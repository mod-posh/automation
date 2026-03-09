# mod-posh automation

This repository is the central home for shared automation, governance, and rollout tracking across the `mod-posh` GitHub organization.

## What lives here

- Reusable GitHub Actions workflows
- Repository standards and governance docs
- Audit scripts that inventory repo readiness
- Generated reports for adoption tracking

## Goals

This repo exists to make the org more consistent and easier to maintain.

Primary goals:

1. Standardize pull request validation across repositories
2. Standardize Dependabot handling and auto-merge policy
3. Inventory repositories for missing tests, missing workflows, and missing Dependabot configuration
4. Provide one place for documentation and rollout tracking

## Shared workflow targets

Today the org includes both:

- .NET repositories with restore/build/test workflows
- PowerShell repositories with Pester test suites

This repo provides reusable workflows for both patterns.

## Repository standards

Each active repository should eventually have:

- a PR validation workflow
- tests appropriate to the repo type
- a Dependabot configuration
- branch protection on `main`
- required status checks enabled
- auto-merge only where validation is trustworthy

See:

- `docs/standards/repo-standard.md`
- `docs/standards/dependabot-policy.md`
- `docs/standards/branch-protection.md`

## Audit reports

Generated inventory and readiness reports are stored under:

- `reports/latest/repo-inventory.json`
- `reports/latest/repo-inventory.md`

## Reusable workflows

- `.github/workflows/reusable-dotnet-pr-validation.yml`
- `.github/workflows/reusable-powershell-pr-validation.yml`
- `.github/workflows/reusable-dependabot-auto-merge.yml`

## Rollout approach

1. Audit current repositories
2. Standardize PR validation
3. Backfill tests where missing
4. Enable Dependabot consistently
5. Enable Dependabot auto-merge only for repos that meet the standard
