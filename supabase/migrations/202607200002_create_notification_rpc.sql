-- Cho phép app tạo notification cho user khác (driver/customer)
-- qua SECURITY DEFINER — RLS chỉ cho SELECT/UPDATE own, không có INSERT.

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_order_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;

  IF p_title IS NULL OR btrim(p_title) = '' THEN
    RAISE EXCEPTION 'title is required';
  END IF;

  IF p_body IS NULL OR btrim(p_body) = '' THEN
    RAISE EXCEPTION 'body is required';
  END IF;

  IF p_type IS NULL OR btrim(p_type) = '' THEN
    RAISE EXCEPTION 'type is required';
  END IF;

  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    type,
    is_read,
    order_id,
    created_at
  )
  VALUES (
    p_user_id,
    btrim(p_title),
    btrim(p_body),
    btrim(p_type),
    false,
    p_order_id,
    now()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_notification(uuid, text, text, text, uuid)
  TO authenticated;

-- Đảm bảo Realtime nhận INSERT trên notifications (idempotent-ish).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;
