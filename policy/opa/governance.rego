# Unity Catalog access-policy rules — an INDEPENDENT re-implementation of the
# gating rules in scripts/policy_analyzer.py, expressed in Rego for Open Policy
# Agent / Conftest.
#
# Why two engines for the same rules? Defence in depth + a portability proof:
# the deterministic Python analyzer is the source of truth and the CI gate, and
# this Rego policy independently re-derives the same HIGH violations from the
# generated grounding pack (docs/governance/governance_context.json). When both
# agree the committed config is clean, that is two engines confirming the access
# model — and it demonstrates the rules are expressible in the industry-standard
# policy language, not locked inside bespoke Python.
#
# Input: docs/governance/governance_context.json (the analyzer's own output).
# Run:   conftest test docs/governance/governance_context.json --policy policy/opa
#
# A `deny` is raised only for violations WITHOUT a matching accepted exception,
# so the clean committed config (whose PII reads are documented exceptions)
# produces zero denials — exactly like the analyzer's RESULT: PASS.

package main

import rego.v1

public_principals := {"users", "account users", "all account users", "all users", "public", "*"}

admin_principals := {"metastore_admins"}

read_privileges := {"SELECT", "READ_VOLUME", "READ_FILES"}

# Write == any privilege that can change PII, plus ALL_PRIVILEGES (which subsumes them). Mirrors
# WRITE_PRIVILEGES in scripts/governance_model.py so the two engines classify writes identically.
write_privileges := {"MODIFY", "WRITE_VOLUME", "WRITE_FILES", "CREATE_TABLE", "CREATE_EXTERNAL_TABLE", "CREATE_EXTERNAL_VOLUME", "ALL_PRIVILEGES"}

sensitive_classes := {"confidential", "pii"}

# owner[catalog_name] = owner principal, for the objects that declare one.
owner[name] := o.owner if {
	some o in input.objects
	o.object_type == "catalog"
	o.owner != null
	name := o.name
}

is_admin(principal) if admin_principals[principal]

catalog_of(object) := split(object, ".")[0]

is_owner(access) if owner[catalog_of(access.object)] == access.principal

# A documented, unexpired exception accepted by the analyzer for this exact
# (rule, object, principal) — the analyzer already validated the expiry.
accepted(rule, access) if {
	some f in input.policy_findings
	f.rule == rule
	f.accepted == true
	f.object == sprintf("%s:%s", [access.object_type, access.object])
	f.principal == access.principal
}

# ---- PUBLIC_PRINCIPAL ------------------------------------------------------ #
deny contains msg if {
	some access in input.access_matrix
	public_principals[lower(access.principal)]
	not accepted("PUBLIC_PRINCIPAL", access)
	msg := sprintf("PUBLIC_PRINCIPAL: [%s] %s:%s granted to public principal %q", [access.cloud, access.object_type, access.object, access.principal])
}

# ---- PII_BROAD_READ -------------------------------------------------------- #
deny contains msg if {
	some access in input.access_matrix
	access.classification == "pii"
	not is_admin(access.principal)
	some privilege in access.privileges
	read_privileges[privilege]
	not accepted("PII_BROAD_READ", access)
	msg := sprintf("PII_BROAD_READ: [%s] %s:%s readable by non-admin %q", [access.cloud, access.object_type, access.object, access.principal])
}

# ---- PII_WRITE ------------------------------------------------------------- #
deny contains msg if {
	some access in input.access_matrix
	access.classification == "pii"
	not is_admin(access.principal)
	some privilege in access.privileges
	write_privileges[privilege]
	not accepted("PII_WRITE", access)
	msg := sprintf("PII_WRITE: [%s] %s:%s writable by non-admin %q", [access.cloud, access.object_type, access.object, access.principal])
}

# ---- SENSITIVE_ALL_PRIVILEGES ---------------------------------------------- #
deny contains msg if {
	some access in input.access_matrix
	sensitive_classes[access.classification]
	"ALL_PRIVILEGES" in access.privileges
	not is_admin(access.principal)
	not is_owner(access)
	not accepted("SENSITIVE_ALL_PRIVILEGES", access)
	msg := sprintf("SENSITIVE_ALL_PRIVILEGES: [%s] %s:%s ALL_PRIVILEGES to non-admin/non-owner %q", [access.cloud, access.object_type, access.object, access.principal])
}
