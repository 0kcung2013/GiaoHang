-- Được người dùng duyệt sửa ngày 2026-10-24; bản nguồn cho migration review_reliability.
-- Thay hai RPC hiện có, giữ bảng/cột/RLS và hợp đồng đầu vào.
-- Không tạo điểm vi phạm hoặc khóa tài xế từ số sao.

CREATE OR REPLACE FUNCTION public.submit_customer_driver_review(
  p_order_id uuid, p_rating integer,
  p_comment text DEFAULT NULL, p_tags text[] DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_review public.reviews%ROWTYPE;
  v_comment text := NULLIF(btrim(COALESCE(p_comment, '')), '');
  v_tags text[];
  v_average numeric;
  v_count integer;
  v_existing boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_uid AND role::text = 'customer') THEN
    RAISE EXCEPTION 'Review role not allowed' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5
    OR char_length(COALESCE(v_comment, '')) > 500
    OR cardinality(COALESCE(p_tags, '{}'::text[])) > 32
    OR EXISTS (SELECT 1 FROM unnest(p_tags) t
      WHERE t IS NULL OR t <> ALL (ARRAY['on_time', 'friendly', 'careful', 'easy_contact', 'a_bit_late', 'bad_attitude']::text[])) THEN
    RAISE EXCEPTION 'Invalid review input' USING ERRCODE = '22023';
  END IF;
  SELECT COALESCE(array_agg(t ORDER BY first_position), '{}'::text[])
  INTO v_tags FROM (
    SELECT t, min(position) first_position
    FROM unnest(p_tags) WITH ORDINALITY AS input(t, position) GROUP BY t
  ) normalized;

  -- Khóa cùng đơn để hai lần gửi đồng thời không vượt qua kiểm tra tồn tại.
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.customer_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Order not found or not owned' USING ERRCODE = '42501';
  END IF;
  IF v_order.status IS DISTINCT FROM 'delivered'::public.order_status
    OR v_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'Only delivered orders with a driver can be reviewed' USING ERRCODE = '22023';
  END IF;
  -- Không khóa khóa chính: hai chiều review cùng tham chiếu FK users/drivers.
  SELECT * INTO v_driver FROM public.drivers WHERE user_id = v_order.driver_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver profile not found' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_review FROM public.reviews
  WHERE order_id = p_order_id AND direction = 'customer_to_driver';
  v_existing := FOUND;
  IF v_existing THEN
    IF v_review.reviewer_id IS DISTINCT FROM v_uid
      OR v_review.driver_id IS DISTINCT FROM v_driver.id
      OR v_review.reviewee_id IS DISTINCT FROM v_driver.user_id THEN
      RAISE EXCEPTION 'Existing review identity mismatch' USING ERRCODE = '42501';
    END IF;
  ELSE
    INSERT INTO public.reviews (
      order_id, reviewer_id, driver_id, reviewee_id, direction, rating, comment, tags
    ) VALUES (
      p_order_id, v_uid, v_driver.id, v_driver.user_id,
      'customer_to_driver', p_rating, v_comment, v_tags
    ) RETURNING * INTO v_review;
  END IF;

  -- Tính từ điểm gốc; không cộng dồn trung bình đã làm tròn.
  SELECT round(avg(rating)::numeric, 1), count(*)::integer
  INTO v_average, v_count FROM public.reviews
  WHERE direction = 'customer_to_driver'
    AND driver_id = v_driver.id;
  UPDATE public.drivers
  SET rating = v_average, rating_count = v_count, updated_at = now()
  WHERE id = v_driver.id;

  RETURN jsonb_build_object(
    'review_id', v_review.id, 'direction', 'customer_to_driver',
    'rating', v_review.rating, 'already_reviewed', v_existing,
    'driver_avg_rating', v_average, 'driver_rating_count', v_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_customer_driver_review(uuid, integer, text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_customer_driver_review(uuid, integer, text, text[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_driver_customer_review(
  p_order_id uuid, p_rating integer,
  p_comment text DEFAULT NULL, p_tags text[] DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_review public.reviews%ROWTYPE;
  v_comment text := NULLIF(btrim(COALESCE(p_comment, '')), '');
  v_tags text[];
  v_average numeric;
  v_count integer;
  v_existing boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_uid AND role::text = 'driver') THEN
    RAISE EXCEPTION 'Review role not allowed' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5
    OR char_length(COALESCE(v_comment, '')) > 500
    OR cardinality(COALESCE(p_tags, '{}'::text[])) > 32
    OR EXISTS (SELECT 1 FROM unnest(p_tags) t
      WHERE t IS NULL OR t <> ALL (ARRAY['polite', 'on_time', 'easy_find', 'clear_address', 'no_answer', 'wrong_address']::text[])) THEN
    RAISE EXCEPTION 'Invalid review input' USING ERRCODE = '22023';
  END IF;
  SELECT COALESCE(array_agg(t ORDER BY first_position), '{}'::text[])
  INTO v_tags FROM (
    SELECT t, min(position) first_position
    FROM unnest(p_tags) WITH ORDINALITY AS input(t, position) GROUP BY t
  ) normalized;

  -- Khóa cùng đơn để hai lần gửi đồng thời không vượt qua kiểm tra tồn tại.
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.driver_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Order not found or not owned' USING ERRCODE = '42501';
  END IF;
  IF v_order.status IS DISTINCT FROM 'delivered'::public.order_status
    OR v_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'Only delivered orders with a driver can be reviewed' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_driver FROM public.drivers WHERE user_id = v_order.driver_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver profile not found' USING ERRCODE = '22023';
  END IF;
  -- Khóa người nhận trước INSERT để tuần tự hóa các đơn cùng khách hàng.
  PERFORM 1 FROM public.users WHERE id = v_order.customer_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer not found' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_review FROM public.reviews
  WHERE order_id = p_order_id AND direction = 'driver_to_customer';
  v_existing := FOUND;
  IF v_existing THEN
    IF v_review.reviewer_id IS DISTINCT FROM v_uid
      OR v_review.driver_id IS DISTINCT FROM v_driver.id
      OR v_review.reviewee_id IS DISTINCT FROM v_order.customer_id THEN
      RAISE EXCEPTION 'Existing review identity mismatch' USING ERRCODE = '42501';
    END IF;
  ELSE
    INSERT INTO public.reviews (
      order_id, reviewer_id, driver_id, reviewee_id, direction, rating, comment, tags
    ) VALUES (
      p_order_id, v_uid, v_driver.id, v_order.customer_id,
      'driver_to_customer', p_rating, v_comment, v_tags
    ) RETURNING * INTO v_review;
  END IF;

  -- Tính từ điểm gốc; không cộng dồn trung bình đã làm tròn.
  SELECT round(avg(rating)::numeric, 1), count(*)::integer
  INTO v_average, v_count FROM public.reviews
  WHERE direction = 'driver_to_customer'
    AND reviewee_id = v_order.customer_id;
  UPDATE public.users
  SET customer_rating = v_average, customer_rating_count = v_count
  WHERE id = v_order.customer_id;

  RETURN jsonb_build_object(
    'review_id', v_review.id, 'direction', 'driver_to_customer',
    'rating', v_review.rating, 'already_reviewed', v_existing,
    'customer_avg_rating', v_average, 'customer_rating_count', v_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_driver_customer_review(uuid, integer, text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_driver_customer_review(uuid, integer, text, text[]) TO authenticated;

-- Đối soát điểm hiện có một lần, chỉ cho người đã có đánh giá.
-- Khóa từng người trước khi đọc tổng để không ghi đè một lần gửi đồng thời.
DO $reconcile$
DECLARE
  v_id uuid;
  v_average numeric;
  v_count integer;
BEGIN
  FOR v_id IN SELECT d.id FROM public.drivers d WHERE EXISTS (
    SELECT 1 FROM public.reviews r
    WHERE r.driver_id = d.id AND r.direction = 'customer_to_driver'
  ) ORDER BY d.id FOR NO KEY UPDATE OF d LOOP
    SELECT round(avg(rating)::numeric, 1), count(*)::integer
    INTO v_average, v_count FROM public.reviews
    WHERE driver_id = v_id AND direction = 'customer_to_driver';
    UPDATE public.drivers SET rating = v_average, rating_count = v_count,
      updated_at = now() WHERE id = v_id
      AND (rating IS DISTINCT FROM v_average OR rating_count IS DISTINCT FROM v_count);
  END LOOP;
  FOR v_id IN SELECT u.id FROM public.users u WHERE EXISTS (
    SELECT 1 FROM public.reviews r
    WHERE r.reviewee_id = u.id AND r.direction = 'driver_to_customer'
  ) ORDER BY u.id FOR NO KEY UPDATE OF u LOOP
    SELECT round(avg(rating)::numeric, 1), count(*)::integer
    INTO v_average, v_count FROM public.reviews
    WHERE reviewee_id = v_id AND direction = 'driver_to_customer';
    UPDATE public.users SET customer_rating = v_average,
      customer_rating_count = v_count WHERE id = v_id
      AND (customer_rating IS DISTINCT FROM v_average OR customer_rating_count IS DISTINCT FROM v_count);
  END LOOP;
END;
$reconcile$;
