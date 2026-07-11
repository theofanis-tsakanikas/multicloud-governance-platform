#!/bin/sh
# The BigQuery transit gateway: HAProxy, TCP passthrough on :443 to Google's private API VIP,
# across the VPN. See the Dockerfile for why this exists at all.
#
# There is no role switch here, unlike the RDS and Azure SQL gateways. Those needed a `sql`/`seed`
# role because their databases have no public endpoint in private mode, so schema DDL and seeding
# had nowhere else to run from. BigQuery does not work that way: the datasets stay reachable from
# CI over the Google API with IAM, so the seed keeps running from the runner exactly as it does in
# public mode. What private mode changes is where DATABRICKS' traffic goes — and that is all this
# container is for.
#
# VIP_TARGETS is a space-separated list of the private.googleapis.com addresses. Any one of them
# serves every API; listing all four gives HAProxy something to fail over to.
set -eu

: "${VIP_TARGETS:?VIP_TARGETS is required (the private.googleapis.com addresses)}"
# 8443, not 443. The official HAProxy image runs as the unprivileged `haproxy` user, and a
# non-root process cannot bind a port below 1024:
#
#     [ALERT] Binding for frontend api_in: cannot bind socket (Permission denied) for [0.0.0.0:443]
#
# The RDS and Azure SQL gateways never met this — 5432 and 1433 are both above 1024. The NLB
# listens on 443 and forwards here, so Databricks still talks to 443 and nothing runs as root.
: "${LISTEN_PORT:=8443}"

# One backend server line per VIP address.
servers=""
i=1
for ip in $VIP_TARGETS; do
  servers="${servers}    server googleapi${i} ${ip}:443 check
"
  i=$((i + 1))
done

cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log stdout format raw local0
    maxconn 4000

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 10s
    timeout client  1h
    timeout server  1h

frontend api_in
    bind *:${LISTEN_PORT}
    default_backend api_out

backend api_out
    # Pure TCP. HAProxy never sees inside the TLS session — Databricks negotiates it with Google
    # end to end, and Google's frontend routes on the SNI the client sent. That is what lets one
    # backend carry bigquery, bigquerystorage and oauth2 at once.
    balance roundrobin
${servers}
EOF

echo "[bq-gw] HAProxy TCP passthrough :${LISTEN_PORT} → private.googleapis.com VIP [${VIP_TARGETS}] (over the VPN)"
exec haproxy -f /etc/haproxy/haproxy.cfg -db
