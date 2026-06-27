"""Tests for the optional JSON Schema validation layer in validate_domains.

Skipped when `jsonschema` is not installed (the structural validator still runs);
exercised in CI and the devcontainer where it is present."""

import json
from pathlib import Path

import pytest

from validate_domains import (
    Finding,
    jsonschema_available,
    validate_against_schema,
)

pytestmark = pytest.mark.skipif(not jsonschema_available(), reason="jsonschema not installed")

REPO_ROOT = Path(__file__).resolve().parent.parent
_INFRA = "domain.infra.schema.json"
_GRANTS = "domain.grants.schema.json"


def test_valid_infra_passes():
    infra = {
        "cloud": "AWS",
        "domain": "sales",
        "catalogs": [{"catalog_name": "c", "type": "MANAGED", "schemas": [{"schema_name": "s", "classification": "pii"}]}],
    }
    findings: list[Finding] = []
    validate_against_schema(infra, REPO_ROOT, _INFRA, "loc", findings)
    assert findings == []


def test_bad_catalog_type_is_caught():
    infra = {"cloud": "AWS", "domain": "d", "catalogs": [{"catalog_name": "c", "type": "managed"}]}
    findings: list[Finding] = []
    validate_against_schema(infra, REPO_ROOT, _INFRA, "loc", findings)
    assert any(f.code == "SCHEMA_VALIDATION" for f in findings)


def test_federated_requires_connection_name():
    infra = {"cloud": "AWS", "domain": "d", "catalogs": [{"catalog_name": "c", "type": "FEDERATED"}]}
    findings: list[Finding] = []
    validate_against_schema(infra, REPO_ROOT, _INFRA, "loc", findings)
    assert any(f.code == "SCHEMA_VALIDATION" for f in findings)


def test_bad_classification_enum_is_caught():
    infra = {
        "cloud": "AWS",
        "domain": "d",
        "catalogs": [{"catalog_name": "c", "type": "MANAGED", "schemas": [{"schema_name": "s", "classification": "secret"}]}],
    }
    findings: list[Finding] = []
    validate_against_schema(infra, REPO_ROOT, _INFRA, "loc", findings)
    assert any(f.code == "SCHEMA_VALIDATION" for f in findings)


def test_grant_missing_privileges_is_caught():
    grants = {"schema_grants": [{"schema": "c.s", "grants": [{"principal": "analysts"}]}]}
    findings: list[Finding] = []
    validate_against_schema(grants, REPO_ROOT, _GRANTS, "loc", findings)
    assert any(f.code == "SCHEMA_VALIDATION" for f in findings)


def test_committed_domains_satisfy_schema():
    """Every committed domain file must validate against its schema."""
    from validate_domains import discover_domain_files

    for infra_path, grants_path in discover_domain_files(REPO_ROOT):
        findings: list[Finding] = []
        validate_against_schema(json.loads(infra_path.read_text()), REPO_ROOT, _INFRA, str(infra_path), findings)
        validate_against_schema(json.loads(grants_path.read_text()), REPO_ROOT, _GRANTS, str(grants_path), findings)
        assert findings == [], f"{infra_path.name}: {[str(f) for f in findings]}"
