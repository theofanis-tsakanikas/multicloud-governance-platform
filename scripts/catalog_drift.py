#!/usr/bin/env python3
"""Reconcile the committed grants against the *live* Unity Catalog.

The weekly ``dbx-drift.yml`` workflow runs ``terragrunt plan`` — it detects drift
in *Terraform-managed* resources. But a grant changed by hand in the Databricks
UI (the classic "someone clicked Grant in prod on Friday") is exactly the kind of
governance drift Terraform plan may not surface cleanly. This closes that loop:
it compares the access model the config *declares* against what the metastore
*actually* enforces.

Two halves, mirroring the rest of the platform:

* **Expected side (offline, deterministic, always runs).** Flattens the domain
  JSON via :mod:`governance_model` into the set of grants the platform intends.
* **Live side (deferred — needs the Databricks SDK + workspace creds).** Behind
  ``--live``, reads effective grants from Unity Catalog and diffs them. Without
  the SDK or creds it explains what it *would* reconcile and exits 0 — the same
  "artifacts at build time, cloud at deploy time" discipline as ``genie_space.py``.

The diff itself (:func:`diff_grants`) is a pure function, unit-tested against
synthetic "live" data, so the reconciliation logic is provable without a cloud.

Usage::

    python scripts/catalog_drift.py             # offline: summarize expected grants
    python scripts/catalog_drift.py --live       # reconcile against live UC (needs SDK + creds)
    python scripts/catalog_drift.py --format json
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

from governance_model import GovernanceModel, build_model

# A grant's identity for set comparison: who, on what, with which privileges.
GrantKey = tuple[str, str, str, str, frozenset]


def _key(cloud: str, object_type: str, fqn: str, principal: str, privileges) -> GrantKey:
    return (cloud, object_type, fqn, principal, frozenset(privileges))


def expected_grants(model: GovernanceModel) -> set[GrantKey]:
    """The set of grants the committed config declares."""
    return {_key(g.cloud, g.object_type, g.fqn, g.principal, g.privileges) for g in model.grants}


@dataclass
class DriftReport:
    """The result of reconciling expected vs live grants."""

    missing_in_catalog: list[GrantKey]  # config declares it; the catalog does not enforce it
    extra_in_catalog: list[GrantKey]  # the catalog enforces it; the config does not declare it

    @property
    def in_sync(self) -> bool:
        return not self.missing_in_catalog and not self.extra_in_catalog

    def as_dict(self) -> dict:
        def fmt(keys: list[GrantKey]) -> list[dict]:
            return [
                {"cloud": c, "object_type": ot, "object": fqn, "principal": p, "privileges": sorted(privs)}
                for (c, ot, fqn, p, privs) in sorted(keys, key=lambda k: (k[0], k[1], k[2], k[3]))
            ]

        return {
            "in_sync": self.in_sync,
            "missing_in_catalog": fmt(self.missing_in_catalog),
            "extra_in_catalog": fmt(self.extra_in_catalog),
        }


def diff_grants(expected: set[GrantKey], live: set[GrantKey]) -> DriftReport:
    """Pure reconciliation: what the config wants vs what the catalog enforces."""
    return DriftReport(
        missing_in_catalog=sorted(expected - live),
        extra_in_catalog=sorted(live - expected),
    )


# --------------------------------------------------------------------------- #
# Live side (deferred — needs Databricks SDK + workspace credentials)
# --------------------------------------------------------------------------- #

# Unity Catalog securable type per our object_type, for the SDK grants API.
_SECURABLE_TYPE = {
    "external_location": "EXTERNAL_LOCATION",
    "catalog": "CATALOG",
    "schema": "SCHEMA",
    "volume": "VOLUME",
}


def fetch_live_grants(model: GovernanceModel) -> set[GrantKey] | None:
    """Read effective grants from the live metastore. Returns None if unavailable.

    Deferred, exactly like ``genie_space.deploy_space``: Genie/Grants reads need a
    live workspace + credentials that are absent in offline CI. With the SDK
    installed and ``DATABRICKS_HOST``/auth configured, this walks each securable
    and collects its ``(principal → privileges)`` assignments.
    """
    try:
        from databricks.sdk import WorkspaceClient
    except ImportError:
        print("databricks-sdk not installed — `pip install databricks-sdk` to run live reconciliation.")
        return None

    try:
        w = WorkspaceClient()
    except Exception as exc:  # noqa: BLE001 - any auth/config failure means "no live side"
        print(f"could not initialise Databricks workspace client ({exc}); skipping live reconciliation.")
        return None

    live: set[GrantKey] = set()
    for s in model.securables:
        sec_type = _SECURABLE_TYPE.get(s.object_type)
        if not sec_type:
            continue
        try:
            perms = w.grants.get(securable_type=sec_type, full_name=s.fqn)
        except Exception as exc:  # noqa: BLE001 - object may not exist yet; record nothing
            print(f"  (skip {s.object_type}:{s.fqn} — {exc})")
            continue
        for assignment in perms.privilege_assignments or []:
            privs = [p.value if hasattr(p, "value") else str(p) for p in (assignment.privileges or [])]
            live.add(_key(s.cloud, s.object_type, s.fqn, assignment.principal, privs))
    return live


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Reconcile committed grants against the live Unity Catalog.")
    parser.add_argument("--root", default=str(_default_repo_root()))
    parser.add_argument("--live", action="store_true", help="reconcile against live UC (needs databricks-sdk + creds)")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    model = build_model(root)
    expected = expected_grants(model)

    if not args.live:
        summary = {
            "mode": "offline",
            "expected_grants": len(expected),
            "clouds": sorted({k[0] for k in expected}),
            "note": "Run with --live (and databricks-sdk + workspace creds) to reconcile against the live metastore.",
        }
        if args.format == "json":
            print(json.dumps(summary, indent=2))
        else:
            print(f"offline: {len(expected)} grants declared across {', '.join(summary['clouds'])}.")
            print(summary["note"])
        return 0

    live = fetch_live_grants(model)
    if live is None:
        # Deferred (no SDK/creds) — not a failure in CI, mirrors genie --deploy.
        return 0

    report = diff_grants(expected, live)
    if args.format == "json":
        print(json.dumps(report.as_dict(), indent=2))
    else:
        if report.in_sync:
            print("IN SYNC — every declared grant is enforced and no extra grants exist.")
        else:
            for k in report.missing_in_catalog:
                print(f"MISSING  [{k[0]}] {k[1]}:{k[2]} → {k[3]} {sorted(k[4])} (declared, not enforced)")
            for k in report.extra_in_catalog:
                print(f"EXTRA    [{k[0]}] {k[1]}:{k[2]} → {k[3]} {sorted(k[4])} (enforced, not declared)")
    # Live drift is a real problem — gate on it when running live.
    return 0 if report.in_sync else 1


if __name__ == "__main__":
    sys.exit(main())
