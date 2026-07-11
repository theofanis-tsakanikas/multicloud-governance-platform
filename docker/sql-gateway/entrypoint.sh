#!/bin/sh
# The Azure SQL transit gateway's three roles. See the Dockerfile for why one image does all three.
#
#   gateway  (default)  HAProxy TCP passthrough on :1433 → Azure SQL over the VPN — the NLB target
#   sql <statement>     run one T-SQL statement against Azure SQL, from inside the AWS VPC
#   seed                run the baked source-system seed
#
# TARGET_HOST is the Azure SQL FQDN (e.g. sql-federation-master-abcd.database.windows.net). The
# container resolves it through the VPC's Route53 private zone "database.windows.net", which the
# VPN module points at the Azure private endpoint IP — so the name resolves to a private address
# reachable only across the tunnel. Nothing here ever touches the public internet.
set -eu

: "${TARGET_HOST:?TARGET_HOST is required (the Azure SQL FQDN)}"
: "${TARGET_PORT:=1433}"

ROLE="${1:-gateway}"

# ── psql-equivalent for the two one-shot roles: sqlcmd, straight to Azure SQL over the VPN ─────
#
# The database is a SERVERLESS SKU with a 60-minute auto-pause. The first connection after an idle
# period is what wakes it, and while it wakes — about a minute — every attempt is refused with:
#
#     Database '...' is not currently available. Please retry the connection later.
#
# That is not an error, it is the resume. apply_seed.py already learned this and retries; this
# image has to as well, or the deploy fails on a database that is in the middle of coming back.
MAX_ATTEMPTS="${MAX_ATTEMPTS:-12}"
BACKOFF="${BACKOFF:-15}"

run_sqlcmd() {
  # -C trusts the server certificate: we reach Azure SQL by its real FQDN across the tunnel, and
  # the cert it presents is its own for *.database.windows.net. -b makes a SQL error a non-zero
  # exit, so a failed statement fails the task instead of passing silently.
  attempt=1
  while : ; do
    if sqlcmd -S "tcp:${TARGET_HOST},${TARGET_PORT}" \
              -U "$DB_USER" -P "$DB_PASSWORD" -d "${DB_NAME:-master}" \
              -C -b -l 60 "$@"; then
      return 0
    fi
    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
      echo "[sql-gw] gave up after ${attempt} attempts" >&2
      return 1
    fi
    echo "[sql-gw] attempt ${attempt}/${MAX_ATTEMPTS} failed — the serverless database is probably resuming; retrying in ${BACKOFF}s"
    attempt=$((attempt + 1))
    sleep "$BACKOFF"
  done
}

case "$ROLE" in
  sql|seed)
    : "${DB_USER:?DB_USER is required}"
    : "${DB_PASSWORD:?DB_PASSWORD is required}"

    if [ "$ROLE" = "seed" ]; then
      echo "[sql-gw] seeding ${DB_NAME:-master} on ${TARGET_HOST} from the baked source-system seed"
      run_sqlcmd -i /opt/seed.sql
      run_sqlcmd -Q "SELECT 'inventory.stock' AS t, COUNT(*) AS n FROM inventory.stock
                     UNION ALL SELECT 'orders.purchase_orders', COUNT(*) FROM orders.purchase_orders;"
    else
      shift
      [ $# -ge 1 ] || { echo "[sql-gw] usage: sql <statement>" >&2; exit 2; }
      echo "[sql-gw] running SQL against ${DB_NAME:-master} on ${TARGET_HOST}"
      run_sqlcmd -Q "$*"
    fi
    echo "[sql-gw] ok"
    exit 0
    ;;
esac

# ── gateway: HAProxy TCP passthrough ──────────────────────────────────────────────────────────
# HAProxy re-resolves TARGET_HOST at runtime through the AWS VPC resolver (169.254.169.253), so
# it survives the private endpoint IP changing and does not need the VPN up at container start.
# `mode tcp` means it never parses TDS — the TLS handshake is Databricks↔AzureSQL, opaque to us.
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log stdout format raw local0
    maxconn 2000

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 10s
    timeout client  1h
    timeout server  1h

resolvers awsvpc
    nameserver vpc 169.254.169.253:53
    resolve_retries 3
    timeout resolve 1s
    timeout retry   1s
    hold valid 10s

frontend sql_in
    bind *:${TARGET_PORT}
    default_backend sql_out

backend sql_out
    server azuresql ${TARGET_HOST}:${TARGET_PORT} check resolvers awsvpc init-addr none
EOF

echo "[sql-gw] HAProxy TCP passthrough :${TARGET_PORT} → ${TARGET_HOST}:${TARGET_PORT} (over the VPN)"
exec haproxy -f /etc/haproxy/haproxy.cfg -db
