-- A column REVOKE cannot override a table-level INSERT/UPDATE grant.
-- Expand only existing table grants; retain access to all pre-existing columns.
DO $grant$
DECLARE
  role_name text;
  relation_name text;
  privilege_name text;
  columns_sql text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
    FOREACH relation_name IN ARRAY ARRAY['orders','drivers'] LOOP
      FOREACH privilege_name IN ARRAY ARRAY['INSERT','UPDATE'] LOOP
        IF pg_catalog.has_table_privilege(role_name, 'public.' || relation_name, privilege_name) THEN
          SELECT pg_catalog.string_agg(pg_catalog.quote_ident(attname), ', ' ORDER BY attnum)
          INTO columns_sql
          FROM pg_catalog.pg_attribute
          WHERE attrelid = ('public.' || relation_name)::regclass
            AND attnum > 0 AND NOT attisdropped
            AND attname NOT IN ('pickup_arrived_at','acceptance_locked_until');
          EXECUTE pg_catalog.format('REVOKE %s ON TABLE public.%I FROM %I',privilege_name,relation_name,role_name);
          EXECUTE pg_catalog.format('GRANT %s (%s) ON TABLE public.%I TO %I',
            privilege_name,columns_sql,relation_name,role_name);
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;
END;
$grant$;
REVOKE INSERT (pickup_arrived_at), UPDATE (pickup_arrived_at) ON public.orders FROM PUBLIC, anon, authenticated;
REVOKE INSERT (acceptance_locked_until), UPDATE (acceptance_locked_until) ON public.drivers FROM PUBLIC, anon, authenticated;
