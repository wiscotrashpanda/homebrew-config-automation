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
