-- Existing dispatch boundary, no committed driver/order changes.
BEGIN;
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
DO $$
DECLARE d public.drivers%ROWTYPE; before_count integer; after_count integer;
BEGIN
 SELECT * INTO STRICT d FROM public.drivers
 WHERE is_available=true AND approval_status='approved'
   AND location_updated_at<clock_timestamp()-interval '3 minutes'
   AND current_lat IS NOT NULL AND current_lng IS NOT NULL
   AND coalesce(acceptance_locked_until,'-infinity')<clock_timestamp()
   AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.driver_id=drivers.user_id
     AND o.status IN ('assigned','picking_up','delivering','return_approved','returning'))
 ORDER BY location_updated_at DESC LIMIT 1;
 SELECT count(*) INTO before_count FROM public.road_lookup_candidates(d.current_lat,d.current_lng,2000,50) c
 WHERE c.user_id=d.user_id;
 UPDATE public.drivers SET location_updated_at=clock_timestamp() WHERE user_id=d.user_id;
 SELECT count(*) INTO after_count FROM public.road_lookup_candidates(d.current_lat,d.current_lng,2000,50) c
 WHERE c.user_id=d.user_id;
 IF before_count<>0 OR after_count<>1 THEN
   RAISE EXCEPTION 'Presence/discovery regression: before %, after %',before_count,after_count;
 END IF;
END; $$;
ROLLBACK;
