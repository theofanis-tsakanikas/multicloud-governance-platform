#!/usr/bin/env bash
# Thin wrapper around the Databricks CLI for the medallion Asset Bundle.
# Usage:
#   ./bundle.sh validate <aws|gcp>
#   ./bundle.sh deploy   <aws|gcp>   # uploads SQL + notebook, creates the Jobs
#   ./bundle.sh run      <aws|gcp>   # runs the medallion job (the "click play")
#
# Prereqs: `databricks` CLI authenticated to the target workspace.
#   export DATABRICKS_HOST=<workspace url>   (the CLI's own variable — the bundle
#   cannot interpolate it, and should not: it is an authentication field)
# Pass the SQL warehouse id:  WAREHOUSE_ID=<id> ./bundle.sh deploy aws
set -euo pipefail

cmd="${1:?usage: ./bundle.sh <validate|deploy|run> <aws|gcp>}"
target="${2:?pick a target: aws | gcp}"
cd "$(dirname "$0")"

var_args=()
[[ -n "${WAREHOUSE_ID:-}" ]] && var_args=(--var "warehouse_id=${WAREHOUSE_ID}")

case "$cmd" in
  validate) databricks bundle validate -t "$target" "${var_args[@]}" ;;
  deploy)   databricks bundle deploy   -t "$target" "${var_args[@]}" ;;
  run)      databricks bundle run "medallion_${target}" -t "$target" "${var_args[@]}" ;;
  *) echo "unknown command: $cmd" && exit 1 ;;
esac
