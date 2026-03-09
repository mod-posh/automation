# Repository Standard

This document defines the minimum standard for active repositories in the `mod-posh` organization.

## 1. Source control and governance

Every active repository should have:

- `main` as the protected integration branch
- pull requests required for changes to `main`
- required status checks enabled
- direct pushes to `main` disabled
- a CODEOWNERS file if the repo is intended to enforce ownership boundaries

## 2. CI / PR validation

Every active repository should have a pull request validation workflow.

Minimum expectation:

- trigger on `pull_request`
- build the project
- run tests
- fail the PR if validation fails

If a repository uses merge queue in the future, `merge_group` should also be added.

## 3. Testing expectation

Every code repository should have tests appropriate to its implementation style.

### .NET repositories

Expected indicators:

- one or more `.sln` or `.csproj` files
- one or more test projects
- PR workflow runs restore / build / test

### PowerShell repositories

Expected indicators:

- `.psd1` / `.psm1`
- `tests/` folder with Pester tests
- PR workflow runs `Invoke-Pester`

## 4. Dependabot

Every maintained repository should have `.github/dependabot.yml`.

Baseline expectation:

- NuGet updates enabled for .NET repositories
- GitHub Actions updates enabled for repositories with workflows
- weekly schedule unless there is a reason to do otherwise

## 5. Dependabot auto-merge eligibility

A repository is only eligible for Dependabot auto-merge when all of the following are true:

- tests exist
- PR validation exists
- PR validation is reliable
- branch protection is enabled
- required checks are configured
- major updates are excluded from auto-merge

Patch updates are the default safe target.

Minor updates may be enabled on a per-repo basis.

Major updates require manual review.

## 6. Required inventory metadata

The audit process should classify each repository for:

- repo type
- test presence
- workflow presence
- Dependabot presence
- readiness for auto-merge

## 7. Exceptions

If a repo intentionally does not meet this standard, document the reason in:

- `docs/rollout/exceptions.md`
