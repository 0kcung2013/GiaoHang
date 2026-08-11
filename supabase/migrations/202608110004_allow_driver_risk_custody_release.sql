-- Allow the custody-resolution RPC to release a driver without weakening the
-- normal one-step order progression available to driver clients.

CREATE OR REPLACE FUNCTION public.enforce_driver_order_status_progression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  authorized_custody_release boolean := false;
BEGIN
  IF OLD.driver_id = actor_id
    AND EXISTS (
      SELECT 1
      FROM public.users AS actor
      WHERE actor.id = actor_id
        AND actor.role = 'driver'::public.user_role
    )
  THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.risk_report_interventions AS intervention
      JOIN public.risk_reports AS report
        ON report.id = intervention.risk_report_id
      WHERE report.order_id = OLD.id
        AND intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND (
          (
            intervention.state = 'return_required'
            AND NEW.status = 'cancelled'::public.order_status
            AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id
          )
          OR (
            intervention.state = 'handoff_required'
            AND NEW.status = 'risk_hold'::public.order_status
            AND NEW.driver_id IS NULL
          )
        )
    ) INTO authorized_custody_release;

    IF authorized_custody_release THEN
      IF (to_jsonb(NEW)
          - 'status'
          - 'driver_id'
          - 'status_note'
          - 'cancelled_at'
          - 'updated_at') <>
         (to_jsonb(OLD)
          - 'status'
          - 'driver_id'
          - 'status_note'
          - 'cancelled_at'
          - 'updated_at') THEN
        RAISE EXCEPTION
          'Custody resolution may only update approved order release fields.';
      END IF;

      RETURN NEW;
    END IF;

    IF (to_jsonb(NEW) - 'status' - 'updated_at') <>
       (to_jsonb(OLD) - 'status' - 'updated_at') THEN
      RAISE EXCEPTION 'Drivers may only update order status fields.';
    END IF;

    IF NOT (
      (OLD.status = 'assigned'::public.order_status AND NEW.status = 'picking_up'::public.order_status)
      OR (OLD.status = 'picking_up'::public.order_status AND NEW.status = 'delivering'::public.order_status)
      OR (OLD.status = 'delivering'::public.order_status AND NEW.status = 'delivered'::public.order_status)
    ) THEN
      RAISE EXCEPTION 'Invalid driver order status transition.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_driver_order_status_progression()
  FROM public, anon, authenticated, service_role;

COMMENT ON FUNCTION public.enforce_driver_order_status_progression() IS
  'Restricts driver order updates while permitting RPC-authorized risk custody release.';
