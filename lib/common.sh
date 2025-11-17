#!/bin/bash
#
# Shared helper functions for install/uninstall scripts
#

if [[ -n "${HOMEBREW_CONFIG_COMMON_SOURCED:-}" ]]; then
    return 0
fi

readonly HOMEBREW_CONFIG_COMMON_SOURCED=true

# Color codes for consistent CLI output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

print_header() {
    echo ""
    echo "========================================="
    echo "$*"
    echo "========================================="
    echo ""
}

require_argument() {
    local option="$1"
    local value="$2"

    if [[ -z "${value}" ]]; then
        print_error "${option} requires a value"
        exit 2
    fi
}

expand_path() {
    local input_path="$1"

    if [[ -z "${input_path}" ]]; then
        echo ""
        return 0
    fi

    if [[ "${input_path}" == "~" || "${input_path}" == ~/* ]]; then
        input_path="${input_path/#\~/$HOME}"
    fi

    echo "${input_path}"
}
