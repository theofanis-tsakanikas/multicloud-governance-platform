"""Tests for the offline domain-config validator.

Proves the validator works in BOTH directions:

  * The REAL repository config passes (no errors).
  * Each individual rule FIRES against a crafted bad input — a validator that
    can never fail is worthless, so every rule has a negative test.

The good baseline is mutated minimally per test so each failure is attributable
to exactly one rule.
"""

import copy
import json
from pathlib import Path

import pytest

import validate_domains as vd
from conftest import REPO_ROOT

# --------------------------------------------------------------------------- #
# Fixtures: a minimal, valid infra + grants pair used as the mutation baseline
# --------------------------------------------------------------------------- #

GOOD_INFRA = {
    "cloud": "AWS",
    "domain": "sales",
    "managed_storage_root": "proj/sales/managed/",
    "external_locations": [
        {"location_name": "loc_sales_raw", "path": "proj/sales/raw/"},
        {"location_name": "loc_sales_managed", "path": "proj/sales/managed/"},
    ],
    "catalogs": [
        {
            "catalog_name": "sales_aws",
            "type": "MANAGED",
            "storage_root": "proj/sales/managed/",
            "schemas": [
                {
                    "schema_name": "bronze",
                    "volumes": [
                        {
                            "volume_name": "landing",
                            "location_path": "proj/sales/raw/",
                            "volume_path": "landing/",
                            "volume_type": "EXTERNAL",
                        }
                    ],
                },
                {"schema_name": "gold"},
            ],
        },
        {
            "catalog_name": "sales_fed",
            "type": "FEDERATED",
            "connection_name": "rds_conn",
            "database_name": "salesdb",
            "schemas": [{"schema_name": "crm"}],
        },
    ],
}

GOOD_GRANTS = {
    "external_location_grants": [
        {
            "location_name": "loc_sales_raw",
            "grants": [
                {"principal": "data_engineers", "privileges": ["READ_FILES"]},
            ],
        },
    ],
    "catalog_grants": [
        {
            "catalog_name": "sales_aws",
            "grants": [
                {"principal": "data_engineers", "privileges": ["USE_CATALOG", "CREATE_SCHEMA"]},
            ],
        },
    ],
    "schema_grants": [
        {
            "schema": "sales_aws.bronze",
            "grants": [
                {"principal": "data_engineers", "privileges": ["USE_SCHEMA", "SELECT"]},
            ],
        },
        {
            "schema": "sales_fed.crm",
            "grants": [
                {"principal": "data_engineers", "privileges": ["USE_SCHEMA", "SELECT"]},
            ],
        },
    ],
    "volume_grants": [
        {
            "volume": "sales_aws.bronze.landing",
            "grants": [
                {"principal": "data_engineers", "privileges": ["READ_VOLUME", "WRITE_VOLUME"]},
            ],
        },
    ],
}


def codes(findings, severity=None):
    return {f.code for f in findings if severity is None or f.severity == severity}


def run_pair(infra, grants):
    """Run schema + cross-file checks on one infra/grants pair, return findings."""
    findings = []
    idx = vd.build_infra_index(infra, "infra.json", findings)
    principals = []
    vd.validate_grants(grants, idx, "grants.json", findings, principals)
    return findings


# --------------------------------------------------------------------------- #
# 0. Sanity: the crafted baseline itself is clean
# --------------------------------------------------------------------------- #


def test_baseline_fixture_has_no_errors():
    findings = run_pair(copy.deepcopy(GOOD_INFRA), copy.deepcopy(GOOD_GRANTS))
    assert not vd.has_errors(findings), [str(f) for f in findings]


# --------------------------------------------------------------------------- #
# 1. REAL repo config must PASS
# --------------------------------------------------------------------------- #


def test_real_repo_has_no_errors():
    findings = vd.validate_repo(REPO_ROOT)
    errors = [f for f in findings if f.severity == vd.ERROR]
    assert errors == [], [str(f) for f in errors]


def test_real_repo_wiring_resolves():
    """Every dbx_governance file() reference points at a real JSON file."""
    findings = []
    vd.validate_wiring(REPO_ROOT, findings)
    assert "WIRING_MISSING" not in codes(findings), [str(f) for f in findings]


def test_real_repo_passes_with_relative_root(monkeypatch):
    """Wiring resolution must be independent of cwd / relative-vs-absolute root."""
    monkeypatch.chdir(REPO_ROOT)
    findings = vd.validate_repo(".")
    errors = [f for f in findings if f.severity == vd.ERROR]
    assert errors == [], [str(f) for f in errors]


# --------------------------------------------------------------------------- #
# 2. SCHEMA rules — each fires on a crafted bad input
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize("bad_type", ["managed", "Managed", "FEDERATED ", "MANAGEDD", ""])
def test_miscased_or_typo_catalog_type_fails(bad_type):
    infra = copy.deepcopy(GOOD_INFRA)
    infra["catalogs"][0]["type"] = bad_type
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "CATALOG_TYPE" in codes(findings, vd.ERROR)


def test_federated_without_connection_name_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    del infra["catalogs"][1]["connection_name"]
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "CATALOG_FED" in codes(findings, vd.ERROR)


def test_external_volume_missing_location_path_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    del infra["catalogs"][0]["schemas"][0]["volumes"][0]["location_path"]
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "INFRA_VOLUME" in codes(findings, vd.ERROR)


def test_missing_top_level_field_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    del infra["cloud"]
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "INFRA_FIELD" in codes(findings, vd.ERROR)


def test_invalid_json_reports_parse_error(tmp_path):
    bad = tmp_path / "broken_infra.json"
    bad.write_text('{ "cloud": "AWS", ', encoding="utf-8")  # truncated
    data, err = vd.load_json(bad)
    assert data is None
    assert err is not None and err.code == "JSON_PARSE"


# --------------------------------------------------------------------------- #
# 3. CROSS-FILE consistency — dangling grants
# --------------------------------------------------------------------------- #


def test_dangling_external_location_grant_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["external_location_grants"][0]["location_name"] = "loc_does_not_exist"
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "DANGLING_GRANT" in codes(findings, vd.ERROR)


def test_dangling_catalog_grant_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["catalog_grants"][0]["catalog_name"] = "ghost_catalog"
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "DANGLING_GRANT" in codes(findings, vd.ERROR)


def test_dangling_schema_grant_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["schema_grants"][0]["schema"] = "sales_aws.nonexistent"
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "DANGLING_GRANT" in codes(findings, vd.ERROR)


def test_dangling_volume_grant_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["volume_grants"][0]["volume"] = "sales_aws.bronze.ghost_volume"
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "DANGLING_GRANT" in codes(findings, vd.ERROR)


# --------------------------------------------------------------------------- #
# 4. CROSS-FILE consistency — privilege validity
# --------------------------------------------------------------------------- #


def test_unknown_privilege_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["schema_grants"][0]["grants"][0]["privileges"] = ["SELECTT"]  # typo
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "PRIVILEGE_INVALID" in codes(findings, vd.ERROR)


def test_privilege_valid_but_wrong_object_type_fails():
    # READ_FILES is valid on an external location, NOT on a catalog.
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["catalog_grants"][0]["grants"][0]["privileges"] = ["READ_FILES"]
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "PRIVILEGE_INVALID" in codes(findings, vd.ERROR)


def test_empty_privileges_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    grants["catalog_grants"][0]["grants"][0]["privileges"] = []
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "GRANT_PRIVS" in codes(findings, vd.ERROR)


def test_missing_principal_fails():
    grants = copy.deepcopy(GOOD_GRANTS)
    del grants["catalog_grants"][0]["grants"][0]["principal"]
    findings = run_pair(copy.deepcopy(GOOD_INFRA), grants)
    assert "GRANT_PRINCIPAL" in codes(findings, vd.ERROR)


# --------------------------------------------------------------------------- #
# 5. CROSS-FILE consistency — duplicate object names
# --------------------------------------------------------------------------- #


def test_duplicate_catalog_name_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    infra["catalogs"].append(copy.deepcopy(infra["catalogs"][0]))
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "DUP_CATALOG" in codes(findings, vd.ERROR)


def test_duplicate_schema_name_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    infra["catalogs"][0]["schemas"].append({"schema_name": "bronze"})
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "DUP_SCHEMA" in codes(findings, vd.ERROR)


def test_duplicate_volume_name_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    infra["catalogs"][0]["schemas"][0]["volumes"].append(
        {"volume_name": "landing", "location_path": "p/", "volume_path": "x/", "volume_type": "EXTERNAL"}
    )
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "DUP_VOLUME" in codes(findings, vd.ERROR)


def test_duplicate_external_location_name_fails():
    infra = copy.deepcopy(GOOD_INFRA)
    infra["external_locations"].append({"location_name": "loc_sales_raw", "path": "other/"})
    findings = run_pair(infra, copy.deepcopy(GOOD_GRANTS))
    assert "DUP_EXT_LOC" in codes(findings, vd.ERROR)


# --------------------------------------------------------------------------- #
# 6. CONSISTENCY — group singleton warning
# --------------------------------------------------------------------------- #


def test_group_singleton_warns():
    findings = []
    vd.validate_group_consistency({"data_engineers": 5, "data_enginers": 1}, findings)
    singletons = [f for f in findings if f.code == "GROUP_SINGLETON"]
    assert any("data_enginers" in f.message for f in singletons)
    assert all(f.severity == vd.WARNING for f in singletons)


# --------------------------------------------------------------------------- #
# 7. WIRING — file() reference resolution against a synthetic repo
# --------------------------------------------------------------------------- #


def _make_repo(tmp_path: Path, *, with_json: bool, domain_path_levels: str = "../../../") -> Path:
    """Build a minimal repo: a dbx_governance terragrunt.hcl plus (optionally)
    the domain JSON it references at environments/dev/domains/aws/."""
    cloud = "aws"
    gov = tmp_path / "environments" / "dev" / cloud / "data_platform" / "dbx_governance"
    gov.mkdir(parents=True)
    hcl = gov / "terragrunt.hcl"
    hcl.write_text(
        "locals {\n"
        f'  domain_path = "${{get_terragrunt_dir()}}/{domain_path_levels}domains/{cloud}"\n'
        '  infra  = jsondecode(file("${local.domain_path}/sales_infra.json"))\n'
        '  grants = jsondecode(file("${local.domain_path}/sales_grants.json"))\n'
        "}\n",
        encoding="utf-8",
    )
    if with_json:
        dom = tmp_path / "environments" / "dev" / "domains" / cloud
        dom.mkdir(parents=True)
        (dom / "sales_infra.json").write_text(json.dumps(GOOD_INFRA), encoding="utf-8")
        (dom / "sales_grants.json").write_text(json.dumps(GOOD_GRANTS), encoding="utf-8")
    return tmp_path


def test_wiring_detects_missing_file(tmp_path):
    # HCL points at ../../../domains/aws but the JSON is absent -> error.
    repo = _make_repo(tmp_path, with_json=False)
    findings = []
    vd.validate_wiring(repo, findings)
    assert "WIRING_MISSING" in codes(findings, vd.ERROR)


def test_wiring_detects_wrong_relative_depth(tmp_path):
    # The exact real-world bug: domain_path off by one '../' (too shallow).
    repo = _make_repo(tmp_path, with_json=True, domain_path_levels="../../")
    findings = []
    vd.validate_wiring(repo, findings)
    assert "WIRING_MISSING" in codes(findings, vd.ERROR)


def test_wiring_passes_when_paths_correct(tmp_path):
    repo = _make_repo(tmp_path, with_json=True, domain_path_levels="../../../")
    findings = []
    vd.validate_wiring(repo, findings)
    assert "WIRING_MISSING" not in codes(findings)


def test_orphan_json_warns(tmp_path):
    repo = _make_repo(tmp_path, with_json=True, domain_path_levels="../../../")
    # Add an extra, unreferenced domain JSON.
    orphan = repo / "environments" / "dev" / "domains" / "aws" / "unused_infra.json"
    orphan.write_text(json.dumps(GOOD_INFRA), encoding="utf-8")
    findings = []
    referenced = vd.validate_wiring(repo, findings)
    vd.validate_orphans(repo, referenced, findings)
    assert "ORPHAN_JSON" in codes(findings, vd.WARNING)
