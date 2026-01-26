# pull_request_target Behavior Change - Test Repository

This repository replicates a user scenario affected by the recent `pull_request_target` behavior change in GitHub Actions.

## Background

The `pull_request_target` event now runs workflows from the **default branch** instead of the **base branch** of the PR. This change was made for security purposes but breaks valid workflows for projects with long-lived stable branches.

## The Scenario

- **Open source project** receiving contributions from external forks
- **Three stable release branches**: `release/v1.1.x`, `release/v1.2.x`, `release/v1.3.x`
- **Intentionally divergent workflows** per branch (different Node versions, test frameworks, etc.)
- **Need for secrets** in CI to build/push container images (why they use `pull_request_target`)

## Quick Start

```bash
# Clone and setup
git clone <this-repo>
cd <repo-name>
./setup.sh
```

This creates:
- Stable branches with their own workflows
- Test branches for creating PRs
- Demonstrates the workflow testing problem

## Key Files

| File | Purpose |
|------|---------|
| `.github/workflows/pr-target-ci.yml` | Main workflow with stable branch workarounds |
| `docs/SCENARIO.md` | Detailed problem description |
| `docs/TESTING.md` | How to test and observe the issue |
| `setup.sh` | Script to create branch structure |
| `branch-workflows/` | Templates for stable branch workflows |

## The Problem in Brief

1. **PRs to stable branches run main's workflow** (not the target branch's workflow)
2. **Cannot test workflow changes** for stable branches without merging to main first
3. **Must maintain duplicate logic** in main for each stable branch

## See Also

- [docs/SCENARIO.md](docs/SCENARIO.md) - Full scenario description
- [docs/TESTING.md](docs/TESTING.md) - Testing guide
