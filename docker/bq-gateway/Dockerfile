# The BigQuery transit gateway — the AWS end of the third private path.
#
# BigQuery is a Google-managed API, not a database in a VPC, so there is nothing to put a private
# endpoint in front of. Google's answer is the private.googleapis.com VIP (199.36.153.8/30): a set
# of addresses that front essentially every Google API and are reachable only from inside a Google
# network — or from a network joined to one by a VPN or Interconnect.
#
# Databricks serverless runs in an AWS Databricks account, so it cannot reach that VIP directly and
# cannot create a GCP endpoint. Same wall as Azure SQL, same way around it — the transit hub:
#
#     Databricks serverless (AWS)
#       └─ NCC rule → PrivateLink service → NLB :443
#            └─ THIS CONTAINER (Fargate, AWS transit VPC 10.11.0.0/16)
#                 └─ IPsec VPN → GCP VPC → private.googleapis.com VIP → BigQuery
#
# It is the simplest of the three gateways: a pure TCP passthrough. It never terminates TLS, so the
# session is end-to-end between Databricks and Google, and the SNI the client sends
# (bigquery.googleapis.com, bigquerystorage.googleapis.com, oauth2.googleapis.com) is what Google's
# frontend routes on. The gateway holds no credential and understands no protocol — which is
# exactly why it can carry all three API hosts on one backend.
#
# NOT restricted.googleapis.com (199.36.153.4/30): that VIP only fronts APIs that support VPC
# Service Controls, and the BigQuery connector must also reach oauth2.googleapis.com to exchange
# its service-account key for a token. private.googleapis.com fronts both.

FROM haproxy:2.9-alpine

USER root
COPY docker/bq-gateway/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /etc/haproxy && chown -R haproxy:haproxy /etc/haproxy

USER haproxy
EXPOSE 8443
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
