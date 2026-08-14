-- The Support queue listens for report inserts and updates through
-- Supabase Realtime. Keep this idempotent for linked environments where the
-- table may already have been enabled manually in the Dashboard.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'risk_reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.risk_reports;
  END IF;
END;
$$;
