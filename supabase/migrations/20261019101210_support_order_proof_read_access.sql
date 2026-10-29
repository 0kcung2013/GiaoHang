-- Approved 2026-10-19: CSKH/Admin may read order handoff photos.
-- Keep all participant policies and write permissions unchanged.
CREATE POLICY order_delivery_proofs_select_staff
ON public.order_delivery_proofs FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN ('support', 'admin')
  )
  AND EXISTS (
    SELECT 1 FROM public.orders proof_order
    WHERE proof_order.id = order_delivery_proofs.order_id
  )
);

-- Legacy private files must also be registered proof references.
-- R2 already authorizes staff download tickets; its pipeline is unchanged.
CREATE POLICY delivery_proofs_select_registered_staff
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'delivery-proofs'
  AND EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN ('support', 'admin')
  )
  AND EXISTS (
    SELECT 1 FROM public.order_delivery_proofs proof
    WHERE proof.storage_path = storage.objects.name
  )
);
