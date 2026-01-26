# Testing Guide

This document explains how to test and observe the `pull_request_target` behavior change.

## Prerequisites

1. Repository access with ability to create branches and PRs
2. GitHub Actions enabled
3. Run the setup script: `./setup.sh`

## Test Scenarios

### Scenario 1: PR Targeting a Stable Branch

**Goal**: Observe that the main branch workflow runs instead of the target branch workflow.

**Steps**:
1. Go to GitHub and create a new PR
2. Base: `release/v1.2.x`
3. Compare: `test/pr-to-v1.2`
4. Create the PR
5. Observe the Actions tab

**Expected Behavior (before change)**:
- The workflow from `release/v1.2.x` runs
- You'd see "v1.2.x Branch CI" with Node 18, Jest 28, security scanning

**Actual Behavior (after change)**:
- The workflow from `main` runs
- You see the workaround logic determining "v1.2" context
- The `ci-v1-2` job runs (workaround copy on main)

### Scenario 2: Testing Workflow Changes (The Core Problem)

**Goal**: Demonstrate that workflow changes cannot be tested before merging to default branch.

**Steps**:
1. Create a PR from `test/workflow-change-v1.2` → `release/v1.2.x`
2. This branch contains a modified v1.2.x workflow
3. Observe the Actions tab

**What Happens**:
- The workflow from `main` runs
- The modified workflow in `test/workflow-change-v1.2` is **never executed**
- The maintainer cannot verify their workflow changes work
- They must blindly merge to main to test

### Scenario 3: Multiple Stable Branches

**Goal**: Show that the workaround requires maintaining parallel logic in main.

**Steps**:
1. Create PR: `test/pr-to-v1.1` → `release/v1.1.x`
2. Create PR: `test/pr-to-v1.2` → `release/v1.2.x`
3. Create PR: `test/pr-to-v1.3` → `release/v1.3.x`
4. Observe all three use main's workflow

**Observation**:
- All three PRs run from the same workflow file on main
- Main's workflow must contain conditional logic for all three versions
- Any workflow change for v1.1.x/v1.2.x/v1.3.x must be updated in main

### Scenario 4: Fork-Based PR (External Contributor)

**Goal**: Demonstrate why `pull_request` cannot be used.

**Steps**:
1. Fork the repository
2. Create a branch in your fork
3. Open a PR to the upstream `release/v1.2.x`

**What Happens with `pull_request_target`**:
- Workflow runs with access to secrets
- Container images can be built and pushed
- CI completes successfully

**What Would Happen with `pull_request`**:
- Workflow runs without secrets
- Cannot push to container registry
- CI fails or is incomplete

## Workflow Run Comparison

### Main Branch Workflow (What Actually Runs)

Location: `main:.github/workflows/pr-target-ci.yml`

```yaml
jobs:
  determine-context:
    # Figures out which branch is being targeted
    
  build-and-push:
    # Common build logic (needs secrets)
    
  ci-v1-1:
    if: base_ref == 'release/v1.1.x'
    # WORKAROUND: Copy of v1.1.x logic
    
  ci-v1-2:
    if: base_ref == 'release/v1.2.x'
    # WORKAROUND: Copy of v1.2.x logic
    
  ci-v1-3:
    if: base_ref == 'release/v1.3.x'
    # WORKAROUND: Copy of v1.3.x logic
```

### Stable Branch Workflow (What Should Run But Doesn't)

Location: `release/v1.2.x:.github/workflows/pr-target-ci.yml`

```yaml
jobs:
  security-scan:
    # v1.2.x specific security scan
    
  build-and-test:
    # v1.2.x specific build with Node 18, Jest 28
```

## Verification Commands

### Check workflow file on different branches

```bash
# Main branch workflow
git show main:.github/workflows/pr-target-ci.yml

# v1.2.x branch workflow (different!)
git show release/v1.2.x:.github/workflows/pr-target-ci.yml

# See the difference
git diff main:release/v1.2.x -- .github/workflows/pr-target-ci.yml
```

### List all branches

```bash
git branch -a
```

### Check which workflow would run

For any PR targeting `release/v1.2.x`, check:
```bash
# This is what SHOULD run:
git show release/v1.2.x:.github/workflows/pr-target-ci.yml

# This is what ACTUALLY runs (after the change):
git show main:.github/workflows/pr-target-ci.yml
```

## Key Observations

1. **Workflow Mismatch**: The workflow that runs doesn't match what's on the target branch

2. **Cannot Test Changes**: Workflow modifications in feature branches are never executed

3. **Duplication Required**: Main must contain logic for all stable branches

4. **Version Drift**: As stable branches diverge, main's workaround logic becomes more complex

5. **Security Trade-off**: The change was made for security, but the workaround adds maintenance burden
