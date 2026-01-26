# pull_request_target Test Scenario

This repository replicates a customer scenario affected by the `pull_request_target` behavior change.

## The Breaking Change

GitHub Actions recently changed the `pull_request_target` event so that workflows triggered by this event run in the context of the **default branch** instead of the **base branch** of the PR.

### Before the Change
```
PR: feature-branch → release/v1.2.x
Workflow runs from: release/v1.2.x (base branch)
```

### After the Change
```
PR: feature-branch → release/v1.2.x
Workflow runs from: main (default branch)
```

## Customer Scenario

### Their Setup

The customer maintains an open-source project with:

1. **Long-lived stable branches** for the last 3 minor versions:
   - `release/v1.1.x`
   - `release/v1.2.x`
   - `release/v1.3.x`

2. **Intentionally divergent workflows** - each stable branch has its own CI configuration frozen at release time:
   - Different Node.js versions
   - Different test frameworks
   - Different security scanning rules
   - Different container image configurations

3. **External contributors** who fork the repo and submit PRs from forks

4. **Need for secrets** in CI to build and push container images to an external registry

### Why They Need `pull_request_target`

Standard `pull_request` triggers cannot be used because:
- External contributor PRs from forks don't have access to repository secrets
- They need to build container images during CI
- Container images need to be pushed to an external registry
- The images are consumed by later CI steps

### The Problem

With the new `pull_request_target` behavior:

1. **All PRs run the main branch workflow**, regardless of target branch
2. **Stable branch workflows are ignored** - they diverge intentionally but are never used
3. **Cannot test workflow changes** - changes to a stable branch workflow can't be tested via PR

### Current Workaround

The customer maintains **copies of stable branch workflows on the default branch**:

```yaml
# In main's workflow
jobs:
  ci-v1-1:
    if: github.base_ref == 'release/v1.1.x'
    # ... v1.1.x specific steps ...
  
  ci-v1-2:
    if: github.base_ref == 'release/v1.2.x'
    # ... v1.2.x specific steps ...
  
  ci-v1-3:
    if: github.base_ref == 'release/v1.3.x'
    # ... v1.3.x specific steps ...
```

### Problems with the Workaround

1. **Cannot test workflow changes** for stable branches:
   - Want to modify `release/v1.2.x` workflow
   - Create PR from `test/workflow-change` → `release/v1.2.x`
   - The PR runs main's workflow, not the modified workflow
   - Must merge to main first to test (defeats the purpose)

2. **Workflow duplication** - must maintain copies in main

3. **Synchronization burden** - any change requires updates in multiple places

## Repository Structure

```
├── .github/workflows/
│   ├── pr-target-ci.yml      # Main workflow with workaround copies
│   └── basic-pr-checks.yml   # Standard PR checks (no secrets)
├── branch-workflows/         # Templates for stable branch workflows
│   ├── release-v1.1.x/
│   ├── release-v1.2.x/
│   └── release-v1.3.x/
├── docs/
│   ├── SCENARIO.md           # This file
│   └── TESTING.md            # How to test
├── setup.sh                  # Script to create branches and test scenarios
└── README.md
```

## Quick Start

```bash
# Clone the repo
git clone <repo-url>
cd <repo>

# Run setup script to create all branches
./setup.sh

# Create test PRs from GitHub UI
```

## What to Observe

1. **Create a PR from `test/pr-to-v1.2` → `release/v1.2.x`**
   - Expected (before change): v1.2.x specific workflow runs
   - Actual (after change): main's workflow runs with v1.2 workaround logic

2. **Create a PR from `test/workflow-change-v1.2` → `release/v1.2.x`**
   - This branch has a modified v1.2.x workflow
   - The modification cannot be tested because main's workflow runs instead
   - The customer cannot verify their workflow change works before merging

## The Ask

The customer cannot opt-out of the new behavior for security reasons. They need a solution that allows:

1. Workflows to run from the appropriate branch (base or target)
2. OR a secure way to test workflow changes for stable branches
3. OR some mechanism to maintain branch-specific workflow logic without duplication
