-- Support (CSKH) tối thiểu: tra cứu đơn, xem timeline và ghi nhận hỗ trợ.
-- Support không được cập nhật orders, drivers, GPS hoặc KYC.

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  customer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  assigned_to uuid REFERENCES public.users(id) ON DELETE SET NULL,
  subject text NOT NULL CHECK (char_length(trim(subject)) BETWEEN 3 AND 160),
  message text NOT NULL CHECK (char_length(trim(message)) BETWEEN 1 AND 4000),
  resolution text CHECK (resolution IS NULL OR char_length(resolution) <= 4000),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS support_tickets_order_idx ON public.support_tickets(order_id, created_at DESC);
CREATE INDEX IF NOT EXISTS support_tickets_assigned_status_idx ON public.support_tickets(assigned_to, status, updated_at DESC);
CREATE INDEX IF NOT EXISTS support_tickets_customer_idx ON public.support_tickets(customer_id, created_at DESC);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY support_tickets_customer_select ON public.support_tickets FOR SELECT TO authenticated
  USING (customer_id = (SELECT auth.uid()));
CREATE POLICY support_tickets_customer_insert ON public.support_tickets FOR INSERT TO authenticated
  WITH CHECK (customer_id = (SELECT auth.uid()) AND created_by = (SELECT auth.uid()));
CREATE POLICY support_tickets_staff_select ON public.support_tickets FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = (SELECT auth.uid())
    AND u.role IN ('support'::public.user_role, 'admin'::public.user_role)));
CREATE POLICY support_tickets_staff_insert ON public.support_tickets FOR INSERT TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()) AND EXISTS (SELECT 1 FROM public.users u
    WHERE u.id = (SELECT auth.uid()) AND u.role IN ('support'::public.user_role, 'admin'::public.user_role)));
CREATE POLICY support_tickets_staff_update ON public.support_tickets FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = (SELECT auth.uid())
    AND u.role IN ('support'::public.user_role, 'admin'::public.user_role)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.users u WHERE u.id = (SELECT auth.uid())
    AND u.role IN ('support'::public.user_role, 'admin'::public.user_role)));

CREATE POLICY orders_select_support ON public.orders FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = (SELECT auth.uid())
    AND u.role IN ('support'::public.user_role, 'admin'::public.user_role)));
CREATE POLICY order_status_logs_select_support ON public.order_status_logs FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = (SELECT auth.uid())
    AND u.role IN ('support'::public.user_role, 'admin'::public.user_role)));

CREATE OR REPLACE FUNCTION public.set_support_ticket_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  IF NEW.status IN ('resolved', 'closed') AND OLD.status NOT IN ('resolved', 'closed') THEN
    NEW.resolved_at = COALESCE(NEW.resolved_at, now());
  ELSIF NEW.status NOT IN ('resolved', 'closed') THEN
    NEW.resolved_at = NULL;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER support_tickets_updated_at
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_support_ticket_updated_at();
