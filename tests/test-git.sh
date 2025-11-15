#!/usr/bin/env bash
#
# Integration tests for Git functionality
#

set -euo pipefail

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR="/tmp/homebrew-config-git-test-$$"
mkdir -p "${TEST_DIR}"

# Source the main script functions
source "$(dirname "$0")/../brew-config.sh" 2>/dev/null || {
    echo "ERROR: Cannot source brew-config.sh"
    exit 1
}

# Suppress logging for tests
LOG_FILE="/dev/null"

#######################################
# Test helper functions
#######################################

pass() {
    echo "✓ $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo "✗ $1"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

cleanup() {
    rm -rf "${TEST_DIR}"
}

trap cleanup EXIT

#######################################
# Test is_git_repository function
#######################################

test_is_git_repository_positive() {
    local git_dir="${TEST_DIR}/git-repo"
    mkdir -p "${git_dir}"
    cd "${git_dir}"
    git init &> /dev/null
    
    if is_git_repository "${git_dir}"; then
        pass "is_git_repository detects Git repository"
    else
        fail "is_git_repository detection"
    fi
}

test_is_git_repository_negative() {
    local non_git_dir="${TEST_DIR}/non-git"
    mkdir -p "${non_git_dir}"
    
    if ! is_git_repository "${non_git_dir}"; then
        pass "is_git_repository correctly identifies non-repository"
    else
        fail "is_git_repository false positive"
    fi
}

#######################################
# Test commit_to_git function
#######################################

test_commit_to_git_with_changes() {
    local git_dir="${TEST_DIR}/git-commit-test"
    mkdir -p "${git_dir}"
    cd "${git_dir}"
    git init &> /dev/null
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create a Brewfile with content
    echo "brew 'git'" > Brewfile
    git add Brewfile
    git commit -m "Initial commit" &> /dev/null
    
    # Modify Brewfile
    echo "brew 'wget'" >> Brewfile
    
    BREWFILE_DESTINATION="${git_dir}"
    GIT_COMMIT_ENABLED=true
    
    if commit_to_git; then
        # Check if commit was created
        local commit_count
        commit_count=$(git log --oneline | wc -l)
        if [[ ${commit_count} -eq 2 ]]; then
            pass "commit_to_git creates commit with changes"
        else
            fail "commit_to_git commit creation"
        fi
    else
        fail "commit_to_git execution"
    fi
}

test_commit_to_git_no_changes() {
    local git_dir="${TEST_DIR}/git-no-changes"
    mkdir -p "${git_dir}"
    cd "${git_dir}"
    git init &> /dev/null
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create and commit Brewfile
    echo "brew 'git'" > Brewfile
    git add Brewfile
    git commit -m "Initial commit" &> /dev/null
    
    BREWFILE_DESTINATION="${git_dir}"
    GIT_COMMIT_ENABLED=true
    
    if commit_to_git; then
        # Check that no new commit was created
        local commit_count
        commit_count=$(git log --oneline | wc -l)
        if [[ ${commit_count} -eq 1 ]]; then
            pass "commit_to_git skips commit when no changes"
        else
            fail "commit_to_git unnecessary commit"
        fi
    else
        fail "commit_to_git execution with no changes"
    fi
}

#######################################
# Run all tests
#######################################

echo "=========================================="
echo "Git Integration Tests"
echo "=========================================="
echo

test_is_git_repository_positive
test_is_git_repository_negative
test_commit_to_git_with_changes
test_commit_to_git_no_changes

echo
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo "Tests run:    ${TESTS_RUN}"
echo "Tests passed: ${TESTS_PASSED}"
echo "Tests failed: ${TESTS_FAILED}"
echo

if [[ ${TESTS_FAILED} -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
