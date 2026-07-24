-- Drop routes: planned for Phase 3 VRP, never written/read by app code.
-- Keep order_status_logs, reviews (actively used by Flutter services).
-- Do NOT drop geography_columns / geometry_columns / spatial_ref_sys
-- (PostGIS system catalog objects).

DROP TABLE IF EXISTS public.routes;

-- order_status_logs was empty because only SELECT policy existed;
-- client inserts (driver accept / status update / assign fallback) were denied by RLS
-- and swallowed by try/catch in Flutter services.

DROP POLICY IF EXISTS order_status_logs_insert_customer_own ON public.order_status_logs;
CREATE POLICY order_status_logs_insert_customer_own
  ON public.order_status_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_status_logs.order_id
        AND o.customer_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS order_status_logs_insert_driver_assigned ON public.order_status_logs;
CREATE POLICY order_status_logs_insert_driver_assigned
  ON public.order_status_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_status_logs.order_id
        AND o.driver_id = auth.uid()
    )
  );

-- Drivers should see timeline of their assigned orders (customer already can).
DROP POLICY IF EXISTS order_status_logs_select_driver_assigned ON public.order_status_logs;
CREATE POLICY order_status_logs_select_driver_assigned
  ON public.order_status_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_status_logs.order_id
        AND o.driver_id = auth.uid()
    )
  );
