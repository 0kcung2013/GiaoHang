-- Customer payment PIN. Only server-owned functions can read credential state.
-- Separate from public.users (profile SELECTs) and the financial ledger.
CREATE TABLE private.customer_wallet_security (
  customer_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  pin_hash text,
  failed_attempts integer NOT NULL DEFAULT 0 CHECK (failed_attempts BETWEEN 0 AND 4),
  locked_until timestamptz,
  pin_updated_at timestamptz,
  last_reset_verified_at timestamptz,
  last_reset_request_id uuid
);
ALTER TABLE private.customer_wallet_security ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.customer_wallet_security FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION private.customer_wallet_pin_actor() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE actor uuid := auth.uid();
BEGIN
  IF actor IS NULL OR NOT private.account_enabled(actor) OR NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = actor AND role = 'customer'
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED' USING ERRCODE = '42501'; END IF;
  RETURN actor;
END;
$fn$;
REVOKE ALL ON FUNCTION private.customer_wallet_pin_actor() FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.get_customer_wallet_pin_status() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE actor uuid := private.customer_wallet_pin_actor(); state private.customer_wallet_security;
BEGIN
  SELECT * INTO state FROM private.customer_wallet_security WHERE customer_id = actor;
  RETURN jsonb_build_object('ok', true, 'is_configured', state.pin_hash IS NOT NULL,
    'locked_until', state.locked_until, 'server_now', clock_timestamp(),
    'attempts_remaining', CASE WHEN state.locked_until > clock_timestamp() THEN 0
      WHEN state.locked_until IS NOT NULL THEN 5 ELSE 5 - COALESCE(state.failed_attempts, 0) END,
    'recovery_email', (SELECT email FROM auth.users WHERE id = actor AND email_confirmed_at IS NOT NULL));
END;
$fn$;

-- Return failures, never RAISE after counting them: an exception rolls back the count.
-- Caller holds the customer-wallet advisory lock for the complete command.
CREATE FUNCTION private.check_customer_wallet_pin(p_customer_id uuid, p_pin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE state private.customer_wallet_security; attempts integer; until_at timestamptz;
BEGIN
  INSERT INTO private.customer_wallet_security(customer_id) VALUES(p_customer_id) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT state FROM private.customer_wallet_security WHERE customer_id = p_customer_id FOR UPDATE;
  IF state.pin_hash IS NULL THEN RETURN jsonb_build_object('ok', false, 'code', 'PIN_REQUIRED'); END IF;
  IF state.locked_until > clock_timestamp() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'PIN_LOCKED', 'locked_until', state.locked_until,
      'server_now', clock_timestamp(), 'attempts_remaining', 0);
  END IF;
  IF p_pin IS NULL OR p_pin !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'PIN_FORMAT');
  END IF;
  IF extensions.crypt(p_pin, state.pin_hash) <> state.pin_hash THEN
    attempts := CASE WHEN state.locked_until IS NOT NULL THEN 1 ELSE state.failed_attempts + 1 END;
    IF attempts >= 5 THEN until_at := clock_timestamp() + interval '15 minutes'; END IF;
    UPDATE private.customer_wallet_security SET failed_attempts = CASE WHEN attempts >= 5 THEN 0 ELSE attempts END,
      locked_until = until_at WHERE customer_id = p_customer_id;
    RETURN jsonb_build_object('ok', false, 'code', CASE WHEN until_at IS NULL THEN 'PIN_INVALID' ELSE 'PIN_LOCKED' END,
      'attempts_remaining', 5 - attempts, 'locked_until', until_at, 'server_now', clock_timestamp());
  END IF;
  UPDATE private.customer_wallet_security SET failed_attempts = 0, locked_until = NULL WHERE customer_id = p_customer_id;
  RETURN jsonb_build_object('ok', true);
END;
$fn$;
REVOKE ALL ON FUNCTION private.check_customer_wallet_pin(uuid,text) FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION private.set_customer_wallet_pin(p_new_pin text, p_current_pin text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE actor uuid := private.customer_wallet_pin_actor(); check_result jsonb; configured boolean;
BEGIN
  IF p_new_pin IS NULL OR p_new_pin !~ '^[0-9]{6}$' THEN RETURN jsonb_build_object('ok', false, 'code', 'PIN_FORMAT'); END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:' || actor::text, 0));
  INSERT INTO private.customer_wallet_security(customer_id) VALUES(actor) ON CONFLICT DO NOTHING;
  SELECT pin_hash IS NOT NULL INTO configured FROM private.customer_wallet_security WHERE customer_id = actor FOR UPDATE;
  IF configured THEN
    check_result := private.check_customer_wallet_pin(actor, p_current_pin);
    IF NOT (check_result->>'ok')::boolean THEN RETURN check_result; END IF;
  END IF;
  UPDATE private.customer_wallet_security SET pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf', 10)),
    failed_attempts = 0, locked_until = NULL, pin_updated_at = clock_timestamp() WHERE customer_id = actor;
  RETURN jsonb_build_object('ok', true);
END;
$fn$;

-- Proof is the live Auth recovery session, not editable metadata or token iat.
-- Auth verifies the email code; this RPC consumes its server-side AMR timestamp.
CREATE FUNCTION private.reset_customer_wallet_pin(p_new_pin text, p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE actor uuid := private.customer_wallet_pin_actor(); verified_at timestamptz;
  recovery_session_id uuid := NULLIF(auth.jwt()->>'session_id', '')::uuid; state private.customer_wallet_security;
BEGIN
  IF p_new_pin IS NULL OR p_new_pin !~ '^[0-9]{6}$' OR p_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'PIN_FORMAT');
  END IF;
  SELECT max(greatest(a.created_at, a.updated_at)) INTO verified_at
  FROM auth.sessions s JOIN auth.mfa_amr_claims a ON a.session_id = s.id
    JOIN auth.users u ON u.id = s.user_id
  WHERE s.id = recovery_session_id AND s.user_id = actor AND a.authentication_method = 'recovery'
    AND u.email_confirmed_at IS NOT NULL AND u.email = auth.jwt()->>'email'
    AND (s.not_after IS NULL OR s.not_after > clock_timestamp());
  IF verified_at IS NULL OR verified_at < clock_timestamp() - interval '5 minutes' OR verified_at > clock_timestamp() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'EMAIL_VERIFICATION_REQUIRED');
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:' || actor::text, 0));
  INSERT INTO private.customer_wallet_security(customer_id) VALUES(actor) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT state FROM private.customer_wallet_security WHERE customer_id = actor FOR UPDATE;
  IF state.last_reset_verified_at IS NOT NULL AND verified_at <= state.last_reset_verified_at THEN
    IF state.last_reset_request_id = p_request_id AND extensions.crypt(p_new_pin, state.pin_hash) = state.pin_hash THEN
      RETURN jsonb_build_object('ok', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'EMAIL_VERIFICATION_REQUIRED');
  END IF;
  UPDATE private.customer_wallet_security SET pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf', 10)),
    failed_attempts = 0, locked_until = NULL, pin_updated_at = clock_timestamp(),
    last_reset_verified_at = verified_at, last_reset_request_id = p_request_id WHERE customer_id = actor;
  RETURN jsonb_build_object('ok', true);
END;
$fn$;

-- Preserve the existing financial/quote/dispatch implementation. Remove every
-- client grant to the unchecked helper, including its old private entry point.
ALTER FUNCTION private.create_customer_order_with_wallet(jsonb,uuid) RENAME TO create_customer_order_with_wallet_unchecked;
REVOKE ALL ON FUNCTION private.create_customer_order_with_wallet_unchecked(jsonb,uuid) FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION private.create_customer_order_with_wallet(p_order_payload jsonb, p_request_id uuid, p_pin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE actor uuid := private.customer_wallet_pin_actor(); check_result jsonb; existing public.customer_wallet_transactions;
  result_order public.orders;
BEGIN
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'WALLET_REQUEST_ID_REQUIRED'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:' || actor::text, 0));
  SELECT * INTO existing FROM public.customer_wallet_transactions
    WHERE customer_id = actor AND idempotency_key = 'customer:' || actor::text || ':delivery-payment:' || p_request_id::text;
  IF NOT FOUND THEN
    check_result := private.check_customer_wallet_pin(actor, p_pin);
    IF NOT (check_result->>'ok')::boolean THEN RETURN check_result; END IF;
  END IF;
  -- Existing receipt still checks the original payload. Read-back never debits
  -- again, requires no retained PIN, and works even after a later PIN lock.
  SELECT * INTO result_order FROM private.create_customer_order_with_wallet_unchecked(p_order_payload, p_request_id);
  RETURN jsonb_build_object('ok', true, 'order', to_jsonb(result_order));
END;
$fn$;

-- Old clients fail closed. No overloaded 2-argument route can debit without PIN.
CREATE OR REPLACE FUNCTION public.create_customer_order_with_wallet(p_order_payload jsonb, p_request_id uuid)
RETURNS public.orders LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $fn$
BEGIN RAISE EXCEPTION 'CUSTOMER_WALLET_PIN_REQUIRED'; END;
$fn$;

CREATE FUNCTION public.create_customer_order_with_wallet(p_order_payload jsonb, p_request_id uuid, p_pin text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $fn$
  SELECT private.create_customer_order_with_wallet(p_order_payload, p_request_id, p_pin);
$fn$;
CREATE FUNCTION public.get_customer_wallet_pin_status() RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $fn$ SELECT private.get_customer_wallet_pin_status(); $fn$;
CREATE FUNCTION public.set_customer_wallet_pin(p_new_pin text, p_current_pin text DEFAULT NULL) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $fn$ SELECT private.set_customer_wallet_pin(p_new_pin, p_current_pin); $fn$;
CREATE FUNCTION public.reset_customer_wallet_pin(p_new_pin text, p_request_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $fn$ SELECT private.reset_customer_wallet_pin(p_new_pin, p_request_id); $fn$;

REVOKE ALL ON FUNCTION private.get_customer_wallet_pin_status(), private.set_customer_wallet_pin(text,text),
  private.reset_customer_wallet_pin(text,uuid), private.create_customer_order_with_wallet(jsonb,uuid,text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_customer_wallet_pin_status(), public.set_customer_wallet_pin(text,text),
  public.reset_customer_wallet_pin(text,uuid), public.create_customer_order_with_wallet(jsonb,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.get_customer_wallet_pin_status(), private.set_customer_wallet_pin(text,text),
  private.reset_customer_wallet_pin(text,uuid), private.create_customer_order_with_wallet(jsonb,uuid,text),
  public.get_customer_wallet_pin_status(), public.set_customer_wallet_pin(text,text),
  public.reset_customer_wallet_pin(text,uuid), public.create_customer_order_with_wallet(jsonb,uuid,text) TO authenticated;
