# Dependabot Policy

This document defines the default Dependabot policy for repositories in the `mod-posh` organization.

## Objectives

- Keep dependencies current with minimal manual effort
- Reduce noise by grouping safe updates
- Auto-merge low-risk updates only after validation passes
- Keep major updates manual

## Baseline configuration

Maintained repositories should have `.github/dependabot.yml` with at least:

- `nuget` for .NET repositories
- `github-actions` for repositories with workflows
- weekly cadence
- grouped minor/patch updates where practical

## Auto-merge policy

Default policy:

- patch updates: eligible for auto-merge
- minor updates: eligible where the repo is stable and tests are trustworthy
- major updates: manual review only

## Eligibility requirements

Auto-merge may only be enabled when the repository has:

- tests
- PR validation
- branch protection
- required checks
- reliable merge behavior on `main`

## Security and implementation notes

- Prefer GitHub metadata over parsing PR titles
- Prefer enabling auto-merge over merging immediately
- Avoid running untrusted PR code in privileged workflows
- Pin third-party actions to full commit SHAs where possible

## Labels

Suggested labels:

- `dependencies`
- `dependabot`
- `dependabot-auto-merged`
- `manual-review`
