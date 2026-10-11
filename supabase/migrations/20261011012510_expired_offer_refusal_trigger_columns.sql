-- Invitation expiry usually changes just the offer columns, rather than status.
-- Extend the existing trigger so it audits every expired invitation withdrawal
-- or replacement; preserves the previously approved refusal policy and schema.
CREATE OR REPLACE TRIGGER orders_00_clear_offer_state
  BEFORE UPDATE OF status, driver_id, assignment_timed_out_at,
    offered_driver_id, offer_expires_at
  ON public.orders FOR EACH ROW
  EXECUTE FUNCTION private.clear_order_offer_on_inactive_state();
