-- Driver assignment timeout.
-- The database owns the 15-minute deadline; Flutter only renders it.

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS assignment_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS assignment_timed_out_at timestamptz;

ALTER TABLE public.orders
  ALTER COLUMN assignment_expires_at
  SET DEFAULT (now() + interval '15 minutes');

UPDATE public.orders
SET assignment_expires_at = created_at + interval '15 minutes'
WHERE assignment_expires_at IS NULL;

UPDATE public.orders
SET assignment_timed_out_at = assignment_expires_at
WHERE driver_id IS NULL
  AND status IN (
    'pending'::public.order_status,
    'confirmed'::public.order_status
  )
  AND assignment_expires_at <= now()
  AND assignment_timed_out_at IS NULL;

ALTER TABLE public.orders
  ALTER COLUMN assignment_expires_at SET NOT NULL;

COMMENT ON COLUMN public.orders.assignment_expires_at IS
  'Server-owned deadline for a driver to claim the current assignment attempt.';
COMMENT ON COLUMN public.orders.assignment_timed_out_at IS
  'Set when the current assignment attempt expires without a driver.';

CREATE INDEX IF NOT EXISTS orders_open_assignment_deadline_idx
  ON public.orders (assignment_expires_at)
  WHERE driver_id IS NULL
    AND assignment_timed_out_at IS NULL
    AND status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    );

-- Drivers may only discover unassigned orders whose assignment window is open.
DROP POLICY IF EXISTS orders_select_available_for_drivers ON public.orders;
CREATE POLICY orders_select_available_for_drivers
ON public.orders
FOR SELECT
TO authenticated
USING (
  (
    (
      driver_id IS NULL
      AND status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
      AND assignment_timed_out_at IS NULL
      AND assignment_expires_at > clock_timestamp()
    )
    OR driver_id = (SELECT auth.uid())
  )
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE users.id = (SELECT auth.uid())
      AND users.role = 'driver'::public.user_role
  )
);

-- Keep direct updates backward-compatible, but reject expired claims at RLS.
DROP POLICY IF EXISTS orders_update_claim_available_for_drivers
  ON public.orders;
CREATE POLICY orders_update_claim_available_for_drivers
ON public.orders
FOR UPDATE
TO authenticated
USING (
  driver_id IS NULL
  AND status IN (
    'pending'::public.order_status,
    'confirmed'::public.order_status
  )
  AND assignment_timed_out_at IS NULL
  AND assignment_expires_at > clock_timestamp()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE users.id = (SELECT auth.uid())
      AND users.role = 'driver'::public.user_role
  )
)
WITH CHECK (
  driver_id = (SELECT auth.uid())
  AND status = 'assigned'::public.order_status
  AND assignment_timed_out_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE users.id = (SELECT auth.uid())
      AND users.role = 'driver'::public.user_role
  )
);

-- This broad policy allowed a driver to update arbitrary order columns.
-- Rejections now go through the validated reject_order RPC below.
DROP POLICY IF EXISTS drivers_can_update_rejected_by ON public.orders;

CREATE OR REPLACE FUNCTION public.accept_order(
  p_order_id uuid
)
RETURNS TABLE(
  order_id uuid,
  customer_id uuid,
  tracking_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_is_available boolean;
  v_approval_status public.approval_status;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT d.is_available, d.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers d
  WHERE d.user_id = v_driver_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  IF v_approval_status IS DISTINCT FROM 'approved'::public.approval_status THEN
    RAISE EXCEPTION 'DRIVER_NOT_APPROVED';
  END IF;

  IF v_is_available IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'DRIVER_OFFLINE';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orders active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_order.driver_id IS NOT NULL
     OR v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     ) THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;

  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'ASSIGNMENT_EXPIRED';
  END IF;

  UPDATE public.orders
  SET
    driver_id = v_driver_user_id,
    status = 'assigned'::public.order_status,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING * INTO v_order;

  INSERT INTO public.order_status_logs (
    order_id,
    status,
    title,
    description,
    logged_by
  )
  VALUES (
    p_order_id,
    'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã nhận đơn trong thời gian chờ.',
    v_driver_user_id
  );

  RETURN QUERY
  SELECT v_order.id, v_order.customer_id, v_order.tracking_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_order_assignment_timed_out(
  p_order_id uuid
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_timed_out_at timestamptz;
BEGIN
  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR auth.uid() IS DISTINCT FROM v_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_order.driver_id IS NOT NULL
     OR v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     ) THEN
    RETURN v_order.assignment_timed_out_at;
  END IF;

  IF v_order.assignment_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'ASSIGNMENT_STILL_OPEN';
  END IF;

  IF v_order.assignment_timed_out_at IS NULL THEN
    v_timed_out_at := clock_timestamp();

    UPDATE public.orders
    SET
      assignment_timed_out_at = v_timed_out_at,
      status_note = 'Không có tài xế nhận đơn trong vòng 15 phút.',
      updated_at = now()
    WHERE id = p_order_id;

    INSERT INTO public.order_status_logs (
      order_id,
      status,
      title,
      description,
      logged_by
    )
    VALUES (
      p_order_id,
      v_order.status,
      'Chưa tìm thấy tài xế',
      'Không có tài xế nhận đơn trong vòng 15 phút.',
      auth.uid()
    );
  ELSE
    v_timed_out_at := v_order.assignment_timed_out_at;
  END IF;

  RETURN v_timed_out_at;
END;
$function$;

CREATE OR REPLACE FUNCTION public.retry_order_assignment(
  p_order_id uuid
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_new_deadline timestamptz;
BEGIN
  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR auth.uid() IS DISTINCT FROM v_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_order.driver_id IS NOT NULL
     OR v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     ) THEN
    RAISE EXCEPTION 'ORDER_NOT_RETRYABLE';
  END IF;

  IF v_order.assignment_timed_out_at IS NULL
     AND v_order.assignment_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'ASSIGNMENT_STILL_OPEN';
  END IF;

  v_new_deadline := clock_timestamp() + interval '15 minutes';

  UPDATE public.orders
  SET
    assignment_expires_at = v_new_deadline,
    assignment_timed_out_at = NULL,
    rejected_by = '[]'::jsonb,
    status_note = NULL,
    updated_at = now()
  WHERE id = p_order_id;

  INSERT INTO public.order_status_logs (
    order_id,
    status,
    title,
    description,
    logged_by
  )
  VALUES (
    p_order_id,
    v_order.status,
    'Đang tìm lại tài xế',
    'Hệ thống bắt đầu lượt tìm tài xế mới trong 15 phút.',
    auth.uid()
  );

  RETURN v_new_deadline;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_order(
  p_order_id uuid,
  p_driver_user_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_driver_user_id uuid := auth.uid();
BEGIN
  IF v_driver_user_id IS NULL
     OR v_driver_user_id::text IS DISTINCT FROM p_driver_user_id THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers
    WHERE user_id = v_driver_user_id
  ) THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_order.driver_id IS NOT NULL
     OR v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;

  IF NOT COALESCE(v_order.rejected_by, '[]'::jsonb)
      ? v_driver_user_id::text THEN
    UPDATE public.orders
    SET
      rejected_by =
        COALESCE(v_order.rejected_by, '[]'::jsonb)
        || to_jsonb(v_driver_user_id::text),
      updated_at = now()
    WHERE id = p_order_id;
  END IF;
END;
$function$;

-- Keep the future automatic-assignment path consistent with the same deadline.
CREATE OR REPLACE FUNCTION public.assign_order_to_nearest_driver(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 15000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_driver_user_id uuid;
  v_distance double precision;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF auth.uid() IS DISTINCT FROM v_order.customer_id THEN
    RAISE EXCEPTION 'Not allowed to assign this order';
  END IF;

  IF v_order.driver_id IS NOT NULL THEN
    RETURN v_order.driver_id;
  END IF;

  IF v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp() THEN
    RETURN NULL;
  END IF;

  IF v_order.pickup_lat IS NULL OR v_order.pickup_lng IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT f.user_id, f.distance_meters
  INTO v_driver_user_id, v_distance
  FROM public.find_nearest_drivers(
    v_order.pickup_lat,
    v_order.pickup_lng,
    p_radius_meters,
    1
  ) AS f
  LIMIT 1;

  IF v_driver_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE public.orders
  SET
    driver_id = v_driver_user_id,
    status = 'assigned'::public.order_status,
    updated_at = now()
  WHERE id = p_order_id
    AND driver_id IS NULL
    AND assignment_timed_out_at IS NULL
    AND assignment_expires_at > clock_timestamp()
    AND status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    );

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.order_status_logs (
    order_id,
    status,
    title,
    description
  )
  VALUES (
    p_order_id,
    'assigned'::public.order_status,
    'Đã phân công tài xế',
    format(
      'Hệ thống gán đơn cho tài xế gần điểm lấy hàng nhất (%.0f m).',
      COALESCE(v_distance, 0)
    )
  );

  RETURN v_driver_user_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.accept_order(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_order_assignment_timed_out(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.retry_order_assignment(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_order(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.accept_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_order_assignment_timed_out(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.retry_order_assignment(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_order(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) TO authenticated;
