#!/usr/bin/env bash
#
# Unit tests for configuration loading
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
# Test expand_path function
#######################################

test_expand_path_tilde() {
    local result
    result=$(expand_path "~/test")
    if [[ "${result}" == "${HOME}/test" ]]; then
        pass "expand_path handles tilde notation"
    else
        fail "expand_path tilde expansion (expected: ${HOME}/test, got: ${result})"
    fi
}

test_expand_path_env_var() {
    export TEST_VAR="/tmp/test"
    local result
    result=$(expand_path "\$TEST_VAR/subdir")
    if [[ "${result}" == "/tmp/test/subdir" ]]; then
        pass "expand_path handles environment variables"
    else
        fail "expand_path env var expansion (expected: /tmp/test/subdir, got: ${result})"
    fi
    unset TEST_VAR
}

test_expand_path_absolute() {
    local result
    result=$(expand_path "/absolute/path")
    if [[ "${result}" == "/absolute/path" ]]; then
        pass "expand_path handles absolute paths"
    else
        fail "expand_path absolute path (expected: /absolute/path, got: ${result})"
    fi
}

#######################################
# Test load_configuration function
#######################################

test_load_configuration_defaults() {
    # Clear variables
    BREWFILE_DESTINATION=""
    LOG_DIR=""
    CONFIG_FILE="/nonexistent/config.sh"
    
    # Suppress log output for test
    LOG_FILE="/dev/null"
    
    load_configuration
    
    if [[ "${BREWFILE_DESTINATION}" == "${HOME}/Config" ]]; then
        pass "load_configuration sets default BREWFILE_DESTINATION"
    else
        fail "load_configuration default BREWFILE_DESTINATION (expected: ${HOME}/Config, got: ${BREWFILE_DESTINATION})"
    fi
    
    if [[ "${LOG_DIR}" == "${HOME}/.local/share/homebrew-config/logs" ]]; then
        pass "load_configuration sets default LOG_DIR"
    else
        fail "load_configuration default LOG_DIR"
    fi
}

test_load_configuration_from_file() {
    # Create temporary config file
    local temp_config="/tmp/test-config-$$.sh"
    cat > "${temp_config}" << 'EOF'
BREWFILE_DESTINATION="/tmp/test-brewfile"
MAX_LOG_SIZE=5242880
EOF
    
    # Clear variables
    BREWFILE_DESTINATION=""
    MAX_LOG_SIZE=""
    CONFIG_FILE="${temp_config}"
    LOG_FILE="/dev/null"
    
    load_configuration
    
    if [[ "${BREWFILE_DESTINATION}" == "/tmp/test-brewfile" ]]; then
        pass "load_configuration reads from config file"
    else
        fail "load_configuration config file reading"
    fi
    
    if [[ "${MAX_LOG_SIZE}" == "5242880" ]]; then
        pass "load_configuration loads custom values"
    else
        fail "load_configuration custom values"
    fi
    
    # Cleanup
    rm -f "${temp_config}"
}

#######################################
# Run all tests
#######################################

echo "=========================================="
echo "Configuration Tests"
echo "=========================================="
echo

test_expand_path_tilde
test_expand_path_env_var
test_expand_path_absolute
test_load_configuration_defaults
test_load_configuration_from_file

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
