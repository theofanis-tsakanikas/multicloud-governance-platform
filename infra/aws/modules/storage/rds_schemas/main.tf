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
resource "postgresql_schema" "rds_schemas" {
  for_each = toset(var.rds_schemas)
  name     = each.value

  drop_cascade = var.drop_cascade
}
