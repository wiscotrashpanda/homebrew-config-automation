#!/usr/bin/env bash
#
# Test runner - executes all test scripts
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Homebrew Config - Test Suite Runner"
echo "=========================================="
echo

# Find all test scripts
TEST_SCRIPTS=(
    "${SCRIPT_DIR}/test-config.sh"
    "${SCRIPT_DIR}/test-logging.sh"
    "${SCRIPT_DIR}/test-homebrew.sh"
    "${SCRIPT_DIR}/test-git.sh"
)

# Run each test script
for test_script in "${TEST_SCRIPTS[@]}"; do
    if [[ ! -f "${test_script}" ]]; then
        echo -e "${YELLOW}⚠ Skipping missing test: $(basename "${test_script}")${NC}"
        continue
    fi
    
    ((TOTAL_SUITES++))
    
    echo
    echo "Running: $(basename "${test_script}")"
    echo "------------------------------------------"
    
    if bash "${test_script}"; then
        echo -e "${GREEN}✓ Test suite passed${NC}"
        ((PASSED_SUITES++))
    else
        echo -e "${RED}✗ Test suite failed${NC}"
        ((FAILED_SUITES++))
    fi
done

# Print summary
echo
echo "=========================================="
echo "Test Suite Summary"
echo "=========================================="
echo "Total test suites:  ${TOTAL_SUITES}"
echo -e "Passed:             ${GREEN}${PASSED_SUITES}${NC}"
if [[ ${FAILED_SUITES} -gt 0 ]]; then
    echo -e "Failed:             ${RED}${FAILED_SUITES}${NC}"
else
    echo -e "Failed:             ${FAILED_SUITES}"
fi
echo

# Exit with appropriate code
if [[ ${FAILED_SUITES} -eq 0 ]]; then
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}Some test suites failed!${NC}"
    exit 1
fi
