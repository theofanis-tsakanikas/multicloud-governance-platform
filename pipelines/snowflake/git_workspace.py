#!/usr/bin/env python3
"""Verify that Snowflake can read this repository — and print the one manual step left.

This is the acceptance test for ADR-0015. Terraform creates the API integration and the
GIT REPOSITORY object; this asserts they actually resolve against GitHub, which Terraform
cannot tell you (Snowflake does not contact GitHub at CREATE time — only at FETCH).

    python3 pipelines/snowflake/git_workspace.py

Exit codes
    0  the repository fetches and the notebook is visible — create the Workspace and you're done
    1  the fetch failed — almost always because the repository is still private

Credentials come from the environment, as everywhere else in this repo:

    export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=...
"""

import os
import sys
import snowflake.connector

REPO = '"sales_aws"."_GOVERNANCE"."governance_repo"'
BRANCH = "main"
NOTEBOOK_DIR = "pipelines/snowflake"
NOTEBOOK = "governance_demo.ipynb"


def main() -> int:
    con = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "DEV_SALES_WH"),
        login_timeout=30,
    )
    cur = con.cursor()

    # The fetch is the whole test: it is the first moment Snowflake actually calls GitHub.
    try:
        cur.execute(f"ALTER GIT REPOSITORY {REPO} FETCH")
        print(f"  ok   fetched {REPO}")
    except Exception as e:
        print(f"  FAIL could not fetch {REPO}\n       {e}\n")
        print("  The overwhelmingly likely cause: the repository is still PRIVATE.")
        print("  Snowflake creates the objects against a private repo happily; it just cannot")
        print("  read it. Make the repo public (or wire a PAT — see the git_credentials note in")
        print("  infra/snowflake/modules/global/git_repository/variables.tf) and re-run.")
        con.close()
        return 1

    listing = cur.execute(
        f"LS @{REPO}/branches/{BRANCH}/{NOTEBOOK_DIR}/"
    ).fetchall()
    names = [r[0] for r in listing]
    found = any(NOTEBOOK in n for n in names)

    print(f"  {'ok  ' if found else 'FAIL'} {NOTEBOOK} {'visible' if found else 'NOT FOUND'} "
          f"in {NOTEBOOK_DIR}/ on {BRANCH} ({len(names)} files)")
    con.close()
    if not found:
        return 1

    print(f"""
  Snowflake can read the repository. One manual step remains — there is no API for it:

      Snowsight -> Projects -> Workspaces -> Create Workspace -> From Git repository
        Repository URL   {os.environ.get('GITHUB_REPO_URL', 'https://github.com/<owner>/<repo>')}
        API integration  DEV_GIT_INTEGRATION
        Authentication   Public repository

  Every .ipynb in the repo then opens as a native Workspace notebook, synced to {BRANCH}.
  `git push` is the deploy. deploy_notebook.py can be deleted.
""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
