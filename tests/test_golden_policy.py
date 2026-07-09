"""Golden corpus: prove the analyzer flags every modelled violation and stays
quiet on clean config. Cases live in tests/golden/corpus.json so the corpus can
grow without touching test code."""

import json
from pathlib import Path

import pytest

from policy_analyzer import run_analysis

CORPUS = json.loads((Path(__file__).parent / "golden" / "corpus.json").read_text(encoding="utf-8"))["cases"]


def _materialize(case: dict, repo_root: Path) -> None:
    cloud_dir = repo_root / "environments" / "dev" / "domains" / case["cloud"].lower()
    cloud_dir.mkdir(parents=True, exist_ok=True)
    name = case["name"]
    (cloud_dir / f"{name}_infra.json").write_text(json.dumps(case["infra"]), encoding="utf-8")
    (cloud_dir / f"{name}_grants.json").write_text(json.dumps(case["grants"]), encoding="utf-8")


@pytest.mark.parametrize("case", CORPUS, ids=[c["name"] for c in CORPUS])
def test_golden_case(case: dict, tmp_path: Path) -> None:
    _materialize(case, tmp_path)
    result = run_analysis(tmp_path)
    rules_seen = {f.rule for f in result.findings}

    for expected_rule in case["expect_rules"]:
        assert expected_rule in rules_seen, f"{case['name']}: expected rule {expected_rule} not raised (saw {sorted(rules_seen)})"

    gating = {f.rule for f in result.gating}
    assert gating == set(case["expect_gating"]), f"{case['name']}: gating {sorted(gating)} != expected {sorted(case['expect_gating'])}"


def test_corpus_covers_every_rule() -> None:
    """The corpus must exercise every rule the analyzer can emit (no blind spots)."""
    from policy_analyzer import _DIMENSION

    covered = {rule for case in CORPUS for rule in case["expect_rules"]}
    missing = set(_DIMENSION) - covered
    assert not missing, f"golden corpus does not exercise these rules: {sorted(missing)}"
