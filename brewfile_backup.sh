#!/bin/bash

################################################################################
# Brewfile Backup Script
################################################################################
#
# Description:
#   Automatically backs up your Homebrew package configuration (Brewfile) to
#   a private GitHub Gist. The script generates a Brewfile from your current
#   Homebrew installation, detects changes, and uploads only when changes are
#   detected.
#
# Features:
#   - Automatic Brewfile generation via `brew bundle dump`
#   - Change detection using SHA-256 hashing (skips upload if unchanged)
#   - GitHub Gist integration via GitHub CLI (gh)
#   - Persistent configuration storage
#   - Comprehensive logging
#
# Requirements:
#   - Homebrew (brew command)
#   - GitHub CLI (gh command, authenticated)
#   - jq (JSON processor)
#
# Usage:
#   ./brewfile_backup.sh           # Normal execution
#   ./brewfile_backup.sh --force   # Force upload even if unchanged
#   ./brewfile_backup.sh --dry-run # Generate Brewfile but don't upload
#   ./brewfile_backup.sh --help    # Show help message
#
# Exit Codes:
#   0  - Success (including no changes detected)
#   1  - Authentication error (gh not installed/authenticated)
#   2  - Homebrew error (brew not available or dump failed)
#   3  - GitHub API error (gist creation/update failed)
#   4  - Configuration error
#   99 - Unexpected error
#
# Author: Homebrew Backup System
# Version: 1.0.0
#
################################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

################################################################################
# CONFIGURATION
################################################################################

# Configuration directory and files
CONFIG_DIR="$HOME/.config/brewfile-backup"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_FILE="$CONFIG_DIR/backup.log"
BREWFILE_PATH="$CONFIG_DIR/Brewfile"

# Script options (set via command-line arguments)
FORCE=false
DRY_RUN=false

# Global variables (populated during execution)
BREWFILE_HASH=""
BREWFILE_CONTENT=""
GIST_ID=""
GIST_URL=""

################################################################################
# LOGGING FUNCTIONS
################################################################################

# log_message: Core logging function
#
# Writes a timestamped log message to both the log file and stdout.
# This ensures logs are captured by launchd and also stored for reference.
#
# Arguments:
#   $1 - Log level (INFO, WARN, ERROR)
#   $2 - Log message
#
# Example:
#   log_message "INFO" "Starting backup process"
#
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local log_line="$timestamp - $level - $message"

    # Append to log file if directory exists (create file if doesn't exist)
    if [[ -d "$(dirname "$LOG_FILE")" ]]; then
        echo "$log_line" >> "$LOG_FILE"
    fi

    # Also output to stdout for launchd
    echo "$log_line"
}

# log_info: Log informational messages
#
# Use for normal operation messages like "Starting backup", "Backup completed"
#
# Arguments:
#   $1 - Message to log
#
log_info() {
    log_message "INFO" "$1"
}

# log_warn: Log warning messages
#
# Use for recoverable issues like "Previous Gist not found, creating new one"
#
# Arguments:
#   $1 - Message to log
#
log_warn() {
    log_message "WARN" "$1"
}

# log_error: Log error messages
#
# Use for failures and errors that prevent normal operation
#
# Arguments:
#   $1 - Message to log
#
log_error() {
    log_message "ERROR" "$1"
}

################################################################################
# HELPER FUNCTIONS
################################################################################

# show_help: Display usage information
#
# Prints the help message with usage examples and available options
#
show_help() {
    cat << EOF
Brewfile Backup Script

Backs up your Homebrew configuration to a private GitHub Gist.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force     Force upload even if Brewfile hasn't changed
    --dry-run   Generate Brewfile but skip upload to Gist
    --help      Show this help message

EXAMPLES:
    $0                  # Normal backup (skip if unchanged)
    $0 --force          # Force upload regardless of changes
    $0 --dry-run        # Test Brewfile generation only

REQUIREMENTS:
    - Homebrew (brew)
    - GitHub CLI (gh) - must be authenticated
    - jq (JSON processor)

SETUP:
    1. Install GitHub CLI: brew install gh
    2. Authenticate: gh auth login
    3. Install jq: brew install jq
    4. Run this script: $0

CONFIGURATION:
    Config directory: $CONFIG_DIR
    Log file: $LOG_FILE

For more information, see the README.md file.
EOF
}

################################################################################
# DEPENDENCY CHECKING
################################################################################

# check_dependencies: Verify all required tools are installed and configured
#
# Checks for the following dependencies:
#   1. GitHub CLI (gh) - must be installed and authenticated
#   2. Homebrew (brew) - must be installed
#   3. jq - JSON processor for config file manipulation
#
# This function exits the script with an appropriate error code if any
# dependency is missing or not properly configured.
#
# Exit codes:
#   1 - GitHub CLI not installed or not authenticated
#   2 - Homebrew not installed
#   4 - jq not installed (configuration error)
#
check_dependencies() {
    log_info "Checking dependencies..."

    # Check if GitHub CLI is installed
    if ! command -v gh &>/dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_error "Install with: brew install gh"
        log_error "Then authenticate with: gh auth login"
        exit 1
    fi

    # Check if GitHub CLI is authenticated
    # The 'gh auth status' command returns 0 if authenticated, non-zero otherwise
    if ! gh auth status &>/dev/null; then
        log_error "GitHub CLI is not authenticated"
        log_error "Please run: gh auth login"
        log_error "Make sure to grant the 'gist' scope during authentication"
        exit 1
    fi

    log_info "✓ GitHub CLI is installed and authenticated"

    # Check if Homebrew is installed
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew is not installed"
        log_error "Visit https://brew.sh for installation instructions"
        exit 2
    fi

    log_info "✓ Homebrew is installed"

    # Check if jq is installed
    if ! command -v jq &>/dev/null; then
        log_error "jq (JSON processor) is not installed"
        log_error "Install with: brew install jq"
        exit 4
    fi

    log_info "✓ jq is installed"

    log_info "All dependencies satisfied"
}

################################################################################
# INITIALIZATION
################################################################################

# init_config: Initialize configuration directory and files
#
# Creates the config directory if it doesn't exist and initializes
# an empty config file. This function is idempotent and safe to call
# multiple times.
#
# The config directory structure:
#   ~/.config/brewfile-backup/
#   ├── config.json    - Persistent state (Gist ID, last hash, etc.)
#   ├── backup.log     - Execution log
#   └── Brewfile       - Generated Brewfile (cached)
#
# Exits with code 4 if directory creation fails
#
init_config() {
    log_info "Initializing configuration..."

    # Create config directory with appropriate permissions
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
        log_error "Failed to create config directory: $CONFIG_DIR"
        exit 4
    fi

    # Initialize empty config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '{}' > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"  # Restrict to owner only
        log_info "Created new config file: $CONFIG_FILE"
    fi

    # Ensure log file exists
    touch "$LOG_FILE"

    log_info "Configuration initialized successfully"
}

################################################################################
# MAIN SCRIPT
################################################################################

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Initialize configuration
init_config

log_info "========================================="
log_info "Brewfile Backup Script v1.0.0"
log_info "========================================="

# Check dependencies
check_dependencies

# The main implementation will be added in subsequent tasks
log_info "Script skeleton initialized successfully"
log_info "Ready for core functionality implementation"

exit 0
