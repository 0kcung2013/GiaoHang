-- Automatic dispatch must use the same held-parcel capacity as acceptance.
-- Keep GPS, wallet, account, payment, existing-offer and radius checks intact.
CREATE OR REPLACE FUNCTION private.road_driver_candidates(p_order_id uuid)
 RETURNS TABLE(user_id uuid, current_lat double precision, current_lng double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT d.user_id, d.current_lat, d.current_lng
  FROM public.orders o CROSS JOIN public.drivers d
  WHERE o.id = p_order_id
    AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
    AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
    AND o.payment_status IN ('paid','not_required')
    AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
    AND (o.offered_driver_id IS NULL OR o.offer_expires_at <= now())
    AND EXISTS(SELECT 1 FROM auth.users a WHERE a.id=d.user_id
      AND (a.banned_until IS NULL OR a.banned_until<=statement_timestamp()))
    AND d.is_available AND d.approval_status = 'approved'
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= now())
    AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL
    AND d.location_updated_at >= now() - interval '3 minutes'
    AND NOT (COALESCE(o.rejected_by,'[]'::jsonb) ? d.user_id::text)
    AND COALESCE((SELECT sum(w.available_delta) FROM public.driver_wallet_transactions w
      WHERE w.driver_id = d.user_id AND w.status = 'completed'),0) >= o.driver_advance_amount
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.driver_id = d.user_id
      AND a.status IN ('assigned','picking_up','delivering','return_approved','returning')
      AND (NOT private.is_recipient_hold(a.delivery_hold)
        OR coalesce((a.delivery_hold->>'until')::timestamptz <= clock_timestamp(),true)
        OR a.delivery_hold->>'return_report_id' IS NOT NULL))
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.id <> o.id
      AND a.offered_driver_id = d.user_id AND a.driver_id IS NULL
      AND a.assignment_timed_out_at IS NULL AND a.status IN ('pending','confirmed')
      AND a.offer_expires_at > now())
    -- Geographic distance only limits API work. Include a 200 m snapping margin.
    AND public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(o.pickup_lng,o.pickup_lat),4326)::public.geography,private.business_number(o.business_policy,'auto_radius_m')+200)
  ORDER BY d.user_id;
$function$
;

