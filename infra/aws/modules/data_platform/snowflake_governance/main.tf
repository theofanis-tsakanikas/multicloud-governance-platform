# Snowflake governance wrapper — the second enforcement backend.
#
# Consumes the SAME domain JSON contract as dbx_governance, translates it through the shared
# infra/snowflake/privilege_map.json (the identical file scripts/snowflake_backend.py reads
# for the cross-backend consistency proof), and fans out to the cloud-neutral global modules
# to create databases, schemas, stages, functional roles, least-privilege grants, tag-based
# masking + row-access policies, and a cost-governed warehouse.

locals {
  # ── The shared translation contract (single source of truth) ──────────────
  priv_map = jsondecode(file("${path.module}/../../../../snowflake/privilege_map.json"))
  ptable   = local.priv_map.privilege_map

  # ── Decode the domain JSON strings ────────────────────────────────────────
  catalogs   = jsondecode(var.catalogs_json)
  ext_locs   = jsondecode(var.external_locations_json)
  cat_grants = jsondecode(var.catalog_grants_json)
  sch_grants = jsondecode(var.managed_schema_grants_json)
  vol_grants = jsondecode(var.volume_grants_json)
  loc_grants = jsondecode(var.ext_loc_grants_json)

  role_prefix = upper(var.environment)

  # Deterministic principal -> Snowflake functional role name (mirrors the roles module).
  principals = distinct(flatten([
    [for e in local.cat_grants : [for g in e.grants : g.principal]],
    [for e in local.sch_grants : [for g in e.grants : g.principal]],
    [for e in local.vol_grants : [for g in e.grants : g.principal]],
    [for e in local.loc_grants : [for g in e.grants : g.principal]],
  ]))
  role_name  = { for p in local.principals : p => upper(replace("${local.role_prefix}_${p}", "-", "_")) }
  owner_role = upper(replace("${local.role_prefix}_${var.owner}", "-", "_"))

  # Primary managed database — hosts the governance + external schemas for this domain.
  managed_db = length(local.catalogs) > 0 ? local.catalogs[0].catalog_name : ""

  # ── Flattened object lists for the resource modules ───────────────────────
  schemas = flatten([
    for c in local.catalogs : [
      for s in c.schemas : {
        database       = c.catalog_name
        schema_name    = s.schema_name
        classification = lookup(s, "classification", "unclassified")
      }
    ]
  ])

  classified_schemas = [
    for s in local.schemas : { schema = "${s.database}.${s.schema_name}", classification = s.classification }
    if contains(["confidential", "pii"], s.classification)
  ]

  external_stages = [
    for l in local.ext_locs : { name = l.location_name, url = "s3://${var.storage_bucket}/${trim(l.path, "/")}/" }
  ]

  internal_stages = flatten([
    for c in local.catalogs : [
      for s in c.schemas : [
        for v in lookup(s, "volumes", []) : {
          key      = "${c.catalog_name}.${s.schema_name}.${v.volume_name}"
          name     = v.volume_name
          database = c.catalog_name
          schema   = s.schema_name
        }
      ]
    ]
  ])

  # ── Translate abstract grants -> resolved Snowflake grant instances ────────
  # Each abstract privilege is looked up in the shared privilege_map; a fragment with scope
  # "future_and_existing_tables" fans out to the ALL + FUTURE table kinds. This is the exact
  # logic scripts/snowflake_backend.py mirrors in Python for the consistency test.
  catalog_instances = flatten([
    for e in local.cat_grants : [
      for g in e.grants : [
        for uc in g.privileges : [
          for frag in lookup(local.ptable.catalog, uc, []) : {
            key         = "cat|${e.catalog_name}|${g.principal}|${uc}"
            role_name   = local.role_name[g.principal]
            privileges  = frag.privileges
            kind        = "database"
            object_name = e.catalog_name
            schema      = ""
          }
        ]
      ]
    ]
  ])

  schema_instances = flatten([
    for e in local.sch_grants : [
      for g in e.grants : [
        for uc in g.privileges : [
          for frag in lookup(local.ptable.schema, uc, []) : [
            for kind in(frag.scope == "future_and_existing_tables" ? ["schema_tables_all", "schema_tables_future"] : ["schema"]) : {
              key         = "sch|${e.schema}|${g.principal}|${uc}|${kind}"
              role_name   = local.role_name[g.principal]
              privileges  = frag.privileges
              kind        = kind
              object_name = ""
              schema      = e.schema
            }
          ]
        ]
      ]
    ]
  ])

  volume_instances = flatten([
    for e in local.vol_grants : [
      for g in e.grants : [
        for uc in g.privileges : [
          for frag in lookup(local.ptable.volume, uc, []) : {
            key         = "vol|${e.volume}|${g.principal}|${uc}"
            role_name   = local.role_name[g.principal]
            privileges  = frag.privileges
            kind        = "stage"
            object_name = e.volume
            schema      = ""
          }
        ]
      ]
    ]
  ])

  loc_instances = flatten([
    for e in local.loc_grants : [
      for g in e.grants : [
        for uc in g.privileges : [
          for frag in lookup(local.ptable.external_location, uc, []) : {
            key         = "loc|${e.location_name}|${g.principal}|${uc}"
            role_name   = local.role_name[g.principal]
            privileges  = frag.privileges
            kind        = "stage"
            object_name = "${local.managed_db}._EXTERNAL.${e.location_name}"
            schema      = ""
          }
        ]
      ]
    ]
  ])

  grant_instances = concat(local.catalog_instances, local.schema_instances, local.volume_instances, local.loc_instances)
}

# ── Fan-out to the cloud-neutral Snowflake modules ──────────────────────────

module "roles" {
  source      = "../../../../snowflake/modules/global/roles"
  role_prefix = local.role_prefix
  principals  = local.principals
}

module "database" {
  source   = "../../../../snowflake/modules/global/database"
  catalogs = local.catalogs
}

module "schema" {
  source     = "../../../../snowflake/modules/global/schema"
  schemas    = local.schemas
  depends_on = [module.database]
}

module "external_stage" {
  source                   = "../../../../snowflake/modules/global/external_stage"
  database                 = local.managed_db
  storage_integration_name = var.storage_integration_name
  external_stages          = [] # deferred: needs the Snowflake storage integration (S3<->Snowflake IAM trust); RBAC+masking are the core
  internal_stages          = local.internal_stages
  depends_on               = [module.schema]
}

module "grants" {
  source          = "../../../../snowflake/modules/global/grants"
  grant_instances = local.grant_instances
  depends_on      = [module.roles, module.database, module.schema, module.external_stage]
}

module "governance_policies" {
  source             = "../../../../snowflake/modules/global/masking"
  database           = local.managed_db
  domain             = var.domain
  classified_schemas = local.classified_schemas
  privileged_role    = local.owner_role
  depends_on         = [module.schema, module.roles]
}

module "warehouse_monitor" {
  source                = "../../../../snowflake/modules/global/warehouse_monitor"
  domain                = var.domain
  warehouse_name        = "${local.role_prefix}_${upper(var.domain)}_WH"
  resource_monitor_name = "${local.role_prefix}_${upper(var.domain)}_RM"
  warehouse_size        = var.warehouse_size
  credit_quota          = var.credit_quota
}
