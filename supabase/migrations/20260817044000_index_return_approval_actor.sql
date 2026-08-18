-- Cover the approval actor foreign key for staff/user maintenance operations.
CREATE INDEX order_returns_approved_by_idx
  ON public.order_returns(approved_by);
