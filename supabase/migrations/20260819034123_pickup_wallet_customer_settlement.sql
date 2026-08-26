-- Charge COD only when pickup is confirmed, expose customer COD balances,
-- and keep every order/wallet transition atomic inside PostgreSQL.

CREATE TABLE public.customer_wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE RESTRICT,
  risk_report_id uuid REFERENCES public.risk_reports(id) ON DELETE RESTRICT,
  transaction_type text NOT NULL CHECK (
    transaction_type IN (
      'delivery_credit',
      'failed_delivery_credit',
      'risk_credit',
      'adjustment_credit',
      'adjustment_debit'
    )
  ),
  status text NOT NULL DEFAULT 'completed' CHECK (
    status IN ('completed', 'reversed')
  ),
  amount bigint NOT NULL CHECK (amount > 0),
  available_delta bigint NOT NULL,
  idempotency_key text NOT NULL UNIQUE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX customer_wallet_transactions_customer_created_idx
  ON public.customer_wallet_transactions (customer_id, created_at DESC);
CREATE INDEX customer_wallet_transactions_order_idx
  ON public.customer_wallet_transactions (order_id);
CREATE INDEX customer_wallet_transactions_risk_idx
  ON public.customer_wallet_transactions (risk_report_id)
  WHERE risk_report_id IS NOT NULL;

ALTER TABLE public.customer_wallet_transactions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.customer_wallet_transactions FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.customer_wallet_transactions
  FROM authenticated;
GRANT SELECT ON public.customer_wallet_transactions TO authenticated;

CREATE POLICY customer_wallet_transactions_select_related
  ON public.customer_wallet_transactions
  FOR SELECT
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.users AS viewer
      WHERE viewer.id = (SELECT auth.uid())
        AND viewer.role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
    )
  );

CREATE OR REPLACE FUNCTION private.credit_customer_cod(
  p_customer_id uuid,
  p_order_id uuid,
  p_amount bigint,
  p_transaction_type text,
  p_idempotency_key text,
  p_risk_report_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN;
  END IF;
  IF p_transaction_type NOT IN (
    'delivery_credit', 'failed_delivery_credit', 'risk_credit'
  ) THEN
    RAISE EXCEPTION 'CUSTOMER_WALLET_TRANSACTION_TYPE_INVALID';
  END IF;

  INSERT INTO public.customer_wallet_transactions (
    customer_id,
    order_id,
    risk_report_id,
    transaction_type,
    amount,
    available_delta,
    idempotency_key,
    metadata
  ) VALUES (
    p_customer_id,
    p_order_id,
    p_risk_report_id,
    p_transaction_type,
    p_amount,
    p_amount,
    p_idempotency_key,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION private.credit_customer_cod(
  uuid, uuid, bigint, text, text, uuid, jsonb
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_customer_wallet_summary()
RETURNS TABLE(
  available_balance bigint,
  total_received bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer_id uuid := (SELECT auth.uid());
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS customer
    WHERE customer.id = v_customer_id
      AND customer.role = 'customer'::public.user_role
  ) THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(sum(tx.available_delta) FILTER (
      WHERE tx.status = 'completed'
    ), 0)::bigint,
    COALESCE(sum(tx.amount) FILTER (
      WHERE tx.status = 'completed'
        AND tx.available_delta > 0
    ), 0)::bigint
  FROM public.customer_wallet_transactions AS tx
  WHERE tx.customer_id = v_customer_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_customer_wallet_transactions(
  p_limit integer DEFAULT 30
)
RETURNS SETOF public.customer_wallet_transactions
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer_id uuid := (SELECT auth.uid());
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'WALLET_TRANSACTION_LIMIT_INVALID';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS customer
    WHERE customer.id = v_customer_id
      AND customer.role = 'customer'::public.user_role
  ) THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;

  RETURN QUERY
  SELECT tx.*
  FROM public.customer_wallet_transactions AS tx
  WHERE tx.customer_id = v_customer_id
  ORDER BY tx.created_at DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_driver_availability(
  p_is_available boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_updated boolean;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_is_available IS NULL THEN
    RAISE EXCEPTION 'DRIVER_AVAILABILITY_REQUIRED';
  END IF;

  UPDATE public.drivers AS driver
  SET
    is_available = p_is_available,
    updated_at = clock_timestamp()
  WHERE driver.user_id = v_driver_user_id
    AND (
      p_is_available = false
      OR driver.approval_status = 'approved'::public.approval_status
    )
  RETURNING driver.is_available INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;
  RETURN v_updated;
END;
$$;

-- Accepting an order checks solvency but does not reserve or debit the wallet.
CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid)
RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_order public.orders%ROWTYPE;
  v_is_available boolean;
  v_approval_status public.approval_status;
  v_available_balance bigint;
  v_required_balance bigint;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT driver_profile.is_available, driver_profile.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers AS driver_profile
  WHERE driver_profile.user_id = v_driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF v_approval_status IS DISTINCT FROM 'approved'::public.approval_status
    THEN RAISE EXCEPTION 'DRIVER_NOT_APPROVED'; END IF;
  IF v_is_available IS DISTINCT FROM true
    THEN RAISE EXCEPTION 'DRIVER_OFFLINE'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.payment_status NOT IN ('not_required', 'paid') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_INCOMPLETE';
  END IF;
  IF v_order.driver_id IS NOT NULL OR v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_AVAILABLE'; END IF;
  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'ASSIGNMENT_EXPIRED'; END IF;
  IF v_order.offered_driver_id IS DISTINCT FROM v_driver_user_id
    THEN RAISE EXCEPTION 'ORDER_NOT_OFFERED_TO_DRIVER'; END IF;
  IF v_order.offer_expires_at IS NULL
     OR v_order.offer_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'OFFER_EXPIRED'; END IF;

  v_required_balance := v_order.driver_advance_amount;
  IF v_required_balance > 0 THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
    SELECT COALESCE(sum(tx.available_delta), 0)::bigint
    INTO v_available_balance
    FROM public.driver_wallet_transactions AS tx
    WHERE tx.driver_id = v_driver_user_id
      AND tx.status = 'completed';
    IF v_available_balance < v_required_balance THEN
      RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE';
    END IF;
  END IF;

  BEGIN
    UPDATE public.orders
    SET
      driver_id = v_driver_user_id,
      status = 'assigned'::public.order_status,
      offered_driver_id = NULL,
      offer_expires_at = NULL,
      updated_at = clock_timestamp()
    WHERE id = p_order_id
    RETURNING * INTO v_order;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã chấp nhận lời mời. Tiền hàng chỉ được trừ khi xác nhận nhận kiện.',
    v_driver_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.customer_id, v_order.tracking_code;
END;
$$;

-- Pickup debits the available wallet directly for new orders. A legacy order
-- that was accepted before this migration consumes its existing hold instead.
CREATE OR REPLACE FUNCTION public.advance_driver_order_status(p_order_id uuid)
RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text, new_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_order public.orders%ROWTYPE;
  v_next_status public.order_status;
  v_title text;
  v_description text;
  v_available_balance bigint;
  v_legacy_held_balance bigint;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_driver_user_id
    THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status = 'picking_up'::public.order_status AND NOT EXISTS (
    SELECT 1 FROM public.order_delivery_proofs AS proof
    WHERE proof.order_id = p_order_id
      AND proof.driver_id = v_driver_user_id
      AND proof.stage = 'pickup'
  ) THEN RAISE EXCEPTION 'PICKUP_PROOF_REQUIRED'; END IF;
  IF v_order.status = 'delivering'::public.order_status AND NOT EXISTS (
    SELECT 1 FROM public.order_delivery_proofs AS proof
    WHERE proof.order_id = p_order_id
      AND proof.driver_id = v_driver_user_id
      AND proof.stage = 'delivery'
  ) THEN RAISE EXCEPTION 'DELIVERY_PROOF_REQUIRED'; END IF;

  v_next_status := CASE v_order.status
    WHEN 'assigned'::public.order_status THEN 'picking_up'::public.order_status
    WHEN 'picking_up'::public.order_status THEN 'delivering'::public.order_status
    WHEN 'delivering'::public.order_status THEN 'delivered'::public.order_status
    ELSE NULL
  END;
  IF v_next_status IS NULL THEN RAISE EXCEPTION 'INVALID_STATUS_TRANSITION'; END IF;

  IF v_next_status IN (
    'delivering'::public.order_status,
    'delivered'::public.order_status
  ) THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
  END IF;

  IF v_next_status = 'delivering'::public.order_status
     AND v_order.driver_advance_amount > 0 THEN
    SELECT COALESCE(sum(tx.held_delta), 0)::bigint
    INTO v_legacy_held_balance
    FROM public.driver_wallet_transactions AS tx
    WHERE tx.driver_id = v_driver_user_id
      AND tx.order_id = v_order.id
      AND tx.status = 'completed';

    IF v_legacy_held_balance >= v_order.driver_advance_amount THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, held_delta,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_advance_capture',
        v_order.driver_advance_amount, -v_order.driver_advance_amount,
        'order:' || v_order.id::text || ':cod_advance_capture',
        clock_timestamp(), jsonb_build_object('source', 'legacy_hold')
      );
    ELSE
      SELECT COALESCE(sum(tx.available_delta), 0)::bigint
      INTO v_available_balance
      FROM public.driver_wallet_transactions AS tx
      WHERE tx.driver_id = v_driver_user_id
        AND tx.status = 'completed';
      IF v_available_balance < v_order.driver_advance_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE_AT_PICKUP';
      END IF;

      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, available_delta,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_advance_capture',
        v_order.driver_advance_amount, -v_order.driver_advance_amount,
        'order:' || v_order.id::text || ':cod_advance_capture',
        clock_timestamp(), jsonb_build_object('source', 'pickup_debit')
      );
    END IF;
  END IF;

  IF v_next_status = 'delivered'::public.order_status THEN
    IF v_order.delivery_fee_payer = 'recipient' THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_settlement',
        v_order.driver_net_earning,
        'order:' || v_order.id::text || ':cod_settlement',
        clock_timestamp(),
        jsonb_build_object(
          'cash_collected', v_order.receiver_collection_amount,
          'cod_collection_amount', v_order.cod_collection_amount,
          'delivery_fee', round(v_order.delivery_fee)::bigint
        )
      );
    ELSE
      IF v_order.cod_collection_amount > 0 THEN
        INSERT INTO public.driver_wallet_transactions (
          driver_id, order_id, transaction_type, amount,
          idempotency_key, completed_at, metadata
        ) VALUES (
          v_driver_user_id, v_order.id, 'cod_settlement', 0,
          'order:' || v_order.id::text || ':cod_settlement',
          clock_timestamp(),
          jsonb_build_object(
            'cash_collected', v_order.cod_collection_amount,
            'cod_collection_amount', v_order.cod_collection_amount,
            'delivery_fee_paid_by', 'sender'
          )
        );
      END IF;
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, available_delta,
        idempotency_key, completed_at
      ) VALUES (
        v_driver_user_id, v_order.id, 'prepaid_earning',
        v_order.driver_net_earning, v_order.driver_net_earning,
        'order:' || v_order.id::text || ':prepaid_earning',
        clock_timestamp()
      );
    END IF;

    PERFORM private.credit_customer_cod(
      v_order.customer_id,
      v_order.id,
      v_order.driver_advance_amount,
      'delivery_credit',
      'order:' || v_order.id::text || ':customer_delivery_credit',
      NULL,
      jsonb_build_object(
        'tracking_code', v_order.tracking_code,
        'driver_id', v_driver_user_id
      )
    );
  END IF;

  v_title := CASE v_next_status
    WHEN 'picking_up'::public.order_status THEN 'Tài xế đang đến điểm lấy hàng'
    WHEN 'delivering'::public.order_status THEN 'Đơn hàng đang được giao'
    WHEN 'delivered'::public.order_status THEN 'Giao hàng thành công'
    ELSE 'Cập nhật trạng thái đơn hàng'
  END;
  v_description := CASE v_next_status
    WHEN 'picking_up'::public.order_status
      THEN 'Tài xế đã bắt đầu di chuyển đến điểm lấy hàng.'
    WHEN 'delivering'::public.order_status
      THEN 'Tài xế đã xác nhận nhận kiện, tiền hàng đã được trừ và đơn đang được giao.'
    WHEN 'delivered'::public.order_status
      THEN 'Tài xế đã xác nhận bàn giao thành công; tiền hàng đã được quyết toán cho người tạo đơn.'
    ELSE NULL
  END;

  UPDATE public.orders
  SET
    status = v_next_status,
    updated_at = clock_timestamp(),
    actual_picked_up_at = CASE
      WHEN v_next_status = 'delivering'::public.order_status
        THEN clock_timestamp()
      ELSE actual_picked_up_at
    END,
    actual_delivered_at = CASE
      WHEN v_next_status = 'delivered'::public.order_status
        THEN clock_timestamp()
      ELSE actual_delivered_at
    END
  WHERE id = p_order_id
    AND status = v_order.status;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_STATUS_CHANGED'; END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, v_next_status, v_title, v_description, v_driver_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.customer_id,
    v_order.tracking_code, v_next_status::text;
END;
$$;

-- A completed return does not refund the driver's COD advance automatically.
-- The already-debited amount compensates the order creator instead.
CREATE OR REPLACE FUNCTION public.confirm_order_return(
  p_order_id uuid,
  p_receiver_name text,
  p_note text DEFAULT NULL
)
RETURNS public.order_returns
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  return_order public.orders%ROWTYPE;
  order_return public.order_returns%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_proof public.order_delivery_proofs%ROWTYPE;
  distance_m double precision;
  normalized_receiver text := trim(COALESCE(p_receiver_name, ''));
  normalized_note text := NULLIF(trim(p_note), '');
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF char_length(normalized_receiver) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'RETURN_RECEIVER_REQUIRED' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO return_order FROM public.orders
  WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT * INTO order_return FROM public.order_returns
  WHERE order_id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RETURN_NOT_FOUND'; END IF;
  IF return_order.driver_id IS DISTINCT FROM actor_id
    OR order_return.driver_id IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501';
  END IF;
  IF return_order.status = 'returned'::public.order_status
    AND order_return.status = 'returned' THEN
    RETURN order_return;
  END IF;
  IF return_order.status <> 'returning'::public.order_status
    OR order_return.status <> 'returning' THEN
    RAISE EXCEPTION 'INVALID_RETURN_COMPLETE_STATE'
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO return_proof
  FROM public.order_delivery_proofs AS proof
  WHERE proof.order_id = p_order_id
    AND proof.driver_id = actor_id
    AND proof.stage = 'return'
  FOR UPDATE;
  IF NOT FOUND OR return_proof.captured_lat IS NULL
    OR return_proof.captured_lng IS NULL THEN
    RAISE EXCEPTION 'RETURN_PROOF_REQUIRED' USING ERRCODE = '23514';
  END IF;

  distance_m := 6371000 * acos(least(1.0, greatest(-1.0,
    cos(radians(order_return.destination_lat))
      * cos(radians(return_proof.captured_lat))
      * cos(radians(return_proof.captured_lng)
        - radians(order_return.destination_lng))
    + sin(radians(order_return.destination_lat))
      * sin(radians(return_proof.captured_lat))
  )));
  IF distance_m > 150 THEN
    RAISE EXCEPTION 'RETURN_OUTSIDE_GEOFENCE' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO intervention FROM public.risk_report_interventions
  WHERE risk_report_id = order_return.risk_report_id FOR UPDATE;
  IF intervention.state <> 'return_required' THEN
    RAISE EXCEPTION 'RETURN_INTERVENTION_MISMATCH' USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'returned'::public.order_status,
    risk_hold_report_id = NULL,
    status_note = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    updated_at = clock_timestamp()
  WHERE id = p_order_id;
  UPDATE public.order_returns SET
    status = 'returned',
    fee_status = 'settled',
    receiver_name = normalized_receiver,
    proof_storage_path = return_proof.storage_path,
    arrived_at = COALESCE(arrived_at, return_proof.captured_at),
    returned_at = COALESCE(returned_at, clock_timestamp()),
    updated_at = clock_timestamp()
  WHERE id = order_return.id
  RETURNING * INTO order_return;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = order_return.risk_report_id;
  UPDATE public.risk_reports SET
    status = 'resolved',
    resolution = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    resolved_at = clock_timestamp(),
    updated_by = actor_id,
    updated_at = clock_timestamp()
  WHERE id = order_return.risk_report_id;

  INSERT INTO public.driver_wallet_transactions (
    driver_id, order_id, transaction_type, amount, available_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    actor_id, p_order_id, 'return_earning',
    order_return.driver_return_earning,
    order_return.driver_return_earning,
    'order:' || p_order_id::text || ':return_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'distance_m', order_return.route_distance_m,
      'fee_payer', order_return.fee_payer
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  IF EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = p_order_id
      AND capture.driver_id = actor_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
  ) THEN
    PERFORM private.credit_customer_cod(
      return_order.customer_id,
      return_order.id,
      return_order.driver_advance_amount,
      'failed_delivery_credit',
      'order:' || return_order.id::text || ':customer_failed_credit',
      order_return.risk_report_id,
      jsonb_build_object(
        'return_id', order_return.id,
        'driver_responsible', true
      )
    );
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'returned'::public.order_status,
    'Hoàn hàng đã ghi nhận',
    'Kiện hàng đã được bàn giao cho ' || normalized_receiver
      || '. Khoản ứng không được tự động hoàn cho tài xế.',
    actor_id
  );
  INSERT INTO public.risk_report_events (
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    order_return.risk_report_id, actor_id, 'return_completed',
    'action_required', 'resolved',
    jsonb_build_object(
      'return_id', order_return.id,
      'receiver_name', normalized_receiver,
      'proof_storage_path', return_proof.storage_path,
      'driver_advance_refunded', false
    )
  );
  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã hoàn hàng',
    'Kiện hàng đã được bàn giao lại; tiền hàng đã được ghi nhận vào Ví Khách Hàng.',
    'order_return_completed',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    actor_id,
    'Hoàn hàng đã ghi nhận',
    'Thu nhập chặng hoàn đã được ghi nhận; khoản ứng tiền hàng không được hoàn tự động.',
    'order_return_completed',
    return_order.id
  );
  RETURN order_return;
END;
$$;

-- A verified custody handoff ends the Driver task. If COD was captured, the
-- driver's responsibility is settled by crediting the order creator.
CREATE OR REPLACE FUNCTION public.confirm_risk_custody_resolved(
  p_report_id uuid,
  p_note text DEFAULT NULL
)
RETURNS public.risk_report_interventions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  custody_order public.orders%ROWTYPE;
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  IF intervention.state = 'return_required' THEN
    RAISE EXCEPTION 'RETURN_WORKFLOW_REQUIRED' USING ERRCODE = '23514';
  END IF;
  IF actor_id IS NULL OR actor_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
    RAISE EXCEPTION 'STAFF_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF intervention.state <> 'handoff_required' THEN
    RAISE EXCEPTION 'NO_HANDOFF_PENDING' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO custody_order FROM public.orders
  WHERE id = report.order_id FOR UPDATE;
  IF custody_order.status NOT IN (
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    ) OR custody_order.driver_id IS DISTINCT FROM intervention.driver_id THEN
    RAISE EXCEPTION 'ORDER_CUSTODY_MISMATCH' USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = custody_order.id
      AND capture.driver_id = intervention.driver_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
  ) THEN
    PERFORM private.credit_customer_cod(
      custody_order.customer_id,
      custody_order.id,
      custody_order.driver_advance_amount,
      'risk_credit',
      'order:' || custody_order.id::text || ':customer_risk_credit',
      p_report_id,
      jsonb_build_object(
        'intervention', 'handoff_required',
        'driver_id', intervention.driver_id
      )
    );
  END IF;

  UPDATE public.orders SET
    status = 'risk_hold'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = p_report_id,
    status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
    updated_at = clock_timestamp()
  WHERE id = custody_order.id;
  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;
  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    custody_order.id, 'risk_hold'::public.order_status,
    'Đã bàn giao hàng',
    COALESCE(NULLIF(trim(p_note), ''), intervention.instruction), actor_id
  );
  INSERT INTO public.risk_report_events (
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    p_report_id, actor_id, 'intervention_changed', report.status,
    report.status,
    jsonb_build_object(
      'state', 'released',
      'driver_advance_refunded', false
    )
  );
  RETURN intervention;
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_wallet_summary()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_wallet_summary()
  TO authenticated;
REVOKE ALL ON FUNCTION public.get_customer_wallet_transactions(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_wallet_transactions(integer)
  TO authenticated;
REVOKE ALL ON FUNCTION public.set_driver_availability(boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_availability(boolean)
  TO authenticated;
REVOKE ALL ON FUNCTION public.accept_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_order(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.advance_driver_order_status(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.advance_driver_order_status(uuid)
  TO authenticated;
REVOKE ALL ON FUNCTION public.confirm_order_return(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_order_return(uuid, text, text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.confirm_risk_custody_resolved(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_risk_custody_resolved(uuid, text)
  TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'customer_wallet_transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.customer_wallet_transactions;
  END IF;
END;
$$;

COMMENT ON TABLE public.customer_wallet_transactions IS
  'Immutable customer COD settlement ledger; clients have read-only access.';
COMMENT ON FUNCTION public.set_driver_availability(boolean) IS
  'Authenticated Driver availability command; apps reset it to false on open.';
