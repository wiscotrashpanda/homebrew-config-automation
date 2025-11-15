#!/usr/bin/env bash
#
# Integration tests for Homebrew detection
#

set -euo pipefail

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

#######################################
# Test check_homebrew function
#######################################

test_check_homebrew() {
    if command -v brew &> /dev/null; then
        if check_homebrew; then
            pass "check_homebrew detects installed Homebrew"
        else
            fail "check_homebrew detection"
        fi
    else
        if ! check_homebrew; then
            pass "check_homebrew correctly reports Homebrew not installed"
        else
            fail "check_homebrew false positive"
        fi
    fi
}

#######################################
# Run all tests
#######################################

echo "=========================================="
echo "Homebrew Detection Tests"
echo "=========================================="
echo

test_check_homebrew

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
