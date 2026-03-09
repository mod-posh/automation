# Adoption Checklist

Use this checklist when onboarding a repository to the `mod-posh` automation standard.

## Baseline

- [ ] Repository audited
- [ ] Repo type classified (.NET, PowerShell, mixed, other)
- [ ] Current workflows reviewed
- [ ] Current tests reviewed
- [ ] Current Dependabot state reviewed

## PR validation

- [ ] Reusable PR validation workflow selected
- [ ] Caller workflow added to repo
- [ ] Workflow passes on pull requests
- [ ] Required status check configured on `main`

## Tests

- [ ] Tests exist
- [ ] Test output is visible in workflow artifacts
- [ ] Obvious gaps are documented

## Dependabot

- [ ] `.github/dependabot.yml` added or updated
- [ ] NuGet updates configured where needed
- [ ] GitHub Actions updates configured where needed
- [ ] Grouping rules reviewed

## Auto-merge

- [ ] Repo meets eligibility requirements
- [ ] Dependabot auto-merge caller workflow added
- [ ] Patch update policy confirmed
- [ ] Minor update policy confirmed or intentionally disabled

## Documentation

- [ ] Repo included in inventory report
- [ ] Exceptions documented if needed
