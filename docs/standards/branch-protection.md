# Branch Protection Standard

## Protected branch

The default protected branch is:

- `main`

## Minimum settings

Enable the following on `main`:

- Require a pull request before merging
- Require status checks to pass before merging
- Require branches to be up to date before merging
- Block force pushes
- Block branch deletion

## Recommended settings

Where appropriate, also enable:

- Require review from Code Owners
- Require at least one approval
- Enable auto-merge
- Dismiss stale reviews when new commits are pushed

## Required checks

At minimum, require the repository PR validation workflow.

Examples:

- `pr-validation`
- `Merge Test Workflow`

Standardization goal is to converge repos on a consistent required check name.

## Dependabot note

Dependabot auto-merge should only be enabled after:

- the PR validation workflow is required
- that workflow is stable
- the repository has dependable tests
