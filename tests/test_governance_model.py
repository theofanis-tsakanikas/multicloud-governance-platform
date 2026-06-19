"""Tests for governance_model: JSON → normalized object graph + classification."""

import json

from governance_model import (
    GovernanceModel,
    build_model,
    classification_rank,
    is_sensitive,
)

REPO_ROOT = __import__("pathlib").Path(__file__).resolve().parent.parent


# --------------------------------------------------------------------------- #
# classification helpers
# --------------------------------------------------------------------------- #


def test_classification_rank_orders_correctly():
    assert classification_rank("public") < classification_rank("internal")
    assert classification_rank("internal") < classification_rank("confidential")
    assert classification_rank("confidential") < classification_rank("pii")
    assert classification_rank(None) == -1
    assert classification_rank("nonsense") == -1


def test_is_sensitive():
    assert is_sensitive("pii")
    assert is_sensitive("confidential")
    assert not is_sensitive("internal")
    assert not is_sensitive("public")
    assert not is_sensitive(None)


# --------------------------------------------------------------------------- #
# real repo model
# --------------------------------------------------------------------------- #


def test_build_model_real_repo_shape():
    m = build_model(REPO_ROOT)
    assert len(m.securables) > 0
    assert len(m.grants) > 0
    # three clouds present
    clouds = {s.cloud for s in m.securables}
    assert clouds == {"AWS", "AZURE", "GCP"}


def test_pii_objects_detected():
    m = build_model(REPO_ROOT)
    pii = {s.fqn for s in m.securables if s.classification == "pii"}
    assert "sales_rds_fed.crm" in pii
    assert "marketing_bq_fed.web" in pii


def test_grant_classification_is_resolved_from_object():
    m = build_model(REPO_ROOT)
    crm_grants = [g for g in m.grants if g.fqn == "sales_rds_fed.crm"]
    assert crm_grants, "expected grants on the CRM schema"
    assert all(g.classification == "pii" for g in crm_grants)


def test_volume_inherits_schema_classification(tmp_path):
    # bronze is confidential; its volume declares no classification → inherits.
    m = build_model(REPO_ROOT)
    vol = m.securable("volume", "sales_aws.bronze.sales_landing_zone")
    assert vol is not None
    assert vol.classification == "confidential"


def test_catalog_owner_parsed():
    m = build_model(REPO_ROOT)
    cat = m.securable("catalog", "sales_aws")
    assert cat is not None and cat.owner == "data_engineers"
    fed = m.securable("catalog", "sales_rds_fed")
    assert fed is not None and fed.catalog_type == "FEDERATED"


def test_grants_on_classified_filters_by_floor():
    m = build_model(REPO_ROOT)
    pii_only = m.grants_on_classified(minimum="pii")
    assert pii_only
    assert all(g.classification == "pii" for g in pii_only)


# --------------------------------------------------------------------------- #
# synthetic model from a temp repo (isolates parsing from the committed config)
# --------------------------------------------------------------------------- #


def _make_repo(tmp_path, infra: dict, grants: dict):
    d = tmp_path / "environments" / "dev" / "domains" / "aws"
    d.mkdir(parents=True)
    (d / "x_infra.json").write_text(json.dumps(infra))
    (d / "x_grants.json").write_text(json.dumps(grants))
    return tmp_path


def test_volume_own_classification_overrides_schema(tmp_path):
    infra = {
        "cloud": "AWS",
        "domain": "x",
        "external_locations": [],
        "catalogs": [
            {
                "catalog_name": "c",
                "type": "MANAGED",
                "schemas": [
                    {
                        "schema_name": "s",
                        "classification": "internal",
                        "volumes": [{"volume_name": "v", "classification": "pii"}],
                    }
                ],
            }
        ],
    }
    repo = _make_repo(tmp_path, infra, {"volume_grants": []})
    m = build_model(repo)
    assert m.classification_of("volume", "c.s.v") == "pii"
    assert m.classification_of("schema", "c.s") == "internal"


def test_malformed_entries_are_skipped_not_raised(tmp_path):
    infra = {
        "cloud": "AWS",
        "domain": "x",
        "catalogs": [
            {"catalog_name": "c", "type": "MANAGED", "schemas": [{"schema_name": "s"}, {"no_name": True}]},
            {"missing": "catalog_name"},
        ],
    }
    grants = {"schema_grants": [{"schema": "c.s", "grants": [{"principal": "g", "privileges": ["SELECT"]}]}]}
    repo = _make_repo(tmp_path, infra, grants)
    m = build_model(repo)  # must not raise
    assert isinstance(m, GovernanceModel)
    assert m.securable("schema", "c.s") is not None
