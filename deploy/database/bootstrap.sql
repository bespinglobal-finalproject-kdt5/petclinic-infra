\set ON_ERROR_STOP on
BEGIN;

DO $check$
BEGIN
  IF current_database() <> 'petclinic' THEN
    RAISE EXCEPTION 'Connect to the petclinic database before running this script';
  END IF;
END
$check$;

SELECT pg_advisory_xact_lock(hashtext('petclinic:bootstrap'));
SET LOCAL search_path TO public;
SELECT NOT EXISTS (
  SELECT FROM pg_tables WHERE schemaname = 'public'
) AS empty_schema \gset

\if :empty_schema
  \i :schema_file
\endif

SELECT 'CREATE ROLE petclinic_app LOGIN' WHERE NOT EXISTS (
  SELECT FROM pg_roles WHERE rolname = 'petclinic_app'
) \gexec

GRANT CONNECT ON DATABASE petclinic TO petclinic_app;
GRANT USAGE ON SCHEMA public TO petclinic_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.vets, public.specialties, public.vet_specialties, public.types, public.owners,
  public.pets, public.visits, public.users, public.roles TO petclinic_app;
GRANT USAGE, SELECT ON SEQUENCE
  public.vets_id_seq, public.specialties_id_seq, public.types_id_seq, public.owners_id_seq,
  public.pets_id_seq, public.visits_id_seq, public.roles_id_seq TO petclinic_app;

-- Let psql prompt for the Secrets Manager password and hash it on the client.
SET LOCAL password_encryption TO 'scram-sha-256';
\password petclinic_app
COMMIT;
