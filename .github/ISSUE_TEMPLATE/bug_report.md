---
name: Bug report
about: Report a broken Terraform/Terragrunt layer, CI failure, or governance misconfiguration
title: "[BUG] "
labels: bug
assignees: ''
---

## Describe the bug

A clear description of what went wrong.

## Affected layer / cloud

- Cloud: [ ] AWS  [ ] Azure  [ ] GCP  [ ] Cross-cloud (Delta Sharing)
- Layer path (e.g. `aws/data_platform/dbx_governance`):

## Steps to reproduce

```bash
# e.g.
make plan LAYER=aws/security/iam
# or
terragrunt run-all apply --terragrunt-working-dir environments/dev/aws
```

## Expected behaviour

What you expected to happen.

## Actual behaviour / error output

```
Paste the full error message or Terraform output here.
```

## Environment

| Tool | Version |
|---|---|
| Terraform | |
| Terragrunt | |
| AWS CLI | |
| OS | |

## Additional context

Any other relevant context — related domain JSON, relevant `config.hcl` values (omit secrets), or a link to a failing CI run.
