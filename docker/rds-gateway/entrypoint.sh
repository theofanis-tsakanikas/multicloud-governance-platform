#!/bin/sh
# The RDS gateway's three roles. See the Dockerfile for why one image does all three.
#
#   gateway  (default)  pgbouncer, listening on :5432 — the NLB's target
#   sql <statement>     run one statement against RDS, from inside the VPC
#   seed                run the baked source-system seed, from inside the VPC
#
# Everything comes from the environment; nothing is baked but the seed. The password arrives as
# an ECS `secrets` entry (Secrets Manager → env), so it is never in the image, never in the task
# definition, and never in a log.
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:=5432}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${DB_NAME:=salesdb}"

ROLE="${1:-gateway}"

# ── psql, for the two one-shot roles ────────────────────────────────────────────────────────
# These talk to RDS *directly*, not through pgbouncer: the task runs in the ECS security group,
# and the RDS security group admits 5432 from exactly that group. It is the only door in.
run_psql() {
  PGPASSWORD="$DB_PASSWORD" \
  PGSSLMODE=require \
  psql --host="$PSQL_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname="$DB_NAME" \
       --no-password --set ON_ERROR_STOP=1 --quiet "$@"
}

case "$ROLE" in
  sql|seed)
    # DB_HOST is the RDS Proxy endpoint (that is what the gateway role needs). The one-shot
    # roles want the database itself: RDS_HOST is passed for them, and the proxy would work too,
    # but going straight at the instance keeps DDL out of the pooler's transaction semantics.
    PSQL_HOST="${RDS_HOST:-$DB_HOST}"

    if [ "$ROLE" = "seed" ]; then
      echo "[gateway] seeding ${DB_NAME} on ${PSQL_HOST} from the baked source-system seed"
      run_psql --file=/opt/seed.sql
      run_psql --command="SELECT 'customers' AS t, count(*) FROM crm.customers
                          UNION ALL SELECT 'orders', count(*) FROM orders.orders;"
    else
      shift
      [ $# -ge 1 ] || { echo "[gateway] usage: sql <statement>" >&2; exit 2; }
      echo "[gateway] running SQL against ${DB_NAME} on ${PSQL_HOST}"
      run_psql --command="$*"
    fi
    echo "[gateway] ok"
    exit 0
    ;;
esac

# ── gateway: pgbouncer ──────────────────────────────────────────────────────────────────────

: "${AUTH_TYPE:=scram-sha-256}"
: "${POOL_MODE:=transaction}"
: "${MAX_CLIENT_CONN:=1000}"

# Databricks opens the connection with sslmode=require. pgbouncer will only speak TLS if it has
# a certificate, and there is nobody to issue it one — the whole path lives inside a VPC behind
# PrivateLink and never touches a public name. So: self-signed, generated per task, never
# persisted. `client_tls_sslmode = allow` means "TLS if the client asks, plaintext if not",
# which keeps the NLB's bare TCP health check working while Databricks still gets an encrypted
# session. Certificate *verification* buys nothing here — PrivateLink already proves who the
# peer is, and a cert nobody can validate would only be theatre.
CERT_DIR=/var/run/pgbouncer
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" \
  -subj "/CN=rds-gateway" 2>/dev/null
chmod 600 "$CERT_DIR/server.key"

# pgbouncer authenticates the client itself, then opens its own pooled connection to RDS Proxy
# with the same credentials. The proxy is configured auth_scheme = SECRETS, so it validates them
# against Secrets Manager and holds the real connection to Postgres.
#
# The password is in plaintext here — in a tmpfs file, in a container, in a private subnet. That
# is what pgbouncer needs to compute SCRAM for an incoming client, and there is no form of the
# secret that both satisfies that and is unreadable to the process that must read it.
printf '"%s" "%s"\n' "$DB_USER" "$DB_PASSWORD" > "$CERT_DIR/userlist.txt"
chmod 600 "$CERT_DIR/userlist.txt"

cat > /etc/pgbouncer/pgbouncer.ini <<EOF
[databases]
; Forward every database through to the proxy — the catalog decides the name, not this file.
* = host=${DB_HOST} port=${DB_PORT}

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 5432

auth_type = ${AUTH_TYPE}
auth_file = ${CERT_DIR}/userlist.txt

pool_mode        = ${POOL_MODE}
max_client_conn  = ${MAX_CLIENT_CONN}
default_pool_size = 20

; RDS Proxy is created with require_tls = true; anything less is refused at the door.
server_tls_sslmode = require

; Accept TLS from Databricks, tolerate the NLB's plaintext TCP health check.
client_tls_sslmode  = allow
client_tls_key_file  = ${CERT_DIR}/server.key
client_tls_cert_file = ${CERT_DIR}/server.crt

; Databricks' JDBC driver sends startup parameters pgbouncer does not proxy. Refusing them
; fails the connection at handshake, with an error that names none of this.
ignore_startup_parameters = extra_float_digits,options,search_path

logfile  =
pidfile  =
admin_users = ${DB_USER}
EOF

echo "[gateway] pgbouncer → ${DB_HOST}:${DB_PORT} (pool=${POOL_MODE}, auth=${AUTH_TYPE})"
exec pgbouncer /etc/pgbouncer/pgbouncer.ini
