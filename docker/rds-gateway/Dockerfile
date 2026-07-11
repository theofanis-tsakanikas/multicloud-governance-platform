# The RDS gateway — the one piece of the private path that Terraform cannot conjure.
#
# In private mode the RDS instance has no public address at all. Databricks serverless reaches
# it over PrivateLink, and PrivateLink terminates on a Network Load Balancer, and an NLB needs a
# target with a stable IP inside the VPC. RDS Proxy has a DNS name, not an IP, so it cannot be
# that target. Something has to sit in the middle. This is that something.
#
#     Databricks serverless
#       └─ NCC private endpoint rule  →  VPC Endpoint Service  →  NLB :5432
#            └─ THIS CONTAINER (Fargate, private subnet, stable ENI)
#                 └─ RDS Proxy (require_tls)  →  RDS Postgres (publicly_accessible = false)
#
# The ECS task definition has always pointed at `<acct>.dkr.ecr.<region>.amazonaws.com/
# pgbouncer-gateway:latest`. Nothing in the repo ever built it. Terraform applied green, the
# task crash-looped on CannotPullContainerError, the target group never went healthy, and the
# private path was dead behind a successful deploy. (`wait_for_steady_state` on the service now
# makes that failure loud, but the image still has to exist.)
#
# THREE JOBS, ONE IMAGE — see entrypoint.sh:
#
#   gateway  (default)  pgbouncer: the NLB target
#   sql <stmt>          run one statement against RDS
#   seed                run the baked source-system seed
#
# The last two exist because a private RDS is unreachable from a GitHub runner *by design* —
# no public address, and a security group that admits only this container's own group. So the
# schema DDL and the seed have to run from inside the VPC, and this is the only thing in there.
# They are a `docker run` away, as a one-shot ECS task, from the same image and the same subnet.

FROM alpine:3.20

# pgbouncer  — the gateway itself
# postgresql-client — psql, for the `sql` and `seed` roles
# openssl    — a self-signed cert so pgbouncer can accept TLS from Databricks (see entrypoint)
RUN apk add --no-cache pgbouncer postgresql16-client openssl ca-certificates \
    # The package is expected to create this user; don't stake the build on it.
    && (getent group pgbouncer  >/dev/null || addgroup -S pgbouncer) \
    && (getent passwd pgbouncer >/dev/null || adduser  -S -G pgbouncer pgbouncer) \
    && mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer

# The simulated source system's own seed travels with it (ADR-0014). Baking it in is what lets
# the `seed` role run without the file being reachable from anywhere inside the VPC.
COPY pipelines/sources/rds/seed.sql /opt/seed.sql

COPY docker/rds-gateway/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 5432
USER pgbouncer

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gateway"]
