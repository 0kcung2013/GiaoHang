-- Durable return-order workflow built on the existing risk intervention flow.
-- This migration is local-only until the project verification gate passes.

CREATE TABLE public.order_returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL UNIQUE
    REFERENCES public.orders(id) ON DELETE RESTRICT,
  risk_report_id uuid NOT NULL UNIQUE
    REFERENCES public.risk_reports(id) ON DELETE RESTRICT,
  driver_id uuid NOT NULL
    REFERENCES public.users(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'approved'
    CHECK (status IN ('approved', 'returning', 'returned')),
  destination_type text NOT NULL
    CHECK (destination_type IN ('sender', 'processing_center')),
  destination_address text NOT NULL
    CHECK (char_length(trim(destination_address)) BETWEEN 3 AND 500),
  destination_lat double precision NOT NULL
    CHECK (destination_lat BETWEEN -90 AND 90),
  destination_lng double precision NOT NULL
    CHECK (destination_lng BETWEEN -180 AND 180),
  route_origin_lat double precision NOT NULL
    CHECK (route_origin_lat BETWEEN -90 AND 90),
  route_origin_lng double precision NOT NULL
    CHECK (route_origin_lng BETWEEN -180 AND 180),
  route_distance_m integer NOT NULL CHECK (route_distance_m >= 0),
  route_duration_s integer NOT NULL CHECK (route_duration_s >= 0),
  quote_source text NOT NULL CHECK (quote_source IN ('osrm', 'fallback')),
  reason_code text NOT NULL
    CHECK (char_length(trim(reason_code)) BETWEEN 3 AND 80),
  fee_payer text NOT NULL
    CHECK (fee_payer IN ('customer', 'platform', 'pending_support')),
  customer_return_charge bigint NOT NULL DEFAULT 0
    CHECK (customer_return_charge >= 0),
  driver_return_earning bigint NOT NULL DEFAULT 0
    CHECK (driver_return_earning >= 0),
  fee_status text NOT NULL DEFAULT 'approved'
    CHECK (fee_status IN ('quoted', 'approved', 'settled', 'waived')),
  instruction text
    CHECK (instruction IS NULL OR char_length(trim(instruction)) <= 4000),
  receiver_name text
    CHECK (receiver_name IS NULL OR char_length(trim(receiver_name)) BETWEEN 2 AND 80),
  proof_storage_path text,
  approved_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  approved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  started_at timestamptz,
  arrived_at timestamptz,
  returned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX order_returns_driver_status_idx
  ON public.order_returns(driver_id, status, updated_at DESC);
CREATE INDEX order_returns_status_updated_idx
  ON public.order_returns(status, updated_at DESC);

ALTER TABLE public.order_returns ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.order_returns FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.order_returns FROM authenticated;
GRANT SELECT ON public.order_returns TO authenticated;

CREATE POLICY order_returns_participant_select
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
  );

CREATE POLICY order_returns_staff_select
  ON public.order_returns
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users actor
      WHERE actor.id = (SELECT auth.uid())
        AND actor.role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
    )
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'order_returns'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.order_returns;
  END IF;
END;
$$;

-- Keep a driver occupied throughout an approved or active return mission.
DROP INDEX IF EXISTS public.orders_one_active_per_driver_idx;
CREATE UNIQUE INDEX orders_one_active_per_driver_idx
  ON public.orders(driver_id)
  WHERE driver_id IS NOT NULL
    AND status IN (
      'assigned'::public.order_status,
      'picking_up'::public.order_status,
      'delivering'::public.order_status,
      'return_approved'::public.order_status,
      'returning'::public.order_status
    );

-- Return handoff uses the same private proof bucket as pickup/delivery.
ALTER TABLE public.order_delivery_proofs
  DROP CONSTRAINT IF EXISTS order_delivery_proofs_stage_check;
ALTER TABLE public.order_delivery_proofs
  ADD CONSTRAINT order_delivery_proofs_stage_check
  CHECK (stage IN ('pickup', 'delivery', 'return'));

DROP POLICY IF EXISTS order_delivery_proofs_insert_assigned_driver
  ON public.order_delivery_proofs;
CREATE POLICY order_delivery_proofs_insert_assigned_driver
  ON public.order_delivery_proofs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.orders proof_order
      WHERE proof_order.id = order_delivery_proofs.order_id
        AND proof_order.driver_id = (SELECT auth.uid())
        AND (
          (order_delivery_proofs.stage = 'pickup'
            AND proof_order.status = 'picking_up'::public.order_status)
          OR (order_delivery_proofs.stage = 'delivery'
            AND proof_order.status = 'delivering'::public.order_status)
          OR (order_delivery_proofs.stage = 'return'
            AND proof_order.status = 'returning'::public.order_status)
        )
    )
  );

DROP POLICY IF EXISTS order_delivery_proofs_update_assigned_driver
  ON public.order_delivery_proofs;
CREATE POLICY order_delivery_proofs_update_assigned_driver
  ON public.order_delivery_proofs
  FOR UPDATE
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.orders proof_order
      WHERE proof_order.id = order_delivery_proofs.order_id
        AND proof_order.driver_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.orders proof_order
      WHERE proof_order.id = order_delivery_proofs.order_id
        AND proof_order.driver_id = (SELECT auth.uid())
        AND (
          (order_delivery_proofs.stage = 'pickup'
            AND proof_order.status = 'picking_up'::public.order_status)
          OR (order_delivery_proofs.stage = 'delivery'
            AND proof_order.status = 'delivering'::public.order_status)
          OR (order_delivery_proofs.stage = 'return'
            AND proof_order.status = 'returning'::public.order_status)
        )
    )
  );

DROP POLICY IF EXISTS delivery_proofs_insert_current_stage ON storage.objects;
CREATE POLICY delivery_proofs_insert_current_stage
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND storage.filename(name) IN ('pickup', 'delivery', 'return')
    AND EXISTS (
      SELECT 1
      FROM public.orders proof_order
      WHERE proof_order.id::text = (storage.foldername(name))[2]
        AND proof_order.driver_id = (SELECT auth.uid())
        AND (
          (storage.filename(name) = 'pickup'
            AND proof_order.status = 'picking_up'::public.order_status)
          OR (storage.filename(name) = 'delivery'
            AND proof_order.status = 'delivering'::public.order_status)
          OR (storage.filename(name) = 'return'
            AND proof_order.status = 'returning'::public.order_status)
        )
    )
  );

DROP POLICY IF EXISTS delivery_proofs_update_current_stage ON storage.objects;
CREATE POLICY delivery_proofs_update_current_stage
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND EXISTS (
      SELECT 1 FROM public.orders proof_order
      WHERE proof_order.id::text = (storage.foldername(name))[2]
        AND proof_order.driver_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND storage.filename(name) IN ('pickup', 'delivery', 'return')
    AND EXISTS (
      SELECT 1
      FROM public.orders proof_order
      WHERE proof_order.id::text = (storage.foldername(name))[2]
        AND proof_order.driver_id = (SELECT auth.uid())
        AND (
          (storage.filename(name) = 'pickup'
            AND proof_order.status = 'picking_up'::public.order_status)
          OR (storage.filename(name) = 'delivery'
            AND proof_order.status = 'delivering'::public.order_status)
          OR (storage.filename(name) = 'return'
            AND proof_order.status = 'returning'::public.order_status)
        )
    )
  );

ALTER TABLE public.driver_wallet_transactions
  DROP CONSTRAINT IF EXISTS driver_wallet_transactions_transaction_type_check;
ALTER TABLE public.driver_wallet_transactions
  ADD CONSTRAINT driver_wallet_transactions_transaction_type_check
  CHECK (transaction_type IN (
    'vnpay_topup',
    'cod_hold',
    'cod_release',
    'cod_advance_capture',
    'platform_fee_capture',
    'prepaid_earning',
    'cod_settlement',
    'return_earning'
  ));

ALTER TABLE public.risk_report_events
  DROP CONSTRAINT IF EXISTS risk_report_events_event_type_check;
ALTER TABLE public.risk_report_events
  ADD CONSTRAINT risk_report_events_event_type_check
  CHECK (event_type IN (
    'created',
    'updated',
    'assigned',
    'status_changed',
    'intervention_changed',
    'note_added',
    'message_added',
    'ticket_linked',
    'return_approved',
    'return_started',
    'return_completed'
  ));

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'order_update',
    'promotion',
    'system',
    'support_ticket_created',
    'support_ticket_accepted',
    'support_ticket_status',
    'support_ticket_admin_required',
    'support_ticket_message',
    'support_ticket_customer_message',
    'support_ticket_converted',
    'support_ticket_sla_overdue',
    'risk_report_accepted',
    'risk_report_status',
    'risk_report_admin_required',
    'risk_report_message',
    'risk_report_participant_message',
    'risk_report_sla_overdue',
    'order_return_approved',
    'order_return_started',
    'order_return_completed'
  ));

-- Custody guard: only the approved return state machine may move a return.

