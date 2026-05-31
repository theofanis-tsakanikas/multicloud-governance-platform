## Summary

<!-- One paragraph describing what this PR changes and why. -->

## Type of change

- [ ] New Terraform module or cloud layer
- [ ] Domain governance change (infra/grants JSON)
- [ ] CI/CD workflow change
- [ ] Documentation update
- [ ] Bug fix (non-breaking)
- [ ] Other:

## Layers changed

Mark every layer this PR touches:

**AWS**
- [ ] `bootstrap/aws/*`
- [ ] `aws/foundation`
- [ ] `aws/security/*`
- [ ] `aws/network`
- [ ] `aws/storage/*`
- [ ] `aws/integration`
- [ ] `aws/data_platform/*`

**Azure**
- [ ] `azure/foundation`
- [ ] `azure/security`
- [ ] `azure/network`
- [ ] `azure/storage/*`
- [ ] `azure/integration`
- [ ] `azure/data_platform/*`

**GCP**
- [ ] `bootstrap/gcp/*`
- [ ] `gcp/foundation`
- [ ] `gcp/security`
- [ ] `gcp/network`
- [ ] `gcp/storage`
- [ ] `gcp/integration`
- [ ] `gcp/data_platform/*`

## Pre-merge checklist

- [ ] `make validate` passes locally (fmt + hclfmt + Checkov + tfsec)
- [ ] `make plan-<cloud>` produces the expected diff (no unintended destroys)
- [ ] Domain JSON is valid (checked by `check-json` pre-commit hook)
- [ ] `deployment_id_*` in `config.hcl` updated if a full destroy preceded this change
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] `CLAUDE.md` / `ARCHITECTURE.md` updated if the dependency graph changed

## Notes for reviewers

<!-- Anything the reviewer should pay particular attention to. -->
