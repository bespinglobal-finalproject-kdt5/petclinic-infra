-- Called with -1 (one transaction) and ON_ERROR_STOP. Application pods never run DDL.
SELECT pg_advisory_xact_lock(7041983);
SELECT to_regclass('petclinic_bootstrap.schema_v1') IS NOT NULL AS initialized \gset
\if :initialized
  -- Do not change credentials or run the non-idempotent indexes a second time.
  SELECT 1 FROM petclinic_bootstrap.schema_v1;
\else
  DO $$ BEGIN
    IF EXISTS (SELECT FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind IN ('r','p','S','v','m','f')) THEN
      RAISE EXCEPTION 'Unmarked database is not empty';
    END IF;
  END $$;
  CREATE SCHEMA petclinic_bootstrap;
  REVOKE ALL ON SCHEMA petclinic_bootstrap FROM PUBLIC;
  REVOKE ALL ON DATABASE petclinic FROM PUBLIC;
  REVOKE CREATE ON SCHEMA public FROM PUBLIC;
  CREATE ROLE petclinic_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
  SET LOCAL password_encryption = 'scram-sha-256';
  \password petclinic_app
  SET LOCAL search_path = public;
  \ir schema.sql
  GRANT CONNECT ON DATABASE petclinic TO petclinic_app;
  GRANT USAGE ON SCHEMA public TO petclinic_app;
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO petclinic_app;
  GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO petclinic_app;
  CREATE TABLE petclinic_bootstrap.schema_v1 (installed_at timestamptz NOT NULL DEFAULT now());
  INSERT INTO petclinic_bootstrap.schema_v1 DEFAULT VALUES;
\endif
