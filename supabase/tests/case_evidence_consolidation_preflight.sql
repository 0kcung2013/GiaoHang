-- Include inside a rollback transaction BEFORE the consolidation migration.
-- Covers both mirrored and unmirrored legacy notes without retaining fixtures.
DO $legacy_fixture$
DECLARE staff uuid := gen_random_uuid(); requester uuid := gen_random_uuid();
  order_id uuid := gen_random_uuid(); report_id uuid := gen_random_uuid();
BEGIN
  PERFORM set_config('request.jwt.claim.sub','',true);
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (staff,staff::text || '@consolidation-test.invalid','Legacy support','support'),
    (requester,requester::text || '@consolidation-test.invalid','Legacy requester','customer');
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
  VALUES(order_id,requester,'cancelled','Synthetic pickup',11,106,
    'Synthetic delivery',11.01,106.01,'GH-DEMO-CONSOLIDATE-LEGACY-' || order_id::text);
  PERFORM set_config('request.jwt.claim.sub',staff::text,true);
  INSERT INTO public.risk_reports(id,order_id,reported_by,assigned_to,updated_by,source,
    category,severity,status,title,description)
  VALUES(report_id,order_id,staff,staff,staff,'manual','other','medium','investigating',
    'Legacy fixture','Synthetic legacy internal-note migration');
  PERFORM public.add_risk_report_note(report_id,'Consolidation mirrored legacy note');
  INSERT INTO public.risk_report_notes(risk_report_id,author_id,body)
  VALUES(report_id,staff,'Consolidation unmirrored legacy note');
  PERFORM set_config('request.jwt.claim.sub','',true);
END;
$legacy_fixture$;
