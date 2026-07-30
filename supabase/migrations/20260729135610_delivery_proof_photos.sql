-- Require a private photo proof before the driver can confirm pickup or
-- delivery. Files are stored at:
--   <driver_user_id>/<order_id>/<pickup|delivery>

CREATE TABLE public.order_delivery_proofs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL
    REFERENCES public.orders(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL
    REFERENCES public.users(id) ON DELETE RESTRICT,
  stage text NOT NULL
    CHECK (stage IN ('pickup', 'delivery')),
  storage_path text NOT NULL UNIQUE,
  captured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  captured_lat double precision
    CHECK (captured_lat IS NULL OR captured_lat BETWEEN -90 AND 90),
  captured_lng double precision
    CHECK (captured_lng IS NULL OR captured_lng BETWEEN -180 AND 180),
  CONSTRAINT order_delivery_proofs_order_stage_key
    UNIQUE (order_id, stage)
);

CREATE INDEX order_delivery_proofs_driver_id_idx
  ON public.order_delivery_proofs (driver_id);

ALTER TABLE public.order_delivery_proofs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.order_delivery_proofs FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE
  ON TABLE public.order_delivery_proofs
  TO authenticated;

CREATE POLICY order_delivery_proofs_select_related
  ON public.order_delivery_proofs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_delivery_proofs.order_id
        AND (
          o.driver_id = (SELECT auth.uid())
          OR o.customer_id = (SELECT auth.uid())
        )
    )
  );

CREATE POLICY order_delivery_proofs_insert_assigned_driver
  ON public.order_delivery_proofs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_delivery_proofs.order_id
        AND o.driver_id = (SELECT auth.uid())
        AND (
          (
            order_delivery_proofs.stage = 'pickup'
            AND o.status = 'picking_up'::public.order_status
          )
          OR (
            order_delivery_proofs.stage = 'delivery'
            AND o.status = 'delivering'::public.order_status
          )
        )
    )
  );

CREATE POLICY order_delivery_proofs_update_assigned_driver
  ON public.order_delivery_proofs
  FOR UPDATE
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_delivery_proofs.order_id
        AND o.driver_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_delivery_proofs.order_id
        AND o.driver_id = (SELECT auth.uid())
        AND (
          (
            order_delivery_proofs.stage = 'pickup'
            AND o.status = 'picking_up'::public.order_status
          )
          OR (
            order_delivery_proofs.stage = 'delivery'
            AND o.status = 'delivering'::public.order_status
          )
        )
    )
  );

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'delivery-proofs',
  'delivery-proofs',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY delivery_proofs_insert_current_stage
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND storage.filename(name) IN ('pickup', 'delivery')
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id::text = (storage.foldername(name))[2]
        AND o.driver_id = (SELECT auth.uid())
        AND (
          (
            storage.filename(name) = 'pickup'
            AND o.status = 'picking_up'::public.order_status
          )
          OR (
            storage.filename(name) = 'delivery'
            AND o.status = 'delivering'::public.order_status
          )
        )
    )
  );

CREATE POLICY delivery_proofs_select_related_order
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'delivery-proofs'
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id::text = (storage.foldername(name))[2]
        AND (
          o.driver_id = (SELECT auth.uid())
          OR o.customer_id = (SELECT auth.uid())
        )
    )
  );

CREATE POLICY delivery_proofs_update_current_stage
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id::text = (storage.foldername(name))[2]
        AND o.driver_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND storage.filename(name) IN ('pickup', 'delivery')
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id::text = (storage.foldername(name))[2]
        AND o.driver_id = (SELECT auth.uid())
        AND (
          (
            storage.filename(name) = 'pickup'
            AND o.status = 'picking_up'::public.order_status
          )
          OR (
            storage.filename(name) = 'delivery'
            AND o.status = 'delivering'::public.order_status
          )
        )
    )
  );

CREATE OR REPLACE FUNCTION public.advance_driver_order_status(
  p_order_id uuid
)
RETURNS TABLE(
  order_id uuid,
  customer_id uuid,
  tracking_code text,
  new_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_next_status public.order_status;
  v_title text;
  v_description text;
BEGIN
  IF v_driver_user_id IS NULL THEN
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

  IF v_order.driver_id IS DISTINCT FROM v_driver_user_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED';
  END IF;

  IF v_order.status = 'picking_up'::public.order_status
     AND NOT EXISTS (
       SELECT 1
       FROM public.order_delivery_proofs p
       WHERE p.order_id = p_order_id
         AND p.driver_id = v_driver_user_id
         AND p.stage = 'pickup'
     ) THEN
    RAISE EXCEPTION 'PICKUP_PROOF_REQUIRED';
  END IF;

  IF v_order.status = 'delivering'::public.order_status
     AND NOT EXISTS (
       SELECT 1
       FROM public.order_delivery_proofs p
       WHERE p.order_id = p_order_id
         AND p.driver_id = v_driver_user_id
         AND p.stage = 'delivery'
     ) THEN
    RAISE EXCEPTION 'DELIVERY_PROOF_REQUIRED';
  END IF;

  v_next_status := CASE v_order.status
    WHEN 'assigned'::public.order_status
      THEN 'picking_up'::public.order_status
    WHEN 'picking_up'::public.order_status
      THEN 'delivering'::public.order_status
    WHEN 'delivering'::public.order_status
      THEN 'delivered'::public.order_status
    ELSE NULL
  END;

  IF v_next_status IS NULL THEN
    RAISE EXCEPTION 'INVALID_STATUS_TRANSITION';
  END IF;

  v_title := CASE v_next_status
    WHEN 'picking_up'::public.order_status
      THEN 'Tài xế đang đến điểm lấy hàng'
    WHEN 'delivering'::public.order_status
      THEN 'Đơn hàng đang được giao'
    WHEN 'delivered'::public.order_status
      THEN 'Giao hàng thành công'
    ELSE 'Cập nhật trạng thái đơn hàng'
  END;

  v_description := CASE v_next_status
    WHEN 'picking_up'::public.order_status
      THEN 'Tài xế đã bắt đầu di chuyển đến điểm lấy hàng.'
    WHEN 'delivering'::public.order_status
      THEN 'Tài xế đã chụp ảnh xác nhận lấy hàng và đang đến người nhận.'
    WHEN 'delivered'::public.order_status
      THEN 'Tài xế đã chụp ảnh xác nhận bàn giao thành công.'
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

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_STATUS_CHANGED';
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
    v_next_status,
    v_title,
    v_description,
    v_driver_user_id
  );

  RETURN QUERY
  SELECT
    v_order.id,
    v_order.customer_id,
    v_order.tracking_code,
    v_next_status::text;
END;
$function$;

REVOKE ALL ON FUNCTION public.advance_driver_order_status(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.advance_driver_order_status(uuid)
  TO authenticated;
