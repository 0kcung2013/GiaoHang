-- Keep one permissive SELECT policy so Postgres evaluates a single predicate.
DROP POLICY IF EXISTS order_returns_participant_select
  ON public.order_returns;
DROP POLICY IF EXISTS order_returns_staff_select
  ON public.order_returns;

CREATE POLICY order_returns_related_select
  ON public.order_returns
  FOR SELECT
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.orders participant_order
      WHERE participant_order.id = order_returns.order_id
        AND participant_order.customer_id = (SELECT auth.uid())
    )
    OR EXISTS (
      SELECT 1
      FROM public.users actor
      WHERE actor.id = (SELECT auth.uid())
        AND actor.role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
    )
  );
