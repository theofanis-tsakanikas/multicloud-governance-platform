# The Azure SQL transit gateway — the AWS end of a cross-cloud private path.
#
# Azure SQL cannot be an AWS PrivateLink target, so Databricks serverless (an AWS Databricks
# account) cannot point an NCC private-endpoint rule straight at it the way it does at RDS. The
# transit-hub design routes around that: the NCC rule points at an AWS PrivateLink service, that
# fronts an NLB, the NLB fronts THIS container, and this container bridges over a Site-to-Site
# VPN to Azure SQL's private endpoint.
#
#     Databricks serverless (AWS)
#       └─ NCC rule → PrivateLink service → NLB :1433
#            └─ THIS CONTAINER (Fargate, AWS VPC 10.10.0.0/16)
#                 └─ IPsec VPN → Azure private endpoint → Azure SQL (public access OFF)
#
# It is the SQL-Server twin of docker/rds-gateway, and deliberately the same shape: one image,
# three roles (see entrypoint.sh). HAProxy replaces pgbouncer because SQL Server speaks TDS, not
# the Postgres wire protocol — and a TDS-aware pooler buys nothing here, since Databricks manages
# its own connections. HAProxy is a transparent TCP passthrough: the TLS session is end-to-end
# between Databricks and Azure SQL, and this container never sees a credential in the gateway role.
#
# The `sql` and `seed` roles exist for the same reason they do on the RDS side: a private Azure
# SQL has no public endpoint, so its schema DDL and its seed cannot run from a GitHub runner.
# They run from HERE — the one place already inside a network that reaches it — as a one-shot
# ECS task, resolving the Azure SQL FQDN across the VPN via the VPC's Route53 zone.

FROM debian:bookworm-slim

# haproxy       — the gateway itself (TCP passthrough)
# sqlcmd (mssql-tools18) — the `sql` and `seed` roles
# The Microsoft apt repo is the supported way to get sqlcmd on Debian; ACCEPT_EULA is required.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         haproxy curl gnupg apt-transport-https ca-certificates \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
         | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
         > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 mssql-tools18 \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/mssql-tools18/bin:${PATH}"

# The simulated source system's own seed travels with the image (ADR-0014), so the `seed` role
# can run without the file being reachable from anywhere inside the VPC.
COPY pipelines/sources/azure_sql/seed.sql /opt/seed.sql

COPY docker/sql-gateway/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 1433
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gateway"]
