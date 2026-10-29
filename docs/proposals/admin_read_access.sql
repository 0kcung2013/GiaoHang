-- Đã được người dùng duyệt riêng ngày 2026-10-21.
-- Đã áp dụng: supabase/migrations/20261021143625_admin_read_access.sql.
-- Chỉ đọc: danh bạ Admin và chặn phiên không có hồ sơ Admin ở ba RPC cũ.
-- Không đổi bảng/cột/RLS, số dư, dữ liệu KYC hoặc các API ghi nghiệp vụ.

CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id=auth.uid() AND role::text='admin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object(
    'total_orders',(SELECT count(*) FROM public.orders),
    'pending_orders',(SELECT count(*) FROM public.orders WHERE status='pending'),
    'delivering_orders',(SELECT count(*) FROM public.orders WHERE status IN('assigned','picking_up','delivering')),
    'completed_orders',(SELECT count(*) FROM public.orders WHERE status='delivered'),
    'total_drivers',(SELECT count(*) FROM public.drivers),
    'active_drivers',(SELECT count(*) FROM public.drivers WHERE is_available=true AND approval_status='approved'),
    'pending_drivers',(SELECT count(*) FROM public.drivers WHERE approval_status='pending'),
    'total_customers',(SELECT count(*) FROM public.users WHERE role::text='customer'),
    'total_revenue',COALESCE((SELECT sum(total_price) FROM public.orders WHERE status='delivered'),0)
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_list_orders(p_status text DEFAULT NULL)
RETURNS TABLE(order_id uuid, tracking_code text, status text, total_price numeric,
  pickup_address text, delivery_address text, note text, created_at timestamptz,
  customer_name text, driver_name text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id=auth.uid() AND role::text='admin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT o.id,o.tracking_code,o.status::text,o.total_price,
    o.pickup_address,o.delivery_address,o.note,o.created_at,cu.full_name,du.full_name
  FROM public.orders o JOIN public.users cu ON cu.id=o.customer_id
  LEFT JOIN public.users du ON du.id=o.driver_id
  WHERE p_status IS NULL OR o.status::text=p_status
  ORDER BY o.created_at DESC LIMIT 100;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_list_drivers(p_status text)
RETURNS TABLE(driver_id uuid, user_id uuid, vehicle_type text, license_plate text,
  vehicle_brand_model text, vehicle_color text, is_available boolean,
  current_lat double precision, current_lng double precision, updated_at timestamptz,
  rating numeric, total_deliveries integer, approval_status text, full_name text,
  email text, phone text, avatar_url text, verified_at timestamptz,
  rejection_reason text, submitted_at timestamptz, id_card_number text,
  id_card_front_url text, id_card_back_url text, driver_license_number text,
  driver_license_url text, vehicle_photo_url text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id=auth.uid() AND role::text='admin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT d.id,d.user_id,d.vehicle_type,d.license_plate,
    d.vehicle_brand_model,d.vehicle_color,d.is_available,d.current_lat,d.current_lng,
    d.updated_at,d.rating,d.total_deliveries,d.approval_status::text,u.full_name,
    u.email,u.phone,u.avatar_url,d.verified_at,d.rejection_reason,d.submitted_at,
    d.id_card_number,d.id_card_front_url,d.id_card_back_url,d.driver_license_number,
    d.driver_license_url,d.vehicle_photo_url
  FROM public.drivers d JOIN public.users u ON u.id=d.user_id
  WHERE d.approval_status::text=p_status ORDER BY d.updated_at DESC;
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.admin_list_orders(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.admin_list_drivers(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_orders(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_drivers(text) TO authenticated;

CREATE FUNCTION private.list_admin_accounts(
  p_search text DEFAULT '', p_role text DEFAULT NULL,
  p_offset integer DEFAULT 0, p_limit integer DEFAULT 51
)
RETURNS TABLE(id uuid,full_name text,email text,phone text,role text,created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE
  v_search text := lower(btrim(COALESCE(p_search,'')));
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE users.id=auth.uid() AND users.role::text='admin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF length(v_search)>120 OR p_offset IS NULL OR p_offset<0
    OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR (p_role IS NOT NULL AND p_role NOT IN('customer','driver','support','admin')) THEN
    RAISE EXCEPTION 'ACCOUNT_FILTER_INVALID' USING ERRCODE='22023';
  END IF;
  RETURN QUERY SELECT u.id,u.full_name,u.email,u.phone,u.role::text,u.created_at
  FROM public.users u
  WHERE (p_role IS NULL OR u.role::text=p_role)
    AND (v_search='' OR strpos(lower(COALESCE(
      CASE WHEN strpos(v_search,'@')>0 THEN u.email
        WHEN v_search ~ '^\+?[0-9\s.-]+$' THEN u.phone
        ELSE u.full_name END,'')),v_search)>0)
  ORDER BY u.created_at DESC,u.id ASC LIMIT p_limit OFFSET p_offset;
END;
$fn$;
REVOKE ALL ON FUNCTION private.list_admin_accounts(text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.list_admin_accounts(text,text,integer,integer) TO authenticated;

CREATE FUNCTION public.list_admin_accounts(
  p_search text DEFAULT '', p_role text DEFAULT NULL,
  p_offset integer DEFAULT 0, p_limit integer DEFAULT 51
)
RETURNS TABLE(id uuid,full_name text,email text,phone text,role text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $fn$
  SELECT * FROM private.list_admin_accounts(p_search,p_role,p_offset,p_limit);
$fn$;
REVOKE ALL ON FUNCTION public.list_admin_accounts(text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.list_admin_accounts(text,text,integer,integer) TO authenticated;
