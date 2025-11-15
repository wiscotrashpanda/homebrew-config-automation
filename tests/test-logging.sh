#!/usr/bin/env bash
#
# Unit tests for logging functionality
#

set -euo pipefail

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test log directory
TEST_LOG_DIR="/tmp/homebrew-config-test-$$"
mkdir -p "${TEST_LOG_DIR}"

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

cleanup() {
    rm -rf "${TEST_LOG_DIR}"
}

trap cleanup EXIT

#######################################
# Test setup_logging function
#######################################

test_setup_logging_creates_directory() {
    LOG_DIR="${TEST_LOG_DIR}/logs1"
    LOG_FILE=""
    
    if setup_logging; then
        if [[ -d "${LOG_DIR}" ]]; then
            pass "setup_logging creates log directory"
        else
            fail "setup_logging directory creation"
        fi
    else
        fail "setup_logging execution"
    fi
}

test_setup_logging_creates_file() {
    LOG_DIR="${TEST_LOG_DIR}/logs2"
    LOG_FILE=""
    
    setup_logging
    
    if [[ -f "${LOG_FILE}" ]]; then
        pass "setup_logging creates log file"
    else
        fail "setup_logging file creation"
    fi
}

#######################################
# Test log_message function
#######################################

test_log_message_format() {
    LOG_DIR="${TEST_LOG_DIR}/logs3"
    LOG_FILE=""
    setup_logging
    
    log_message "INFO" "Test message"
    
    if grep -q "\[INFO\] Test message" "${LOG_FILE}"; then
        pass "log_message writes formatted message"
    else
        fail "log_message format"
    fi
}

test_log_message_levels() {
    LOG_DIR="${TEST_LOG_DIR}/logs4"
    LOG_FILE=""
    setup_logging
    
    log_message "INFO" "Info message"
    log_message "WARN" "Warn message"
    log_message "ERROR" "Error message"
    
    local info_count warn_count error_count
    info_count=$(grep -c "\[INFO\]" "${LOG_FILE}" || echo "0")
    warn_count=$(grep -c "\[WARN\]" "${LOG_FILE}" || echo "0")
    error_count=$(grep -c "\[ERROR\]" "${LOG_FILE}" || echo "0")
    
    if [[ ${info_count} -gt 0 && ${warn_count} -gt 0 && ${error_count} -gt 0 ]]; then
        pass "log_message handles all log levels"
    else
        fail "log_message log levels"
    fi
}

#######################################
# Test log rotation
#######################################

test_log_rotation_trigger() {
    LOG_DIR="${TEST_LOG_DIR}/logs5"
    LOG_FILE=""
    MAX_LOG_SIZE=1024  # 1KB for testing
    setup_logging
    
    # Write enough data to trigger rotation
    for i in {1..100}; do
        log_message "INFO" "Test message number ${i} with some padding to increase size"
    done
    
    # Try to rotate
    rotate_logs
    
    # Check if rotated log exists
    local rotated_count
    rotated_count=$(find "${LOG_DIR}" -name "homebrew-config-*.log" | wc -l)
    
    if [[ ${rotated_count} -gt 0 ]]; then
        pass "rotate_logs creates rotated log files"
    else
        fail "rotate_logs rotation trigger"
    fi
}

#######################################
# Run all tests
#######################################

echo "=========================================="
echo "Logging Tests"
echo "=========================================="
echo

test_setup_logging_creates_directory
test_setup_logging_creates_file
test_log_message_format
test_log_message_levels
test_log_rotation_trigger

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
