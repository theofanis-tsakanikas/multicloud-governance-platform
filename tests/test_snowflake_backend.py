"""Tests for the Snowflake enforcement backend (translation + cross-backend consistency).

The headline test is :func:`test_committed_config_is_access_equivalent` — the committed
domain contract, enforced on Snowflake, grants every principal *exactly* the read/write/
admin access the Unity Catalog contract does. That is the engine-agnostic proof: one JSON,
two backends, provably equivalent least-privilege. The negative tests show the check has
teeth (a mistranslation that drops or adds a capability is caught).
"""

from __future__ import annotations

from pathlib import Path

from governance_model import GovernanceModel, Grant, build_model
from snowflake_backend import (
    engine_limitation,
    ADMIN,
    READ,
    WRITE,
    abstract_capabilities,
    cross_backend_issues,
    effective_access_snowflake,
    effective_access_uc,
    load_privilege_map,
    render_snowflake_grants,
    snowflake_capabilities,
    snowflake_object_type,
)

REPO_ROOT = Path(__file__).resolve().parent.parent


def _model() -> GovernanceModel:
    return build_model(REPO_ROOT)


def _priv_map() -> dict:
    return load_privilege_map(REPO_ROOT)


# --------------------------------------------------------------------------- #
# The shared privilege map
# --------------------------------------------------------------------------- #


def test_privilege_map_covers_all_object_types():
    pm = _priv_map()
    assert set(pm["object_type_map"]) == {"external_location", "catalog", "schema", "volume"}
    assert set(pm["privilege_map"]) == {"external_location", "catalog", "schema", "volume"}


def test_object_type_mapping_to_snowflake():
    pm = _priv_map()
    assert snowflake_object_type("catalog", pm) == "database"
    assert snowflake_object_type("schema", pm) == "schema"
    # The two stage kinds are distinct because Snowflake's stage privileges are:
    # internal -> READ/WRITE (USAGE invalid); external -> USAGE (READ/WRITE invalid).
    assert snowflake_object_type("volume", pm) == "stage_internal"
    assert snowflake_object_type("external_location", pm) == "stage_external"


def test_map_covers_every_privilege_used_in_committed_grants():
    # Nothing the real domain config grants may be silently dropped by the translation.
    model, pm = _model(), _priv_map()
    table = pm["privilege_map"]
    missing = set()
    for g in model.grants:
        for p in g.privileges:
            if p not in table.get(g.object_type, {}):
                missing.add((g.object_type, p))
    assert missing == set(), f"privilege_map is missing translations for: {sorted(missing)}"


# --------------------------------------------------------------------------- #
# Capability classifiers (independent per engine)
# --------------------------------------------------------------------------- #


def test_abstract_capability_classification():
    assert abstract_capabilities(["SELECT"]) == frozenset({READ})
    assert abstract_capabilities(["MODIFY"]) == frozenset({WRITE})
    assert abstract_capabilities(["ALL_PRIVILEGES"]) == frozenset({READ, WRITE, ADMIN})
    assert abstract_capabilities(["USE_CATALOG"]) == frozenset()  # traversal only
    assert abstract_capabilities(["CREATE_SCHEMA"]) == frozenset()  # structural, not data-write
    assert abstract_capabilities(["USE_SCHEMA", "SELECT"]) == frozenset({READ})


def test_snowflake_capability_classification_is_object_aware():
    # External-stage USAGE permits COPY in BOTH directions, so it is read+write.
    assert snowflake_capabilities("stage_external", ["USAGE"]) == frozenset({READ, WRITE})
    # USAGE is not a valid internal-stage privilege; it confers nothing there.
    assert snowflake_capabilities("stage_internal", ["USAGE"]) == frozenset()
    assert snowflake_capabilities("stage_internal", ["READ"]) == frozenset({READ})
    assert snowflake_capabilities("stage_internal", ["WRITE"]) == frozenset({WRITE})
    assert snowflake_capabilities("stage_internal", ["READ", "WRITE"]) == frozenset({READ, WRITE})
    assert snowflake_capabilities("schema", ["USAGE"]) == frozenset()
    assert snowflake_capabilities("database", ["USAGE"]) == frozenset()
    assert snowflake_capabilities("schema", ["SELECT"]) == frozenset({READ})
    assert snowflake_capabilities("schema", ["INSERT", "UPDATE", "DELETE"]) == frozenset({WRITE})
    assert snowflake_capabilities("database", ["ALL PRIVILEGES"]) == frozenset({READ, WRITE, ADMIN})
    assert snowflake_capabilities("schema", ["CREATE SCHEMA"]) == frozenset()  # mirrors abstract


# --------------------------------------------------------------------------- #
# Translation
# --------------------------------------------------------------------------- #


def test_render_produces_grants_for_every_model_grant_object():
    model, pm = _model(), _priv_map()
    rendered = render_snowflake_grants(model, pm)
    assert rendered, "expected Snowflake grants for the committed model"
    # Every rendered fragment names concrete Snowflake privileges and a known scope.
    for sg in rendered:
        assert sg.privileges
        assert sg.scope in {"self", "future_and_existing_tables", "future_and_existing_views"}
        assert sg.snowflake_object_type in {"database", "schema", "stage_internal", "stage_external"}


def test_select_on_schema_targets_tables_not_the_schema():
    # A SELECT grant on a schema must become SELECT on the schema's tables (future+existing),
    # plus the caller separately gets USAGE on the schema — the correct Snowflake pattern.
    model = GovernanceModel(
        securables=[],
        grants=[Grant("AWS", "sales", "schema", "sales_aws.gold", "analysts", ("USE_SCHEMA", "SELECT"), "internal", "MANAGED")],
    )
    frags = render_snowflake_grants(model, _priv_map())
    by_priv = {p: sg for sg in frags for p in sg.privileges}
    assert by_priv["USAGE"].scope == "self"
    assert by_priv["SELECT"].scope == "future_and_existing_tables"


# --------------------------------------------------------------------------- #
# Cross-backend consistency — the engine-agnostic proof
# --------------------------------------------------------------------------- #


def test_committed_config_is_access_equivalent():
    """The committed contract grants identical access on UC and Snowflake, except where the
    engine provably cannot express the distinction (those are classified, not hidden)."""
    model, pm = _model(), _priv_map()
    issues = cross_backend_issues(model, pm)
    divergences = [i for i in issues if i.kind != "engine_limitation"]
    assert divergences == [], "cross-backend access divergence:\n" + "\n".join(str(i) for i in divergences)


def test_every_engine_limitation_is_documented_and_only_on_external_stages():
    """An `engine_limitation` must never become a dumping ground for mistranslations."""
    model, pm = _model(), _priv_map()
    limits = [i for i in cross_backend_issues(model, pm) if i.kind == "engine_limitation"]
    assert limits, "expected the known external-stage over-grant to be surfaced, not silent"
    for i in limits:
        # Only external locations, only an ADDED capability, never a lost one.
        assert i.object_type == "external_location"
        assert not (i.uc_access - i.snowflake_access), f"a lost capability was misfiled: {i}"
        assert engine_limitation(i.object_type, i.snowflake_access - i.uc_access)


def test_no_object_principal_loses_access_on_snowflake():
    # The serious invariant on its own: Snowflake never grants LESS than UC.
    model, pm = _model(), _priv_map()
    lost = [i for i in cross_backend_issues(model, pm) if i.kind == "lost"]
    assert lost == [], "Snowflake enforcement loses UC-granted access:\n" + "\n".join(str(i) for i in lost)


def test_every_principal_object_pair_is_present_on_both_backends():
    model, pm = _model(), _priv_map()
    uc_keys = set(effective_access_uc(model))
    sf_keys = set(effective_access_snowflake(model, pm))
    assert uc_keys == sf_keys


def test_consistency_check_detects_a_lost_capability():
    # Doctor the map so schema SELECT translates to USAGE only (drops read): must be caught.
    model = GovernanceModel(
        securables=[],
        grants=[Grant("AWS", "sales", "schema", "sales_aws.gold", "analysts", ("SELECT",), "internal", "MANAGED")],
    )
    broken = _priv_map()
    broken["privilege_map"]["schema"]["SELECT"] = [{"privileges": ["USAGE"], "scope": "self", "access": "usage"}]
    lost = [i for i in cross_backend_issues(model, broken) if i.kind == "lost"]
    assert len(lost) == 1
    assert lost[0].object_type == "schema" and lost[0].principal == "analysts"
    assert READ in lost[0].uc_access and READ not in lost[0].snowflake_access


def test_consistency_check_detects_an_over_grant():
    # Doctor the map so USE_SCHEMA (traversal) translates to SELECT (read): an over-grant.
    model = GovernanceModel(
        securables=[],
        grants=[Grant("AWS", "sales", "schema", "sales_aws.gold", "business_users", ("USE_SCHEMA",), "internal", "MANAGED")],
    )
    broken = _priv_map()
    broken["privilege_map"]["schema"]["USE_SCHEMA"] = [{"privileges": ["SELECT"], "scope": "future_and_existing_tables", "access": "read"}]
    added = [i for i in cross_backend_issues(model, broken) if i.kind == "added"]
    assert len(added) == 1
    assert READ in added[0].snowflake_access and READ not in added[0].uc_access
