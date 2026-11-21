#!/bin/sh
set +x
set -eu
umask 077
# Only a FIFO, never a master Secret/file. Job has no service-account token or TTY.
mkfifo /tmp/master-in
IFS= read -r PGPASSWORD < /tmp/master-in
rm /tmp/master-in
[ -n "$PGPASSWORD" ]
export PGPASSWORD
# psql's \\password reads confirmation from stdin without a TTY and sends a
# SCRAM verifier, not the cleartext password, to PostgreSQL. No session output.
pw=$(cat /run/app/password)
[ "${#pw}" -eq 64 ]
{ printf '%s\n%s\n' "$pw" "$pw"; } | psql -Xqw -1 -v ON_ERROR_STOP=1 -f /bootstrap/bootstrap.sql >/dev/null 2>&1 || { echo 'Bootstrap transaction failed' >&2; exit 1; }
unset PGPASSWORD
PGUSER=petclinic_app PGPASSWORD="$pw" psql -Xqw -v ON_ERROR_STOP=1 -c 'SELECT id FROM public.owners LIMIT 0' >/dev/null 2>&1 || { echo 'App login or schema check failed; do not regenerate the app secret' >&2; exit 1; }
