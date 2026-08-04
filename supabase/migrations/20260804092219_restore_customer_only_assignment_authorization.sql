-- The offer-transfer flow is read-only ranking plus rejected_by filtering.
-- This mutating RPC remains customer-only and is not used by Driver transfer.

CREATE OR REPLACE FUNCTION public.assign_order_to_nearest_driver(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 5000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_candidate record;
  v_driver_user_id uuid;
  v_distance double precision;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_actor_id IS DISTINCT FROM v_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_ASSIGNMENT_FORBIDDEN';
  END IF;

  IF v_order.driver_id IS NOT NULL THEN
    RETURN v_order.driver_id;
  END IF;

  IF v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
     OR v_order.pickup_lat IS NULL
     OR v_order.pickup_lng IS NULL THEN
    RETURN NULL;
  END IF;

  FOR v_candidate IN
    WITH eligible_candidates AS (
      SELECT candidate.*
      FROM public.find_nearest_drivers(
        v_order.pickup_lat,
        v_order.pickup_lng,
        p_radius_meters,
        50
      ) candidate
      WHERE NOT (
        COALESCE(v_order.rejected_by, '[]'::jsonb)
        ? candidate.user_id::text
      )
    )
    SELECT candidate.*
    FROM eligible_candidates candidate
    ORDER BY
      candidate.distance_meters ASC,
      candidate.user_id ASC
  LOOP
    BEGIN
      UPDATE public.orders
      SET
        driver_id = v_candidate.user_id,
        status = 'assigned'::public.order_status,
        updated_at = clock_timestamp()
      WHERE id = p_order_id
        AND driver_id IS NULL
        AND assignment_timed_out_at IS NULL
        AND assignment_expires_at > clock_timestamp()
        AND status IN (
          'pending'::public.order_status,
          'confirmed'::public.order_status
        );

      IF FOUND THEN
        v_driver_user_id := v_candidate.user_id;
        v_distance := v_candidate.distance_meters;
        EXIT;
      END IF;
    EXCEPTION
      WHEN unique_violation THEN
        CONTINUE;
    END;
  END LOOP;

  IF v_driver_user_id IS NULL THEN
    RETURN NULL;
  END IF;

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
    'Đã phân công tài xế',
    format(
      'Hệ thống phân công tài xế gần nhất (%s m).',
      round(COALESCE(v_distance, 0))::text
    ),
    v_actor_id
  );

  RETURN v_driver_user_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) TO authenticated;
