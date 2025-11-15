#!/usr/bin/env bash
#
# Homebrew Configuration Management Script
# Automates Homebrew installation, upgrades, and Brewfile generation
#
# Version: 1.0.0
#

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.0"

# Global variables for logging
LOG_FILE=""
LOG_DIR=""
MAX_LOG_SIZE=10485760  # 10MB default
MAX_LOG_FILES=5

# Global variables for configuration
BREWFILE_DESTINATION=""
GIT_COMMIT_ENABLED=true
SCHEDULE_PATTERN="daily"
CONFIG_FILE=""
GENERATE_PLIST=false
SCHEDULE_TIME="02:00"

#######################################
# Initialize logging system
# Creates log directory and sets up log file
# Globals:
#   LOG_DIR - Directory for log files
#   LOG_FILE - Path to active log file
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
setup_logging() {
    # Use provided LOG_DIR or default
    if [[ -z "${LOG_DIR}" ]]; then
        LOG_DIR="${HOME}/.local/share/homebrew-config/logs"
    fi
    
    # Create log directory if it doesn't exist
    if ! mkdir -p "${LOG_DIR}" 2>/dev/null; then
        echo "ERROR: Failed to create log directory: ${LOG_DIR}" >&2
        return 1
    fi
    
    # Set log file path
    LOG_FILE="${LOG_DIR}/homebrew-config.log"
    
    # Create log file if it doesn't exist
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}" 2>/dev/null || {
            echo "ERROR: Failed to create log file: ${LOG_FILE}" >&2
            return 1
        }
    fi
    
    # Log initialization
    log_message "INFO" "Logging initialized - Script version ${SCRIPT_VERSION}"
    
    return 0
}

#######################################
# Write a timestamped log message
# Formats message with ISO 8601 timestamp and log level
# Globals:
#   LOG_FILE - Path to active log file
# Arguments:
#   $1 - Log level (INFO|WARN|ERROR|FATAL)
#   $2 - Log message
# Returns:
#   0 on success
#######################################
log_message() {
    local level="$1"
    local message="$2"
    
    # Generate ISO 8601 timestamp with timezone
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S%z")
    
    # Format log entry
    local log_entry="[${timestamp}] [${level}] ${message}"
    
    # Write to log file if available, otherwise to stderr
    if [[ -n "${LOG_FILE}" && -f "${LOG_FILE}" ]]; then
        echo "${log_entry}" >> "${LOG_FILE}"
    else
        echo "${log_entry}" >&2
    fi
    
    # Also output ERROR and FATAL to stderr for immediate visibility
    if [[ "${level}" == "ERROR" || "${level}" == "FATAL" ]]; then
        echo "${log_entry}" >&2
    fi
    
    return 0
}

#######################################
# Rotate log files when size limit is exceeded
# Renames current log with timestamp and creates new log file
# Deletes oldest logs if count exceeds MAX_LOG_FILES
# Globals:
#   LOG_FILE - Path to active log file
#   LOG_DIR - Directory for log files
#   MAX_LOG_SIZE - Maximum log file size in bytes
#   MAX_LOG_FILES - Maximum number of rotated logs to keep
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
rotate_logs() {
    # Check if log file exists
    if [[ ! -f "${LOG_FILE}" ]]; then
        return 0
    fi
    
    # Get current log file size
    local log_size
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS stat command
        log_size=$(stat -f%z "${LOG_FILE}" 2>/dev/null || echo "0")
    else
        # Linux stat command
        log_size=$(stat -c%s "${LOG_FILE}" 2>/dev/null || echo "0")
    fi
    
    # Check if rotation is needed
    if [[ ${log_size} -lt ${MAX_LOG_SIZE} ]]; then
        return 0
    fi
    
    # Generate timestamp for rotated log filename
    local timestamp
    timestamp=$(date -u +"%Y%m%d-%H%M%S")
    
    # Rotate the log file
    local rotated_log="${LOG_DIR}/homebrew-config-${timestamp}.log"
    if ! mv "${LOG_FILE}" "${rotated_log}" 2>/dev/null; then
        echo "WARN: Failed to rotate log file" >&2
        return 1
    fi
    
    # Create new log file
    touch "${LOG_FILE}" 2>/dev/null || {
        echo "ERROR: Failed to create new log file after rotation" >&2
        return 1
    }
    
    log_message "INFO" "Log rotated to: ${rotated_log}"
    
    # Clean up old log files
    cleanup_old_logs
    
    return 0
}

#######################################
# Delete oldest rotated log files exceeding MAX_LOG_FILES
# Keeps only the most recent rotated logs
# Globals:
#   LOG_DIR - Directory for log files
#   MAX_LOG_FILES - Maximum number of rotated logs to keep
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
cleanup_old_logs() {
    # Find all rotated log files, sorted by modification time (oldest first)
    local rotated_logs
    rotated_logs=$(find "${LOG_DIR}" -name "homebrew-config-*.log" -type f 2>/dev/null | sort)
    
    # Count rotated logs
    local log_count
    log_count=$(echo "${rotated_logs}" | grep -c "homebrew-config-" || echo "0")
    
    # Calculate how many logs to delete
    local logs_to_delete=$((log_count - MAX_LOG_FILES))
    
    # Delete oldest logs if we exceed the limit
    if [[ ${logs_to_delete} -gt 0 ]]; then
        echo "${rotated_logs}" | head -n "${logs_to_delete}" | while IFS= read -r old_log; do
            if [[ -f "${old_log}" ]]; then
                rm -f "${old_log}" 2>/dev/null || {
                    log_message "WARN" "Failed to delete old log: ${old_log}"
                }
                log_message "INFO" "Deleted old log: ${old_log}"
            fi
        done
    fi
    
    return 0
}

#######################################
# Expand tilde and environment variables in path
# Converts ~/ to $HOME/ and expands environment variables
# Arguments:
#   $1 - Path to expand
# Outputs:
#   Expanded path to stdout
# Returns:
#   0 on success
#######################################
expand_path() {
    local path="$1"
    
    # Expand tilde to HOME
    if [[ "${path}" =~ ^~(/|$) ]]; then
        path="${HOME}${path#\~}"
    fi
    
    # Expand environment variables
    eval echo "${path}"
}

#######################################
# Load configuration from file
# Reads configuration file and sets global variables
# Falls back to defaults if file doesn't exist or values not set
# Globals:
#   CONFIG_FILE - Path to configuration file
#   BREWFILE_DESTINATION - Brewfile destination directory
#   LOG_DIR - Log directory
#   MAX_LOG_SIZE - Maximum log file size
#   MAX_LOG_FILES - Maximum rotated logs to keep
#   GIT_COMMIT_ENABLED - Whether to create Git commits
#   SCHEDULE_PATTERN - Schedule pattern for launchd
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
load_configuration() {
    # Set default configuration file if not specified
    if [[ -z "${CONFIG_FILE}" ]]; then
        CONFIG_FILE="${HOME}/.config/homebrew-config/config.sh"
    fi
    
    # Load configuration file if it exists
    if [[ -f "${CONFIG_FILE}" ]]; then
        # Source the configuration file
        # shellcheck disable=SC1090
        source "${CONFIG_FILE}"
        log_message "INFO" "Loaded configuration from: ${CONFIG_FILE}"
    else
        log_message "INFO" "Configuration file not found, using defaults: ${CONFIG_FILE}"
    fi
    
    # Set defaults for any unset variables
    if [[ -z "${BREWFILE_DESTINATION}" ]]; then
        BREWFILE_DESTINATION="${HOME}/Config"
    fi
    
    if [[ -z "${LOG_DIR}" ]]; then
        LOG_DIR="${HOME}/.local/share/homebrew-config/logs"
    fi
    
    if [[ -z "${MAX_LOG_SIZE}" ]]; then
        MAX_LOG_SIZE=10485760  # 10MB
    fi
    
    if [[ -z "${MAX_LOG_FILES}" ]]; then
        MAX_LOG_FILES=5
    fi
    
    if [[ -z "${GIT_COMMIT_ENABLED}" ]]; then
        GIT_COMMIT_ENABLED=true
    fi
    
    if [[ -z "${SCHEDULE_PATTERN}" ]]; then
        SCHEDULE_PATTERN="daily"
    fi
    
    # Expand paths
    BREWFILE_DESTINATION=$(expand_path "${BREWFILE_DESTINATION}")
    LOG_DIR=$(expand_path "${LOG_DIR}")
    if [[ -n "${CONFIG_FILE}" ]]; then
        CONFIG_FILE=$(expand_path "${CONFIG_FILE}")
    fi
    
    # Log configuration values
    log_message "INFO" "Configuration - Brewfile destination: ${BREWFILE_DESTINATION}"
    log_message "INFO" "Configuration - Log directory: ${LOG_DIR}"
    log_message "INFO" "Configuration - Max log size: ${MAX_LOG_SIZE} bytes"
    log_message "INFO" "Configuration - Max log files: ${MAX_LOG_FILES}"
    log_message "INFO" "Configuration - Git commit enabled: ${GIT_COMMIT_ENABLED}"
    log_message "INFO" "Configuration - Schedule pattern: ${SCHEDULE_PATTERN}"
    
    return 0
}

#######################################
# Validate configuration values
# Checks that required directories are writable
# Globals:
#   BREWFILE_DESTINATION - Brewfile destination directory
#   LOG_DIR - Log directory
# Arguments:
#   None
# Returns:
#   0 on success, 1 on validation failure
#######################################
validate_configuration() {
    local validation_failed=false
    
    # Validate Brewfile destination is writable
    if [[ -d "${BREWFILE_DESTINATION}" ]]; then
        if [[ ! -w "${BREWFILE_DESTINATION}" ]]; then
            log_message "ERROR" "Brewfile destination is not writable: ${BREWFILE_DESTINATION}"
            validation_failed=true
        fi
    else
        # Try to create the directory
        if ! mkdir -p "${BREWFILE_DESTINATION}" 2>/dev/null; then
            log_message "ERROR" "Cannot create Brewfile destination directory: ${BREWFILE_DESTINATION}"
            validation_failed=true
        else
            log_message "INFO" "Created Brewfile destination directory: ${BREWFILE_DESTINATION}"
        fi
    fi
    
    # Validate log directory is writable
    if [[ -d "${LOG_DIR}" ]]; then
        if [[ ! -w "${LOG_DIR}" ]]; then
            log_message "ERROR" "Log directory is not writable: ${LOG_DIR}"
            validation_failed=true
        fi
    fi
    
    if [[ "${validation_failed}" == true ]]; then
        return 1
    fi
    
    return 0
}

#######################################
# Display help message
# Shows usage information and available options
# Arguments:
#   None
# Outputs:
#   Help text to stdout
# Returns:
#   0 on success
#######################################
show_help() {
    cat << EOF
Homebrew Configuration Management Script v${SCRIPT_VERSION}

Automates Homebrew installation, upgrades, and Brewfile generation.

USAGE:
    brew-config.sh [OPTIONS]

OPTIONS:
    -d, --destination DIR    Brewfile destination directory
                            Default: ~/Config
    
    -s, --schedule PATTERN   Setup scheduled execution
                            Options: daily, weekly, or interval in seconds
                            Default: daily
    
    -c, --config FILE       Configuration file path
                            Default: ~/.config/homebrew-config/config.sh
    
    --generate-plist        Generate launchd plist file for scheduled execution
                            When used, the script generates the plist and exits
                            without performing normal operations
    
    --schedule-time HH:MM   Time for scheduled execution (24-hour format)
                            Used with --generate-plist
                            Default: 02:00
    
    -h, --help             Show this help message
    
    -v, --version          Show version information

EXAMPLES:
    # Run with default settings
    brew-config.sh
    
    # Specify custom Brewfile destination
    brew-config.sh --destination ~/Dotfiles
    
    # Use custom configuration file
    brew-config.sh --config ~/my-config.sh
    
    # Generate launchd plist for daily execution at 2:00 AM
    brew-config.sh --generate-plist
    
    # Generate launchd plist for daily execution at 3:30 AM
    brew-config.sh --generate-plist --schedule-time 03:30

CONFIGURATION:
    Configuration can be set via:
    1. Command-line arguments (highest priority)
    2. Configuration file specified with -c
    3. Default config file at ~/.config/homebrew-config/config.sh
    4. Built-in defaults (lowest priority)

LOGS:
    Logs are stored in: ~/.local/share/homebrew-config/logs/
    Log rotation occurs when files exceed 10MB
    Maximum of 5 rotated logs are kept

For more information, see the README.md file.
EOF
    return 0
}

#######################################
# Parse command-line arguments
# Processes CLI arguments and sets global variables
# Globals:
#   BREWFILE_DESTINATION - Brewfile destination directory
#   SCHEDULE_PATTERN - Schedule pattern for launchd
#   CONFIG_FILE - Configuration file path
#   GENERATE_PLIST - Whether to generate launchd plist
#   SCHEDULE_TIME - Time for scheduled execution (HH:MM)
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 on success, 2 on invalid arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--destination)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --destination requires a directory path" >&2
                    return 2
                fi
                BREWFILE_DESTINATION="$2"
                shift 2
                ;;
            -s|--schedule)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --schedule requires a pattern (daily|weekly|INTERVAL)" >&2
                    return 2
                fi
                SCHEDULE_PATTERN="$2"
                shift 2
                ;;
            -c|--config)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --config requires a file path" >&2
                    return 2
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --generate-plist)
                GENERATE_PLIST=true
                shift
                ;;
            --schedule-time)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --schedule-time requires a time in HH:MM format" >&2
                    return 2
                fi
                # Validate time format
                if [[ ! "$2" =~ ^([0-1][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
                    echo "ERROR: --schedule-time must be in HH:MM format (24-hour)" >&2
                    return 2
                fi
                SCHEDULE_TIME="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "Homebrew Configuration Management Script v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                return 2
                ;;
        esac
    done
    
    return 0
}

#######################################
# Check if Homebrew is installed
# Verifies if brew command is available in PATH
# Arguments:
#   None
# Returns:
#   0 if Homebrew is installed, 1 if not installed
#######################################
check_homebrew() {
    log_message "INFO" "Checking for Homebrew installation..."
    
    if command -v brew &> /dev/null; then
        local brew_version
        brew_version=$(brew --version | head -n 1)
        log_message "INFO" "Homebrew is installed: ${brew_version}"
        return 0
    else
        log_message "INFO" "Homebrew is not installed"
        return 1
    fi
}

#######################################
# Install Homebrew
# Downloads and installs Homebrew using the official installation script
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
install_homebrew() {
    log_message "INFO" "Starting Homebrew installation..."
    
    # Official Homebrew installation script URL
    local install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    
    # Download and execute installation script
    if /bin/bash -c "$(curl -fsSL ${install_url})"; then
        log_message "INFO" "Homebrew installation completed successfully"
        
        # On Apple Silicon Macs, Homebrew is installed to /opt/homebrew
        # Add it to PATH if not already present
        if [[ -d "/opt/homebrew/bin" ]] && [[ ":${PATH}:" != *":/opt/homebrew/bin:"* ]]; then
            export PATH="/opt/homebrew/bin:${PATH}"
            log_message "INFO" "Added /opt/homebrew/bin to PATH"
        fi
        
        # On Intel Macs, Homebrew is installed to /usr/local
        if [[ -d "/usr/local/bin" ]] && [[ ":${PATH}:" != *":/usr/local/bin:"* ]]; then
            export PATH="/usr/local/bin:${PATH}"
            log_message "INFO" "Added /usr/local/bin to PATH"
        fi
        
        # Verify installation
        if command -v brew &> /dev/null; then
            local brew_version
            brew_version=$(brew --version | head -n 1)
            log_message "INFO" "Verified Homebrew installation: ${brew_version}"
            return 0
        else
            log_message "FATAL" "Homebrew installation completed but brew command not found in PATH"
            return 1
        fi
    else
        log_message "FATAL" "Homebrew installation failed"
        return 1
    fi
}

#######################################
# Upgrade Homebrew and installed packages
# Runs brew upgrade to update all packages
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure (non-critical)
#######################################
upgrade_homebrew() {
    log_message "INFO" "Starting Homebrew upgrade..."
    
    local start_time
    start_time=$(date -u +"%Y-%m-%dT%H:%M:%S%z")
    log_message "INFO" "Upgrade started at: ${start_time}"
    
    # Run brew upgrade and capture output
    local upgrade_output
    local upgrade_status
    
    if upgrade_output=$(brew upgrade 2>&1); then
        upgrade_status=0
        log_message "INFO" "Homebrew upgrade completed successfully"
    else
        upgrade_status=1
        log_message "ERROR" "Homebrew upgrade failed with exit code: ${upgrade_status}"
    fi
    
    # Log completion time
    local end_time
    end_time=$(date -u +"%Y-%m-%dT%H:%M:%S%z")
    log_message "INFO" "Upgrade completed at: ${end_time}"
    
    # Parse and log upgrade summary
    if [[ ${upgrade_status} -eq 0 ]]; then
        # Check if any packages were upgraded
        if echo "${upgrade_output}" | grep -q "Already up-to-date"; then
            log_message "INFO" "All packages are already up-to-date"
        elif echo "${upgrade_output}" | grep -q "Upgrading"; then
            # Count upgraded packages
            local upgraded_count
            upgraded_count=$(echo "${upgrade_output}" | grep -c "Upgrading" || echo "0")
            log_message "INFO" "Upgraded ${upgraded_count} package(s)"
            
            # Log package names (first 10 to avoid excessive logging)
            echo "${upgrade_output}" | grep "Upgrading" | head -n 10 | while IFS= read -r line; do
                log_message "INFO" "  ${line}"
            done
        else
            log_message "INFO" "Upgrade completed with no changes"
        fi
    else
        # Log error details
        log_message "ERROR" "Upgrade output: ${upgrade_output}"
    fi
    
    return ${upgrade_status}
}

#######################################
# Generate Brewfile from current Homebrew configuration
# Creates a Brewfile listing all installed packages, casks, and taps
# Globals:
#   BREWFILE_DESTINATION - Directory where Brewfile will be saved
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure (critical)
#######################################
generate_brewfile() {
    log_message "INFO" "Generating Brewfile..."
    
    # Ensure destination directory exists
    if [[ ! -d "${BREWFILE_DESTINATION}" ]]; then
        log_message "INFO" "Creating Brewfile destination directory: ${BREWFILE_DESTINATION}"
        if ! mkdir -p "${BREWFILE_DESTINATION}" 2>/dev/null; then
            log_message "FATAL" "Failed to create destination directory: ${BREWFILE_DESTINATION}"
            return 1
        fi
    fi
    
    # Verify destination is writable
    if [[ ! -w "${BREWFILE_DESTINATION}" ]]; then
        log_message "FATAL" "Destination directory is not writable: ${BREWFILE_DESTINATION}"
        return 1
    fi
    
    # Generate Brewfile using brew bundle dump
    local brewfile_path="${BREWFILE_DESTINATION}/Brewfile"
    
    if brew bundle dump --file="${brewfile_path}" --force 2>&1 | while IFS= read -r line; do
        log_message "INFO" "  ${line}"
    done; then
        log_message "INFO" "Brewfile generated successfully: ${brewfile_path}"
        
        # Log file size and timestamp
        local file_size
        if [[ "$(uname)" == "Darwin" ]]; then
            file_size=$(stat -f%z "${brewfile_path}" 2>/dev/null || echo "unknown")
        else
            file_size=$(stat -c%s "${brewfile_path}" 2>/dev/null || echo "unknown")
        fi
        
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S%z")
        
        log_message "INFO" "Brewfile size: ${file_size} bytes"
        log_message "INFO" "Brewfile saved at: ${timestamp}"
        
        return 0
    else
        log_message "FATAL" "Failed to generate Brewfile"
        return 1
    fi
}

#######################################
# Check if directory is a Git repository
# Verifies if the destination directory is under Git version control
# Arguments:
#   $1 - Directory path to check
# Returns:
#   0 if it's a Git repository, 1 if not
#######################################
is_git_repository() {
    local dir="$1"
    
    if git -C "${dir}" rev-parse --git-dir &> /dev/null; then
        return 0
    else
        return 1
    fi
}

#######################################
# Generate launchd plist file for scheduled execution
# Creates a plist file in ~/Library/LaunchAgents for scheduling the script
# Globals:
#   SCHEDULE_TIME - Time for scheduled execution (HH:MM format)
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
generate_launchd_plist() {
    echo "Generating launchd plist file..."
    
    # Parse schedule time
    local hour minute
    if [[ "${SCHEDULE_TIME}" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        hour="${BASH_REMATCH[1]}"
        minute="${BASH_REMATCH[2]}"
        # Remove leading zeros for plist (XML doesn't like them)
        hour=$((10#${hour}))
        minute=$((10#${minute}))
    else
        echo "ERROR: Invalid schedule time format: ${SCHEDULE_TIME}" >&2
        return 1
    fi
    
    # Get the actual script path
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Expand to absolute path if it's a symlink
    if [[ -L "${script_path}" ]]; then
        script_path="$(readlink -f "${script_path}" 2>/dev/null || readlink "${script_path}")"
    fi
    
    # Plist destination
    local plist_dir="${HOME}/Library/LaunchAgents"
    local plist_file="${plist_dir}/com.homebrewconfig.automation.plist"
    
    # Create LaunchAgents directory if it doesn't exist
    if [[ ! -d "${plist_dir}" ]]; then
        echo "Creating LaunchAgents directory: ${plist_dir}"
        if ! mkdir -p "${plist_dir}" 2>/dev/null; then
            echo "ERROR: Failed to create LaunchAgents directory" >&2
            return 1
        fi
    fi
    
    # Log directory for launchd output
    local log_dir="${HOME}/.local/share/homebrew-config/logs"
    
    # Create log directory if it doesn't exist
    if [[ ! -d "${log_dir}" ]]; then
        mkdir -p "${log_dir}" 2>/dev/null || {
            echo "WARN: Failed to create log directory, using /tmp" >&2
            log_dir="/tmp"
        }
    fi
    
    # Generate plist content
    cat > "${plist_file}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>Homebrew Config Automation</string>
    <key>ProgramArguments</key>
    <array>
        <string>${script_path}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${hour}</integer>
        <key>Minute</key>
        <integer>${minute}</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${log_dir}/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${log_dir}/launchd-stderr.log</string>
</dict>
</plist>
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Plist file generated successfully: ${plist_file}"
        echo ""
        echo "Configuration:"
        echo "  Script path: ${script_path}"
        echo "  Schedule time: ${SCHEDULE_TIME} (${hour}:$(printf "%02d" ${minute}))"
        echo "  Stdout log: ${log_dir}/launchd-stdout.log"
        echo "  Stderr log: ${log_dir}/launchd-stderr.log"
        echo ""
        echo "To activate the scheduled execution, run:"
        echo "  launchctl load ${plist_file}"
        echo ""
        echo "To deactivate, run:"
        echo "  launchctl unload ${plist_file}"
        echo ""
        echo "To check status, run:"
        echo "  launchctl list | grep homebrew-config"
        return 0
    else
        echo "ERROR: Failed to generate plist file" >&2
        return 1
    fi
}

#######################################
# Commit Brewfile changes to Git
# Creates a Git commit if Brewfile has changes
# Globals:
#   BREWFILE_DESTINATION - Directory containing Brewfile
#   GIT_COMMIT_ENABLED - Whether Git commits are enabled
# Arguments:
#   None
# Returns:
#   0 on success or skip, 1 on failure (non-critical)
#######################################
commit_to_git() {
    # Check if Git commits are enabled
    if [[ "${GIT_COMMIT_ENABLED}" != "true" ]]; then
        log_message "INFO" "Git commits are disabled in configuration"
        return 0
    fi
    
    log_message "INFO" "Checking for Git repository..."
    
    # Check if destination is a Git repository
    if ! is_git_repository "${BREWFILE_DESTINATION}"; then
        log_message "WARN" "Destination is not a Git repository: ${BREWFILE_DESTINATION}"
        log_message "WARN" "Skipping Git commit"
        return 0
    fi
    
    log_message "INFO" "Git repository detected"
    
    # Check if Brewfile has changes
    if git -C "${BREWFILE_DESTINATION}" diff --quiet Brewfile 2>/dev/null; then
        log_message "INFO" "Brewfile has no changes, skipping commit"
        return 0
    fi
    
    log_message "INFO" "Brewfile has changes, creating commit..."
    
    # Stage the Brewfile
    if ! git -C "${BREWFILE_DESTINATION}" add Brewfile 2>&1 | while IFS= read -r line; do
        log_message "INFO" "  ${line}"
    done; then
        log_message "ERROR" "Failed to stage Brewfile"
        return 1
    fi
    
    # Create commit with timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local commit_message="Update Brewfile - ${timestamp}

Automated update from homebrew-config script"
    
    if git -C "${BREWFILE_DESTINATION}" commit -m "${commit_message}" 2>&1 | while IFS= read -r line; do
        log_message "INFO" "  ${line}"
    done; then
        log_message "INFO" "Git commit created successfully"
        
        # Get commit hash
        local commit_hash
        commit_hash=$(git -C "${BREWFILE_DESTINATION}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
        log_message "INFO" "Commit hash: ${commit_hash}"
        
        return 0
    else
        log_message "ERROR" "Failed to create Git commit"
        return 1
    fi
}

#######################################
# Main function - orchestrates all operations
# Entry point for the script
# Arguments:
#   $@ - Command-line arguments
# Returns:
#   0 on success, 1-3 on various failures
#######################################
main() {
    local exit_code=0
    local execution_mode="manual"
    
    # Detect if running from launchd (scheduled)
    if [[ -n "${LAUNCHED_BY_LAUNCHD:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
        execution_mode="scheduled"
    fi
    
    # Parse command-line arguments first (before logging setup)
    if ! parse_arguments "$@"; then
        exit 2
    fi
    
    # Check if we should generate plist and exit
    if [[ "${GENERATE_PLIST}" == "true" ]]; then
        if generate_launchd_plist; then
            exit 0
        else
            exit 1
        fi
    fi
    
    # Load configuration (sets LOG_DIR and other variables)
    load_configuration
    
    # Initialize logging
    if ! setup_logging; then
        echo "FATAL: Failed to initialize logging" >&2
        exit 1
    fi
    
    # Log script start
    log_message "INFO" "=========================================="
    log_message "INFO" "Homebrew Configuration Script v${SCRIPT_VERSION}"
    log_message "INFO" "Execution mode: ${execution_mode}"
    log_message "INFO" "=========================================="
    
    # Validate configuration
    if ! validate_configuration; then
        log_message "FATAL" "Configuration validation failed"
        exit 2
    fi
    
    # Check if macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_message "FATAL" "This script is designed for macOS only"
        exit 1
    fi
    
    # Check Homebrew installation
    if ! check_homebrew; then
        log_message "INFO" "Homebrew not found, installing..."
        if ! install_homebrew; then
            log_message "FATAL" "Failed to install Homebrew"
            exit 1
        fi
    else
        # Homebrew is installed, run upgrade
        log_message "INFO" "Homebrew is installed, running upgrade..."
        if ! upgrade_homebrew; then
            log_message "ERROR" "Homebrew upgrade failed, continuing with Brewfile generation"
            exit_code=1  # Non-critical, continue
        fi
    fi
    
    # Generate Brewfile
    if ! generate_brewfile; then
        log_message "FATAL" "Failed to generate Brewfile"
        exit 1
    fi
    
    # Commit to Git if enabled
    if ! commit_to_git; then
        log_message "ERROR" "Git commit failed, but Brewfile was generated successfully"
        # Non-critical, don't change exit code if it's 0
    fi
    
    # Rotate logs if needed
    rotate_logs || log_message "WARN" "Log rotation failed"
    
    # Log completion
    log_message "INFO" "=========================================="
    if [[ ${exit_code} -eq 0 ]]; then
        log_message "INFO" "Script completed successfully"
    else
        log_message "INFO" "Script completed with non-critical errors"
    fi
    log_message "INFO" "=========================================="
    
    exit ${exit_code}
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
