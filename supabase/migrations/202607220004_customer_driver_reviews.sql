-- Phase R1: Khách đánh giá tài xế sau delivered

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS rating_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';

COMMENT ON COLUMN public.drivers.rating_count IS 'Số lượt đánh giá (customer → driver)';
COMMENT ON COLUMN public.reviews.tags IS 'Tag nhanh: on_time, friendly, careful...';

-- Recalc rating_count from existing reviews (if any)
UPDATE public.drivers d
SET rating_count = sub.cnt
FROM (
  SELECT driver_id, COUNT(*)::int AS cnt
  FROM public.reviews
  GROUP BY driver_id
) sub
WHERE d.id = sub.driver_id;

CREATE OR REPLACE FUNCTION public.submit_customer_driver_review(
  p_order_id uuid,
  p_rating integer,
  p_comment text DEFAULT NULL,
  p_tags text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_driver_profile_id uuid;
  v_review_id uuid;
  v_old_rating numeric;
  v_old_count integer;
  v_new_rating numeric;
  v_new_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.customer_id != v_uid THEN
    RAISE EXCEPTION 'Only the customer can review this order';
  END IF;

  IF v_order.status != 'delivered'::public.order_status THEN
    RAISE EXCEPTION 'Only delivered orders can be reviewed';
  END IF;

  IF v_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'Order has no assigned driver';
  END IF;

  SELECT d.id INTO v_driver_profile_id
  FROM public.drivers d
  WHERE d.user_id = v_order.driver_id;

  IF v_driver_profile_id IS NULL THEN
    RAISE EXCEPTION 'Driver profile not found';
  END IF;

  IF EXISTS (SELECT 1 FROM public.reviews r WHERE r.order_id = p_order_id) THEN
    RAISE EXCEPTION 'Order already reviewed';
  END IF;

  INSERT INTO public.reviews (
    order_id,
    reviewer_id,
    driver_id,
    rating,
    comment,
    tags
  )
  VALUES (
    p_order_id,
    v_uid,
    v_driver_profile_id,
    p_rating,
    NULLIF(trim(COALESCE(p_comment, '')), ''),
    COALESCE(p_tags, '{}')
  )
  RETURNING id INTO v_review_id;

  SELECT rating, rating_count
  INTO v_old_rating, v_old_count
  FROM public.drivers
  WHERE id = v_driver_profile_id
  FOR UPDATE;

  v_old_count := COALESCE(v_old_count, 0);
  IF v_old_count <= 0 OR v_old_rating IS NULL THEN
    v_new_rating := p_rating::numeric;
    v_new_count := 1;
  ELSE
    v_new_count := v_old_count + 1;
    v_new_rating := ((v_old_rating * v_old_count) + p_rating) / v_new_count;
  END IF;

  -- keep 1 decimal place
  v_new_rating := round(v_new_rating, 1);

  UPDATE public.drivers
  SET
    rating = v_new_rating,
    rating_count = v_new_count,
    updated_at = now()
  WHERE id = v_driver_profile_id;

  RETURN jsonb_build_object(
    'review_id', v_review_id,
    'driver_id', v_driver_profile_id,
    'rating', p_rating,
    'driver_avg_rating', v_new_rating,
    'driver_rating_count', v_new_count
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_customer_driver_review(uuid, integer, text, text[])
  TO authenticated;

-- Customer can read own reviews (already have select_own)
-- Allow customer to re-read by order_id via existing policy
