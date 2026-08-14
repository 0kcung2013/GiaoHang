-- Supabase Storage returns the inserted object's metadata after an upload.
-- Let the uploader read that row before the risk report RPC registers it as
-- an attachment. Registered evidence remains available to Support/Admin via
-- risk_evidence_select_registered.
DROP POLICY IF EXISTS risk_evidence_select_own_prefix ON storage.objects;

CREATE POLICY risk_evidence_select_own_prefix
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'risk-report-evidence'
  AND owner_id = (SELECT auth.uid())::text
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
