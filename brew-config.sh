#!/bin/bash
#
# Homebrew Configuration Automation Script
# Manages Homebrew installation, upgrades, and Brewfile generation
# Version: 1.0.0
#

set -e  # Exit on error for critical operations (we'll handle non-critical ones explicitly)
set -u  # Exit on undefined variable
set -o pipefail  # Catch errors in pipes

# Script version
readonly SCRIPT_VERSION="1.0.0"

# Default configuration
DEFAULT_BREWFILE_DESTINATION="${HOME}/Config"
DEFAULT_LOG_DIR="${HOME}/.local/share/homebrew-config/logs"
DEFAULT_CONFIG_FILE="${HOME}/.config/homebrew-config/config.sh"
DEFAULT_MAX_LOG_SIZE=10485760  # 10MB
DEFAULT_MAX_LOG_FILES=5
DEFAULT_GIT_COMMIT_ENABLED=true

# Runtime variables
BREWFILE_DESTINATION=""
LOG_DIR=""
CONFIG_FILE=""
MAX_LOG_SIZE=""
MAX_LOG_FILES=""
GIT_COMMIT_ENABLED=""
LOG_FILE=""
START_TIME=""

# Execution state
HOMEBREW_WAS_INSTALLED=false
UPGRADE_SUCCESS=false
BREWFILE_GENERATED=false
GIT_COMMIT_CREATED=false

#############################################
# Logging Functions
#############################################

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%S%z")"

    # Ensure log directory exists
    if [[ -n "${LOG_DIR}" && ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}" 2>/dev/null || true
    fi

    # Write to log file if it's set
    if [[ -n "${LOG_FILE}" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi

    # Also output to console for INFO and WARN
    if [[ "${level}" == "INFO" ]] || [[ "${level}" == "WARN" ]]; then
        echo "[${level}] ${message}"
    elif [[ "${level}" == "ERROR" ]] || [[ "${level}" == "FATAL" ]]; then
        echo "[${level}] ${message}" >&2
    fi
}

rotate_logs() {
    if [[ ! -f "${LOG_FILE}" ]]; then
        return 0
    fi

    local log_size
    log_size=$(stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0)

    if [[ ${log_size} -ge ${MAX_LOG_SIZE} ]]; then
        local timestamp
        timestamp="$(date +"%Y%m%d-%H%M%S")"
        local rotated_log="${LOG_DIR}/homebrew-config-${timestamp}.log"

        if mv "${LOG_FILE}" "${rotated_log}" 2>/dev/null; then
            log_message "INFO" "Rotated log file to ${rotated_log}"

            # Delete old log files if we exceed the maximum
            local log_count
            log_count=$(find "${LOG_DIR}" -name "homebrew-config-*.log" -type f | wc -l | tr -d ' ')

            if [[ ${log_count} -gt ${MAX_LOG_FILES} ]]; then
                local files_to_delete=$((log_count - MAX_LOG_FILES))
                find "${LOG_DIR}" -name "homebrew-config-*.log" -type f -print0 | \
                    xargs -0 ls -t | \
                    tail -n "${files_to_delete}" | \
                    xargs rm -f 2>/dev/null || log_message "WARN" "Failed to delete old log files"
            fi
        else
            log_message "WARN" "Failed to rotate log file"
        fi
    fi
}

setup_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "${LOG_DIR}" ]]; then
        if ! mkdir -p "${LOG_DIR}"; then
            echo "ERROR: Failed to create log directory: ${LOG_DIR}" >&2
            exit 3
        fi
    fi

    # Set log file path
    LOG_FILE="${LOG_DIR}/homebrew-config.log"

    # Check if we can write to the log file
    if ! touch "${LOG_FILE}" 2>/dev/null; then
        echo "ERROR: Cannot write to log file: ${LOG_FILE}" >&2
        exit 3
    fi

    # Rotate logs if needed
    rotate_logs

    log_message "INFO" "========================================="
    log_message "INFO" "Homebrew Config Automation v${SCRIPT_VERSION}"
    log_message "INFO" "Started at ${START_TIME}"
    log_message "INFO" "========================================="
}

#############################################
# Configuration Functions
#############################################

load_configuration() {
    # Start with defaults
    BREWFILE_DESTINATION="${DEFAULT_BREWFILE_DESTINATION}"
    LOG_DIR="${DEFAULT_LOG_DIR}"
    MAX_LOG_SIZE="${DEFAULT_MAX_LOG_SIZE}"
    MAX_LOG_FILES="${DEFAULT_MAX_LOG_FILES}"
    GIT_COMMIT_ENABLED="${DEFAULT_GIT_COMMIT_ENABLED}"

    # Load from environment variables if set
    BREWFILE_DESTINATION="${HOMEBREW_CONFIG_DESTINATION:-${BREWFILE_DESTINATION}}"
    LOG_DIR="${HOMEBREW_CONFIG_LOG_DIR:-${LOG_DIR}}"
    MAX_LOG_SIZE="${HOMEBREW_CONFIG_MAX_LOG_SIZE:-${MAX_LOG_SIZE}}"
    MAX_LOG_FILES="${HOMEBREW_CONFIG_MAX_LOG_FILES:-${MAX_LOG_FILES}}"
    GIT_COMMIT_ENABLED="${HOMEBREW_CONFIG_GIT_COMMIT:-${GIT_COMMIT_ENABLED}}"

    # Load from configuration file if it exists
    if [[ -f "${CONFIG_FILE}" ]]; then
        # Source the config file in a subshell to validate it first
        if bash -n "${CONFIG_FILE}" 2>/dev/null; then
            # shellcheck source=/dev/null
            source "${CONFIG_FILE}"
            log_message "INFO" "Loaded configuration from ${CONFIG_FILE}"
        else
            log_message "ERROR" "Configuration file has syntax errors: ${CONFIG_FILE}"
            exit 2
        fi
    fi

    # Expand tilde and environment variables in paths
    BREWFILE_DESTINATION="${BREWFILE_DESTINATION/#\~/$HOME}"
    LOG_DIR="${LOG_DIR/#\~/$HOME}"

    # Validate configuration
    validate_configuration
}

validate_configuration() {
    # Validate MAX_LOG_SIZE is a number
    if ! [[ "${MAX_LOG_SIZE}" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "MAX_LOG_SIZE must be a number: ${MAX_LOG_SIZE}"
        exit 2
    fi

    # Validate MAX_LOG_FILES is a number
    if ! [[ "${MAX_LOG_FILES}" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "MAX_LOG_FILES must be a number: ${MAX_LOG_FILES}"
        exit 2
    fi

    # Validate BREWFILE_DESTINATION is writable (or can be created)
    if [[ -e "${BREWFILE_DESTINATION}" && ! -d "${BREWFILE_DESTINATION}" ]]; then
        log_message "ERROR" "Brewfile destination exists and is not a directory: ${BREWFILE_DESTINATION}"
        exit 2
    fi

    local dest_parent
    dest_parent="$(dirname "${BREWFILE_DESTINATION}")"

    if [[ -d "${BREWFILE_DESTINATION}" ]]; then
        if [[ ! -w "${BREWFILE_DESTINATION}" ]]; then
            log_message "ERROR" "Brewfile destination is not writable: ${BREWFILE_DESTINATION}"
            exit 3
        fi
    else
        if [[ ! -d "${dest_parent}" ]]; then
            if ! mkdir -p "${dest_parent}" 2>/dev/null; then
                log_message "ERROR" "Failed to create Brewfile destination parent directory: ${dest_parent}"
                exit 3
            fi
        fi

        if [[ ! -w "${dest_parent}" ]]; then
            log_message "ERROR" "Cannot create Brewfile destination (parent not writable): ${dest_parent}"
            exit 3
        fi
    fi
}

#############################################
# Homebrew Functions
#############################################

check_homebrew() {
    if command -v brew &> /dev/null; then
        log_message "INFO" "Homebrew is already installed"
        return 0
    else
        log_message "INFO" "Homebrew is not installed"
        return 1
    fi
}

install_homebrew() {
    log_message "INFO" "Installing Homebrew..."

    # Download and run the official Homebrew installation script
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        HOMEBREW_WAS_INSTALLED=true
        log_message "INFO" "Homebrew installed successfully"

        # Add Homebrew to PATH for this session (for Apple Silicon Macs)
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        return 0
    else
        log_message "FATAL" "Failed to install Homebrew"
        exit 1
    fi
}

upgrade_homebrew() {
    log_message "INFO" "Upgrading Homebrew packages..."

    local upgrade_start
    upgrade_start="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Run brew upgrade and capture output
    if brew upgrade 2>&1 | tee -a "${LOG_FILE}"; then
        local upgrade_end
        upgrade_end="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        UPGRADE_SUCCESS=true
        log_message "INFO" "Homebrew upgrade completed (started: ${upgrade_start}, ended: ${upgrade_end})"

        # Log summary of packages upgraded
        local outdated_count
        outdated_count=$(brew outdated 2>/dev/null | wc -l | tr -d ' ')
        log_message "INFO" "Packages still outdated after upgrade: ${outdated_count}"

        return 0
    else
        log_message "ERROR" "Homebrew upgrade failed, continuing with Brewfile generation"
        return 1
    fi
}

#############################################
# Brewfile Functions
#############################################

generate_brewfile() {
    log_message "INFO" "Generating Brewfile..."

    # Create destination directory if it doesn't exist
    if [[ ! -d "${BREWFILE_DESTINATION}" ]]; then
        if mkdir -p "${BREWFILE_DESTINATION}"; then
            log_message "INFO" "Created destination directory: ${BREWFILE_DESTINATION}"
        else
            log_message "FATAL" "Failed to create destination directory: ${BREWFILE_DESTINATION}"
            exit 1
        fi
    fi

    # Generate Brewfile using brew bundle dump
    local brewfile_path="${BREWFILE_DESTINATION}/Brewfile"

    if brew bundle dump --file="${brewfile_path}" --force; then
        BREWFILE_GENERATED=true
        log_message "INFO" "Brewfile generated successfully: ${brewfile_path}"
        return 0
    else
        log_message "FATAL" "Failed to generate Brewfile"
        exit 1
    fi
}

#############################################
# Git Functions
#############################################

commit_to_git() {
    if [[ "${GIT_COMMIT_ENABLED}" != "true" ]]; then
        log_message "INFO" "Git commit disabled in configuration"
        return 0
    fi

    local brewfile_path="${BREWFILE_DESTINATION}/Brewfile"

    # Check if destination is a git repository
    if ! git -C "${BREWFILE_DESTINATION}" rev-parse --git-dir &>/dev/null; then
        log_message "WARN" "Destination directory is not a Git repository: ${BREWFILE_DESTINATION}"
        log_message "WARN" "Skipping Git commit"
        return 0
    fi

    log_message "INFO" "Checking for Brewfile changes..."

    # Check if Brewfile has changes
    if git -C "${BREWFILE_DESTINATION}" diff --quiet Brewfile 2>/dev/null && \
       git -C "${BREWFILE_DESTINATION}" diff --cached --quiet Brewfile 2>/dev/null; then
        log_message "INFO" "Brewfile has not changed, skipping Git commit"
        return 0
    fi

    # Stage and commit the Brewfile
    log_message "INFO" "Creating Git commit for Brewfile changes..."

    if git -C "${BREWFILE_DESTINATION}" add Brewfile; then
        local commit_timestamp
        commit_timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        local commit_message="Update Brewfile - ${commit_timestamp}

Automated update from homebrew-config script"

        if git -C "${BREWFILE_DESTINATION}" commit -m "${commit_message}"; then
            GIT_COMMIT_CREATED=true
            log_message "INFO" "Git commit created successfully"
            return 0
        else
            log_message "ERROR" "Failed to create Git commit, but continuing"
            return 1
        fi
    else
        log_message "ERROR" "Failed to stage Brewfile for commit, but continuing"
        return 1
    fi
}

#############################################
# Utility Functions
#############################################

show_help() {
    cat << EOF
Homebrew Configuration Automation Script v${SCRIPT_VERSION}

Manages Homebrew installation, upgrades, and Brewfile generation with Git integration.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -d, --destination DIR    Brewfile destination directory (default: ~/Config)
    -c, --config FILE        Configuration file path (default: ~/.config/homebrew-config/config.sh)
    -h, --help               Show this help message
    -v, --version            Show version information

EXAMPLES:
    # Run with default settings
    $(basename "$0")

    # Specify custom destination directory
    $(basename "$0") -d /path/to/config

    # Use custom configuration file
    $(basename "$0") -c /path/to/config.sh

CONFIGURATION:
    Configuration can be set via (in order of precedence):
    1. Command-line arguments
    2. Configuration file specified with -c
    3. Default configuration file (~/.config/homebrew-config/config.sh)
    4. Environment variables
    5. Built-in defaults

EXIT CODES:
    0    Success
    1    Critical failure (Homebrew installation or Brewfile generation failed)
    2    Configuration error
    3    Permission error

For more information, see the README.md file.
EOF
}

show_version() {
    echo "Homebrew Configuration Automation Script v${SCRIPT_VERSION}"
}

parse_arguments() {
    # Set default config file
    CONFIG_FILE="${DEFAULT_CONFIG_FILE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--destination)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --destination requires a value" >&2
                    exit 2
                fi
                BREWFILE_DESTINATION="$2"
                shift 2
                ;;
            -c|--config)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --config requires a value" >&2
                    exit 2
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                echo "Use --help to see available options" >&2
                exit 2
                ;;
        esac
    done
}

#############################################
# Main Function
#############################################

main() {
    # Record start time
    START_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Parse command-line arguments
    parse_arguments "$@"

    # Load configuration
    load_configuration

    # Setup logging
    setup_logging

    # Check and install Homebrew if needed
    if ! check_homebrew; then
        install_homebrew
    fi

    # Upgrade Homebrew (non-critical - continue on failure)
    upgrade_homebrew || true

    # Generate Brewfile (critical - exit on failure)
    generate_brewfile

    # Commit to Git if applicable (non-critical - continue on failure)
    commit_to_git || true

    # Rotate logs if needed
    rotate_logs

    # Log completion
    local end_time
    end_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    log_message "INFO" "========================================="
    log_message "INFO" "Execution completed successfully"
    log_message "INFO" "Ended at ${end_time}"
    log_message "INFO" "Homebrew installed: ${HOMEBREW_WAS_INSTALLED}"
    log_message "INFO" "Upgrade successful: ${UPGRADE_SUCCESS}"
    log_message "INFO" "Brewfile generated: ${BREWFILE_GENERATED}"
    log_message "INFO" "Git commit created: ${GIT_COMMIT_CREATED}"
    log_message "INFO" "========================================="

    exit 0
}

# Run main function with all arguments
main "$@"
