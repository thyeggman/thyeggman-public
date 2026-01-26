#!/bin/bash
# Setup script for pull_request_target testing scenario
# This script creates the branch structure and test scenarios

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "=============================================="
echo "pull_request_target Test Scenario Setup"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    print_error "Not in a git repository!"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
print_step "Current branch: $CURRENT_BRANCH"

# Ensure we're on main
if [ "$CURRENT_BRANCH" != "main" ]; then
    print_warning "Not on main branch. Switching to main..."
    git checkout main
fi

# Make sure main is up to date with remote
print_step "Fetching latest changes..."
git fetch origin 2>/dev/null || true

# Stage 1: Commit main branch workflows
echo ""
print_step "Stage 1: Setting up main branch with workaround workflows"
echo ""

if [ -d ".github/workflows" ]; then
    git add .github/workflows/
    if git diff --cached --quiet; then
        print_success "Workflows already committed on main"
    else
        git commit -m "Add pull_request_target workflows with stable branch workarounds

This commit adds:
- pr-target-ci.yml: Main CI workflow using pull_request_target
  - Contains workaround copies for v1.1.x, v1.2.x, v1.3.x specific logic
  - This is the current workaround for the pull_request_target change
- basic-pr-checks.yml: Standard PR checks (no secrets needed)

The workaround is necessary because pull_request_target now runs from
the default branch instead of the base branch, but it prevents proper
testing of workflow changes intended for stable branches."
        print_success "Committed main branch workflows"
    fi
fi

# Commit other files on main
git add README.md docs/ branch-workflows/ 2>/dev/null || true
if ! git diff --cached --quiet; then
    git commit -m "Add documentation and branch workflow templates"
    print_success "Committed documentation and templates"
fi

# Push main
print_step "Pushing main branch..."
git push origin main 2>/dev/null || print_warning "Could not push main (may need to set upstream)"

# Stage 2: Create stable branches
echo ""
print_step "Stage 2: Creating stable release branches"
echo ""

create_stable_branch() {
    local BRANCH_NAME=$1
    local BRANCH_DIR=$2
    
    print_step "Creating $BRANCH_NAME..."
    
    # Check if branch exists locally
    if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
        print_warning "Branch $BRANCH_NAME already exists locally, deleting..."
        git branch -D $BRANCH_NAME
    fi
    
    # Create branch from main
    git checkout -b $BRANCH_NAME main
    
    # Remove main's workflow and replace with branch-specific
    rm -rf .github/workflows/*
    
    # Copy branch-specific workflow
    if [ -d "branch-workflows/$BRANCH_DIR/.github" ]; then
        cp -r branch-workflows/$BRANCH_DIR/.github/* .github/
        print_success "Copied $BRANCH_NAME specific workflows"
    fi
    
    # Create branch-specific marker file
    echo "# $BRANCH_NAME Branch" > BRANCH_INFO.md
    echo "" >> BRANCH_INFO.md
    echo "This is the stable $BRANCH_NAME branch." >> BRANCH_INFO.md
    echo "" >> BRANCH_INFO.md
    echo "## Workflow Differences from Main" >> BRANCH_INFO.md
    echo "" >> BRANCH_INFO.md
    echo "This branch has its own workflow configuration that is intentionally" >> BRANCH_INFO.md
    echo "different from main. However, due to the pull_request_target behavior" >> BRANCH_INFO.md
    echo "change, PRs targeting this branch will run the workflow from main," >> BRANCH_INFO.md
    echo "not the workflow defined here." >> BRANCH_INFO.md
    
    git add -A
    git commit -m "Configure $BRANCH_NAME with branch-specific workflows

This branch represents a stable maintenance release with:
- Its own workflow configuration frozen at release time
- Intentionally different CI/CD behavior from main
- Branch-specific test configurations

PROBLEM: Due to the pull_request_target change, PRs targeting this
branch will run the workflow from main, not this branch's workflow."
    
    # Push branch
    git push origin $BRANCH_NAME -f 2>/dev/null || print_warning "Could not push $BRANCH_NAME"
    
    print_success "Created and pushed $BRANCH_NAME"
}

create_stable_branch "release/v1.1.x" "release-v1.1.x"
create_stable_branch "release/v1.2.x" "release-v1.2.x"
create_stable_branch "release/v1.3.x" "release-v1.3.x"

# Return to main
git checkout main
print_success "Returned to main branch"

# Stage 3: Create test feature branches
echo ""
print_step "Stage 3: Creating test feature branches for PRs"
echo ""

create_test_branch() {
    local BRANCH_NAME=$1
    local BASE_BRANCH=$2
    local DESCRIPTION=$3
    
    print_step "Creating test branch: $BRANCH_NAME (from $BASE_BRANCH)"
    
    if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
        git branch -D $BRANCH_NAME
    fi
    
    git checkout -b $BRANCH_NAME $BASE_BRANCH
    
    # Create a test change
    mkdir -p src
    echo "// Test change for $BRANCH_NAME" > src/test-change.js
    echo "// $DESCRIPTION" >> src/test-change.js
    echo "console.log('Hello from $BRANCH_NAME');" >> src/test-change.js
    
    git add src/
    git commit -m "Test change: $DESCRIPTION"
    
    git push origin $BRANCH_NAME -f 2>/dev/null || print_warning "Could not push $BRANCH_NAME"
    
    print_success "Created $BRANCH_NAME"
}

# Create test branches that will be used for PRs
create_test_branch "test/pr-to-v1.1" "release/v1.1.x" "PR targeting v1.1.x (should use v1.1 workflow)"
create_test_branch "test/pr-to-v1.2" "release/v1.2.x" "PR targeting v1.2.x (should use v1.2 workflow)"  
create_test_branch "test/pr-to-v1.3" "release/v1.3.x" "PR targeting v1.3.x (should use v1.3 workflow)"
create_test_branch "test/pr-to-main" "main" "PR targeting main (uses main workflow)"

# Create a branch simulating a workflow change for stable branch
git checkout -b "test/workflow-change-v1.2" "release/v1.2.x"
cat > .github/workflows/pr-target-ci.yml << 'EOF'
# MODIFIED v1.2.x workflow - testing a workflow change
# This change should be testable on PRs to release/v1.2.x
# but due to pull_request_target change, it's not possible

name: PR Target CI (v1.2.x) - MODIFIED

on:
  pull_request_target:
    types: [opened, synchronize, reopened]

jobs:
  modified-job:
    runs-on: ubuntu-latest
    steps:
      - name: New step in v1.2.x workflow
        run: |
          echo "=== MODIFIED v1.2.x Workflow ==="
          echo "This is a workflow modification being tested."
          echo ""
          echo "PROBLEM: This workflow change cannot be properly tested!"
          echo "When a PR is opened from this branch to release/v1.2.x,"
          echo "the workflow from main will run, not this modified workflow."
          echo ""
          echo "The maintainer cannot verify their workflow changes work"
          echo "without first merging them to the default branch (main)."
EOF
git add .github/workflows/
git commit -m "Test: Modify v1.2.x workflow (cannot be tested before merge)

This branch contains a workflow modification for v1.2.x that we want
to test. However, due to pull_request_target running from the default
branch, this modification cannot be tested via a PR to release/v1.2.x.

This demonstrates the core problem the customer faces."
git push origin test/workflow-change-v1.2 -f 2>/dev/null || print_warning "Could not push test/workflow-change-v1.2"
print_success "Created test/workflow-change-v1.2 (demonstrates workflow testing problem)"

# Return to main
git checkout main

echo ""
echo "=============================================="
print_success "Setup Complete!"
echo "=============================================="
echo ""
echo "Branch Structure Created:"
echo "  - main (default) - Contains workaround workflow with stable branch copies"
echo "  - release/v1.1.x - Stable branch with v1.1 specific workflow"
echo "  - release/v1.2.x - Stable branch with v1.2 specific workflow"
echo "  - release/v1.3.x - Stable branch with v1.3 specific workflow"
echo ""
echo "Test Branches Created:"
echo "  - test/pr-to-v1.1 - Create PR to release/v1.1.x"
echo "  - test/pr-to-v1.2 - Create PR to release/v1.2.x"
echo "  - test/pr-to-v1.3 - Create PR to release/v1.3.x"
echo "  - test/pr-to-main - Create PR to main"
echo "  - test/workflow-change-v1.2 - Demonstrates workflow testing problem"
echo ""
echo "Next Steps:"
echo "  1. Create PRs from test branches to their respective targets"
echo "  2. Observe that all PRs run the workflow from main"
echo "  3. Note that test/workflow-change-v1.2 cannot be properly tested"
echo ""
echo "See docs/SCENARIO.md for detailed explanation"
