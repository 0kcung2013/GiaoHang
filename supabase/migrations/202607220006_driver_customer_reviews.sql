-- R2: Tài xế đánh giá khách hàng (direction 2 chiều trên reviews)

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS customer_rating numeric
    CHECK (customer_rating IS NULL OR (customer_rating >= 1 AND customer_rating <= 5)),
  ADD COLUMN IF NOT EXISTS customer_rating_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS direction text NOT NULL DEFAULT 'customer_to_driver',
  ADD COLUMN IF NOT EXISTS reviewee_id uuid REFERENCES public.users(id) ON DELETE CASCADE;

COMMENT ON COLUMN public.reviews.direction IS
  'customer_to_driver | driver_to_customer';
COMMENT ON COLUMN public.reviews.reviewee_id IS
  'User được đánh giá (TX user hoặc customer user)';

-- Backfill R1
UPDATE public.reviews r
SET
  direction = 'customer_to_driver',
  reviewee_id = d.user_id
FROM public.drivers d
WHERE r.driver_id = d.id
  AND (r.reviewee_id IS NULL OR r.direction IS NULL OR r.direction = 'customer_to_driver');

ALTER TABLE public.reviews
  DROP CONSTRAINT IF EXISTS reviews_order_unique;

ALTER TABLE public.reviews
  DROP CONSTRAINT IF EXISTS reviews_order_direction_unique;

ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_order_direction_unique UNIQUE (order_id, direction);

ALTER TABLE public.reviews
  DROP CONSTRAINT IF EXISTS reviews_direction_check;

ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_direction_check
  CHECK (direction IN ('customer_to_driver', 'driver_to_customer'));

-- Cập nhật R1 RPC: set direction + reviewee
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
  v_driver_user_id uuid;
  v_review_id uuid;
  v_old_rating numeric;
  v_old_count integer;
  v_new_rating numeric;
  v_new_count integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5';
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF v_order.customer_id != v_uid THEN
    RAISE EXCEPTION 'Only the customer can review this order';
  END IF;
  IF v_order.status != 'delivered'::public.order_status THEN
    RAISE EXCEPTION 'Only delivered orders can be reviewed';
  END IF;
  IF v_order.driver_id IS NULL THEN RAISE EXCEPTION 'Order has no assigned driver'; END IF;

  SELECT d.id, d.user_id INTO v_driver_profile_id, v_driver_user_id
  FROM public.drivers d WHERE d.user_id = v_order.driver_id;
  IF v_driver_profile_id IS NULL THEN RAISE EXCEPTION 'Driver profile not found'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.reviews r
    WHERE r.order_id = p_order_id AND r.direction = 'customer_to_driver'
  ) THEN
    RAISE EXCEPTION 'Order already reviewed by customer';
  END IF;

  INSERT INTO public.reviews (
    order_id, reviewer_id, driver_id, reviewee_id, direction, rating, comment, tags
  ) VALUES (
    p_order_id, v_uid, v_driver_profile_id, v_driver_user_id,
    'customer_to_driver', p_rating,
    NULLIF(trim(COALESCE(p_comment, '')), ''),
    COALESCE(p_tags, '{}')
  )
  RETURNING id INTO v_review_id;

  SELECT rating, COALESCE(rating_count, 0)
  INTO v_old_rating, v_old_count
  FROM public.drivers WHERE id = v_driver_profile_id FOR UPDATE;

  IF v_old_count <= 0 OR v_old_rating IS NULL THEN
    v_new_rating := p_rating::numeric;
    v_new_count := 1;
  ELSE
    v_new_count := v_old_count + 1;
    v_new_rating := round(((v_old_rating * v_old_count) + p_rating) / v_new_count, 1);
  END IF;

  UPDATE public.drivers
  SET rating = v_new_rating, rating_count = v_new_count, updated_at = now()
  WHERE id = v_driver_profile_id;

  RETURN jsonb_build_object(
    'review_id', v_review_id,
    'direction', 'customer_to_driver',
    'rating', p_rating,
    'driver_avg_rating', v_new_rating,
    'driver_rating_count', v_new_count
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_customer_driver_review(uuid, integer, text, text[])
  TO authenticated;

-- R2 RPC: driver → customer
CREATE OR REPLACE FUNCTION public.submit_driver_customer_review(
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
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5';
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;

  IF v_order.driver_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Only the assigned driver can review this customer';
  END IF;
  IF v_order.status != 'delivered'::public.order_status THEN
    RAISE EXCEPTION 'Only delivered orders can be reviewed';
  END IF;

  SELECT d.id INTO v_driver_profile_id
  FROM public.drivers d WHERE d.user_id = v_uid;
  IF v_driver_profile_id IS NULL THEN RAISE EXCEPTION 'Driver profile not found'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.reviews r
    WHERE r.order_id = p_order_id AND r.direction = 'driver_to_customer'
  ) THEN
    RAISE EXCEPTION 'Customer already reviewed for this order';
  END IF;

  INSERT INTO public.reviews (
    order_id, reviewer_id, driver_id, reviewee_id, direction, rating, comment, tags
  ) VALUES (
    p_order_id, v_uid, v_driver_profile_id, v_order.customer_id,
    'driver_to_customer', p_rating,
    NULLIF(trim(COALESCE(p_comment, '')), ''),
    COALESCE(p_tags, '{}')
  )
  RETURNING id INTO v_review_id;

  SELECT customer_rating, COALESCE(customer_rating_count, 0)
  INTO v_old_rating, v_old_count
  FROM public.users WHERE id = v_order.customer_id FOR UPDATE;

  IF v_old_count <= 0 OR v_old_rating IS NULL THEN
    v_new_rating := p_rating::numeric;
    v_new_count := 1;
  ELSE
    v_new_count := v_old_count + 1;
    v_new_rating := round(((v_old_rating * v_old_count) + p_rating) / v_new_count, 1);
  END IF;

  UPDATE public.users
  SET
    customer_rating = v_new_rating,
    customer_rating_count = v_new_count
  WHERE id = v_order.customer_id;

  RETURN jsonb_build_object(
    'review_id', v_review_id,
    'direction', 'driver_to_customer',
    'rating', p_rating,
    'customer_avg_rating', v_new_rating,
    'customer_rating_count', v_new_count
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_driver_customer_review(uuid, integer, text, text[])
  TO authenticated;

-- Driver có thể đọc review chiều driver_to_customer của mình
DROP POLICY IF EXISTS reviews_select_driver_own ON public.reviews;
CREATE POLICY reviews_select_driver_own
  ON public.reviews
  FOR SELECT
  TO authenticated
  USING (
    reviewer_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = reviews.driver_id AND d.user_id = auth.uid()
    )
  );
