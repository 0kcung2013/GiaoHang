-- Customer address book: user-managed saved addresses and order-backed history.
-- Recent addresses are recorded only after create_customer_order succeeds.

CREATE TABLE IF NOT EXISTS public.saved_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  label_type text NOT NULL DEFAULT 'other',
  custom_label text,
  formatted_address text NOT NULL,
  address_detail text NOT NULL DEFAULT '',
  delivery_note text NOT NULL DEFAULT '',
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- The Flutter app referenced a legacy saved_addresses shape before this table
-- was added to repository migrations. These additions/backfills keep a linked
-- project with that legacy table deployable without retaining recipient data in
-- the new model.
ALTER TABLE public.saved_addresses
  ADD COLUMN IF NOT EXISTS label_type text DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS custom_label text,
  ADD COLUMN IF NOT EXISTS formatted_address text,
  ADD COLUMN IF NOT EXISTS address_detail text DEFAULT '',
  ADD COLUMN IF NOT EXISTS delivery_note text DEFAULT '',
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision,
  ADD COLUMN IF NOT EXISTS is_default boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

DO $migration$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'saved_addresses'
      AND column_name = 'address_line'
  ) THEN
    EXECUTE 'UPDATE public.saved_addresses
      SET formatted_address = COALESCE(NULLIF(btrim(formatted_address), ''''), address_line)
      WHERE formatted_address IS NULL OR btrim(formatted_address) = ''''';
    EXECUTE 'ALTER TABLE public.saved_addresses ALTER COLUMN address_line DROP NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'saved_addresses'
      AND column_name = 'lat'
  ) THEN
    EXECUTE 'UPDATE public.saved_addresses SET latitude = COALESCE(latitude, lat)';
    EXECUTE 'ALTER TABLE public.saved_addresses ALTER COLUMN lat DROP NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'saved_addresses'
      AND column_name = 'lng'
  ) THEN
    EXECUTE 'UPDATE public.saved_addresses SET longitude = COALESCE(longitude, lng)';
    EXECUTE 'ALTER TABLE public.saved_addresses ALTER COLUMN lng DROP NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'saved_addresses'
      AND column_name = 'label'
  ) THEN
    EXECUTE 'UPDATE public.saved_addresses
      SET
        label_type = CASE
          WHEN lower(label) LIKE ''%nhà%'' OR lower(label) = ''home'' THEN ''home''
          WHEN lower(label) LIKE ''%công%'' OR lower(label) = ''work'' THEN ''work''
          WHEN lower(label) LIKE ''%kho%'' OR lower(label) = ''warehouse'' THEN ''warehouse''
          ELSE ''other''
        END,
        custom_label = CASE
          WHEN lower(label) LIKE ''%nhà%'' OR lower(label) = ''home'' THEN NULL
          WHEN lower(label) LIKE ''%công%'' OR lower(label) = ''work'' THEN NULL
          WHEN lower(label) LIKE ''%kho%'' OR lower(label) = ''warehouse'' THEN NULL
          ELSE NULLIF(btrim(label), '''')
        END';
    EXECUTE 'ALTER TABLE public.saved_addresses ALTER COLUMN label DROP NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'saved_addresses'
      AND column_name = 'is_default_pickup'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'saved_addresses'
      AND column_name = 'is_default_delivery'
  ) THEN
    EXECUTE 'UPDATE public.saved_addresses
      SET is_default = COALESCE(is_default, false)
        OR COALESCE(is_default_pickup, false)
        OR COALESCE(is_default_delivery, false)';
    EXECUTE 'ALTER TABLE public.saved_addresses
      ALTER COLUMN is_default_pickup SET DEFAULT false,
      ALTER COLUMN is_default_delivery SET DEFAULT false';
  END IF;
END;
$migration$;

UPDATE public.saved_addresses
SET
  label_type = CASE
    WHEN label_type IN ('home', 'work', 'warehouse', 'other') THEN label_type
    ELSE 'other'
  END,
  custom_label = CASE
    WHEN label_type = 'other'
      THEN COALESCE(NULLIF(btrim(custom_label), ''), 'Địa chỉ')
    ELSE NULL
  END,
  formatted_address = COALESCE(NULLIF(btrim(formatted_address), ''), 'Địa chỉ đã lưu'),
  address_detail = COALESCE(address_detail, ''),
  delivery_note = COALESCE(delivery_note, ''),
  latitude = COALESCE(latitude, 0),
  longitude = COALESCE(longitude, 0),
  is_default = COALESCE(is_default, false),
  created_at = COALESCE(created_at, now()),
  updated_at = COALESCE(updated_at, now());

UPDATE public.saved_addresses
SET custom_label = COALESCE(NULLIF(btrim(custom_label), ''), 'Địa chỉ')
WHERE label_type = 'other';

UPDATE public.saved_addresses
SET custom_label = NULL
WHERE label_type <> 'other';

WITH ranked_defaults AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY user_id
      ORDER BY updated_at DESC, created_at DESC, id
    ) AS position
  FROM public.saved_addresses
  WHERE is_default
)
UPDATE public.saved_addresses address
SET is_default = false
FROM ranked_defaults ranked
WHERE address.id = ranked.id
  AND ranked.position > 1;

ALTER TABLE public.saved_addresses
  ALTER COLUMN label_type SET NOT NULL,
  ALTER COLUMN label_type SET DEFAULT 'other',
  ALTER COLUMN formatted_address SET NOT NULL,
  ALTER COLUMN address_detail SET NOT NULL,
  ALTER COLUMN address_detail SET DEFAULT '',
  ALTER COLUMN delivery_note SET NOT NULL,
  ALTER COLUMN delivery_note SET DEFAULT '',
  ALTER COLUMN latitude SET NOT NULL,
  ALTER COLUMN longitude SET NOT NULL,
  ALTER COLUMN is_default SET NOT NULL,
  ALTER COLUMN is_default SET DEFAULT false,
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET NOT NULL,
  ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.saved_addresses
  DROP CONSTRAINT IF EXISTS saved_addresses_label_type_check,
  DROP CONSTRAINT IF EXISTS saved_addresses_custom_label_check,
  DROP CONSTRAINT IF EXISTS saved_addresses_formatted_address_check,
  DROP CONSTRAINT IF EXISTS saved_addresses_address_detail_check,
  DROP CONSTRAINT IF EXISTS saved_addresses_delivery_note_check,
  DROP CONSTRAINT IF EXISTS saved_addresses_latitude_check,
  DROP CONSTRAINT IF EXISTS saved_addresses_longitude_check;

ALTER TABLE public.saved_addresses
  ADD CONSTRAINT saved_addresses_label_type_check
    CHECK (label_type IN ('home', 'work', 'warehouse', 'other')),
  ADD CONSTRAINT saved_addresses_custom_label_check
    CHECK (
      label_type <> 'other'
      OR (
        custom_label IS NOT NULL
        AND char_length(btrim(custom_label)) BETWEEN 1 AND 30
      )
    ),
  ADD CONSTRAINT saved_addresses_formatted_address_check
    CHECK (char_length(btrim(formatted_address)) BETWEEN 6 AND 500),
  ADD CONSTRAINT saved_addresses_address_detail_check
    CHECK (char_length(address_detail) <= 200),
  ADD CONSTRAINT saved_addresses_delivery_note_check
    CHECK (char_length(delivery_note) <= 240),
  ADD CONSTRAINT saved_addresses_latitude_check
    CHECK (latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT saved_addresses_longitude_check
    CHECK (longitude BETWEEN -180 AND 180);

CREATE UNIQUE INDEX IF NOT EXISTS saved_addresses_one_default_per_user_idx
  ON public.saved_addresses(user_id)
  WHERE is_default;

CREATE INDEX IF NOT EXISTS saved_addresses_user_updated_idx
  ON public.saved_addresses(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.recent_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  address_type text NOT NULL CHECK (address_type IN ('pickup', 'delivery')),
  formatted_address text NOT NULL
    CHECK (char_length(btrim(formatted_address)) BETWEEN 6 AND 500),
  address_detail text NOT NULL DEFAULT ''
    CHECK (char_length(address_detail) <= 200),
  delivery_note text NOT NULL DEFAULT ''
    CHECK (char_length(delivery_note) <= 240),
  latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  usage_count integer NOT NULL DEFAULT 1 CHECK (usage_count > 0),
  last_used_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS recent_addresses_location_key_idx
  ON public.recent_addresses(
    user_id,
    address_type,
    (round(latitude::numeric, 4)),
    (round(longitude::numeric, 4))
  );

CREATE INDEX IF NOT EXISTS recent_addresses_user_last_used_idx
  ON public.recent_addresses(user_id, last_used_at DESC);

ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recent_addresses ENABLE ROW LEVEL SECURITY;

-- PostgreSQL combines permissive policies with OR. Remove any legacy policies
-- first so an older broad policy cannot bypass the ownership rules below.
DO $policies$
DECLARE
  policy_row record;
BEGIN
  FOR policy_row IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('saved_addresses', 'recent_addresses')
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );
  END LOOP;
END;
$policies$;

DROP POLICY IF EXISTS saved_addresses_select_own ON public.saved_addresses;
CREATE POLICY saved_addresses_select_own
  ON public.saved_addresses FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS saved_addresses_insert_own ON public.saved_addresses;
CREATE POLICY saved_addresses_insert_own
  ON public.saved_addresses FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS saved_addresses_update_own ON public.saved_addresses;
CREATE POLICY saved_addresses_update_own
  ON public.saved_addresses FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()))
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS saved_addresses_delete_own ON public.saved_addresses;
CREATE POLICY saved_addresses_delete_own
  ON public.saved_addresses FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS recent_addresses_select_own ON public.recent_addresses;
CREATE POLICY recent_addresses_select_own
  ON public.recent_addresses FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS recent_addresses_insert_own ON public.recent_addresses;
CREATE POLICY recent_addresses_insert_own
  ON public.recent_addresses FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS recent_addresses_update_own ON public.recent_addresses;
CREATE POLICY recent_addresses_update_own
  ON public.recent_addresses FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()))
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS recent_addresses_delete_own ON public.recent_addresses;
CREATE POLICY recent_addresses_delete_own
  ON public.recent_addresses FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

-- New SQL-created public tables are not guaranteed to be exposed to the Data
-- API automatically, so grant the authenticated role explicitly.
REVOKE ALL ON TABLE public.saved_addresses FROM anon;
REVOKE ALL ON TABLE public.recent_addresses FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.saved_addresses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.recent_addresses TO authenticated;

CREATE OR REPLACE FUNCTION public.set_default_saved_address(
  p_address_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.saved_addresses
    WHERE id = p_address_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'SAVED_ADDRESS_NOT_FOUND';
  END IF;

  UPDATE public.saved_addresses
  SET is_default = false, updated_at = clock_timestamp()
  WHERE user_id = v_user_id
    AND is_default;

  UPDATE public.saved_addresses
  SET is_default = true, updated_at = clock_timestamp()
  WHERE id = p_address_id
    AND user_id = v_user_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_recent_addresses(
  p_addresses jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_address jsonb;
  v_address_type text;
  v_formatted_address text;
  v_address_detail text;
  v_delivery_note text;
  v_latitude double precision;
  v_longitude double precision;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF p_addresses IS NULL
     OR jsonb_typeof(p_addresses) <> 'array'
     OR jsonb_array_length(p_addresses) NOT BETWEEN 1 AND 2 THEN
    RAISE EXCEPTION 'RECENT_ADDRESSES_INVALID';
  END IF;

  FOR v_address IN SELECT value FROM jsonb_array_elements(p_addresses)
  LOOP
    v_address_type := v_address ->> 'address_type';
    v_formatted_address := NULLIF(btrim(v_address ->> 'formatted_address'), '');
    v_address_detail := COALESCE(btrim(v_address ->> 'address_detail'), '');
    v_delivery_note := COALESCE(btrim(v_address ->> 'delivery_note'), '');
    v_latitude := (v_address ->> 'latitude')::double precision;
    v_longitude := (v_address ->> 'longitude')::double precision;

    IF v_address_type NOT IN ('pickup', 'delivery')
       OR v_formatted_address IS NULL
       OR char_length(v_formatted_address) < 6
       OR v_latitude NOT BETWEEN -90 AND 90
       OR v_longitude NOT BETWEEN -180 AND 180 THEN
      RAISE EXCEPTION 'RECENT_ADDRESS_INVALID';
    END IF;

    INSERT INTO public.recent_addresses (
      user_id,
      address_type,
      formatted_address,
      address_detail,
      delivery_note,
      latitude,
      longitude,
      usage_count,
      last_used_at
    ) VALUES (
      v_user_id,
      v_address_type,
      v_formatted_address,
      v_address_detail,
      v_delivery_note,
      v_latitude,
      v_longitude,
      1,
      clock_timestamp()
    )
    ON CONFLICT (
      user_id,
      address_type,
      (round(latitude::numeric, 4)),
      (round(longitude::numeric, 4))
    ) DO UPDATE SET
      formatted_address = EXCLUDED.formatted_address,
      address_detail = EXCLUDED.address_detail,
      delivery_note = EXCLUDED.delivery_note,
      usage_count = public.recent_addresses.usage_count + 1,
      last_used_at = clock_timestamp();
  END LOOP;

  DELETE FROM public.recent_addresses
  WHERE user_id = v_user_id
    AND id IN (
      SELECT id
      FROM public.recent_addresses
      WHERE user_id = v_user_id
      ORDER BY last_used_at DESC, id DESC
      OFFSET 15
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.set_default_saved_address(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_default_saved_address(uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.record_recent_addresses(jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_recent_addresses(jsonb)
  TO authenticated;
