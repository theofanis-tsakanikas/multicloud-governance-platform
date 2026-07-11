# The schemas of the SIMULATED source system (ADR-0014).
#
# They hold the application's tables -- seeded by pipelines/sources/rds/seed.sql --
# so a plain DROP SCHEMA fails:
#
#     pq: cannot drop schema orders because other objects depend on it (2BP01)
#
# ⚠ A delete-time flag is read from STATE, not from config. Adding `drop_cascade`
# to a module whose resources are already in state does nothing on the next
# destroy: the provider reads the value the last `apply` recorded. It takes effect
# on stacks deployed after this change. To unblock an existing one, drop the
# tables out of band and let terraform drop the (now empty) schema.
#
# `drop_cascade` is opt-in and OFF by default, mirroring the data bucket's
# force_destroy. dev turns it on: these schemas belong to a source system this repo
# only pretends to own, and tearing the platform down has to tear the pretence down
# with it. In production the application owns its schema, and a governance platform
# that cascade-drops it is a governance platform nobody would install.
# ⚠ PRIVATE MODE: this layer creates nothing, and cannot.
#
# `publicly_accessible = false` leaves the instance with no public address at all, and the RDS
# security group then admits 5432 from exactly one place — the gateway container's security
# group. A GitHub runner is not in the VPC. There is no firewall rule to add, no orch_ip to
# allow: there is nothing to route to. Terraform opening a postgres connection from CI is not
# hard in private mode, it is impossible, and it is impossible *on purpose*.
#
# So the schemas move to where the database is. The gateway image (docker/rds-gateway) carries a
# `sql` role for exactly this, and the deploy runs it as a one-shot ECS task in the same subnet
# and the same security group as the gateway itself, right after the integration layer stands
# the cluster up. That is the only door into a private RDS, and it is the door the platform
# already built.
#
# This is not a workaround grafted on: these schemas belong to a SIMULATED source system
# (ADR-0014), the same one whose *tables* have always been seeded from outside Terraform. Only
# the schemas were ever in here, and only because in public mode they could be. Private mode
# just removes that accident.
locals {
  # Empty in private mode. Terraform still configures the postgres provider, but a provider with
  # nothing to do never opens a connection.
  schemas = var.is_private_connection ? toset([]) : toset(var.rds_schemas)
}

resource "postgresql_schema" "rds_schemas" {
  for_each = local.schemas
  name     = each.value

  drop_cascade = var.drop_cascade
}
