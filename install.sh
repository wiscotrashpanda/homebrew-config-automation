#!/usr/bin/env bash
#
# Homebrew Configuration Management - Installation Script
# Installs the brew-config.sh script and sets up the environment
#
# Version: 1.0.0
#

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.0"

# Default installation paths
DEFAULT_INSTALL_DIR="${HOME}/bin"
DEFAULT_CONFIG_DIR="${HOME}/.config/homebrew-config"

# Installation paths (can be overridden)
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
CONFIG_DIR="${DEFAULT_CONFIG_DIR}"
SCHEDULE_PATTERN=""

#######################################
# Display installation help message
# Arguments:
#   None
# Outputs:
#   Help text to stdout
#######################################
show_help() {
    cat << EOF
Homebrew Configuration Management - Installation Script v${SCRIPT_VERSION}

Installs brew-config.sh and sets up the environment.

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    -i, --install-dir DIR    Installation directory for script
                            Default: ~/bin
    
    -c, --config-dir DIR    Configuration directory
                            Default: ~/.config/homebrew-config
    
    -s, --schedule PATTERN  Setup scheduled execution
                            Options: daily, weekly, or interval in seconds
                            If not specified, no schedule is set up
    
    -h, --help             Show this help message

EXAMPLES:
    # Install with defaults
    ./install.sh
    
    # Install to custom directory
    ./install.sh --install-dir /usr/local/bin
    
    # Install with daily schedule
    ./install.sh --schedule daily

WHAT THIS SCRIPT DOES:
    1. Copies brew-config.sh to installation directory
    2. Creates configuration directory
    3. Copies config.sh.example to configuration directory
    4. Sets up scheduled execution (if requested)
    5. Verifies installation

EOF
}

#######################################
# Parse installation command-line arguments
# Globals:
#   INSTALL_DIR - Installation directory
#   CONFIG_DIR - Configuration directory
#   SCHEDULE_PATTERN - Schedule pattern
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 on success, 1 on error
#######################################
parse_install_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--install-dir)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --install-dir requires a directory path" >&2
                    return 1
                fi
                INSTALL_DIR="$2"
                shift 2
                ;;
            -c|--config-dir)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --config-dir requires a directory path" >&2
                    return 1
                fi
                CONFIG_DIR="$2"
                shift 2
                ;;
            -s|--schedule)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --schedule requires a pattern" >&2
                    return 1
                fi
                SCHEDULE_PATTERN="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
        esac
    done
    
    return 0
}

#######################################
# Install the brew-config.sh script
# Copies script to installation directory
# Globals:
#   INSTALL_DIR - Installation directory
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
install_script() {
    echo "Installing brew-config.sh..."
    
    # Expand tilde in paths
    INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
    
    # Create installation directory if it doesn't exist
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        echo "Creating installation directory: ${INSTALL_DIR}"
        if ! mkdir -p "${INSTALL_DIR}"; then
            echo "ERROR: Failed to create installation directory" >&2
            return 1
        fi
    fi
    
    # Check if brew-config.sh exists in current directory
    if [[ ! -f "brew-config.sh" ]]; then
        echo "ERROR: brew-config.sh not found in current directory" >&2
        return 1
    fi
    
    # Copy script to installation directory
    local dest_script="${INSTALL_DIR}/brew-config.sh"
    if ! cp brew-config.sh "${dest_script}"; then
        echo "ERROR: Failed to copy script to ${dest_script}" >&2
        return 1
    fi
    
    # Make script executable
    if ! chmod +x "${dest_script}"; then
        echo "ERROR: Failed to make script executable" >&2
        return 1
    fi
    
    echo "✓ Script installed to: ${dest_script}"
    return 0
}

#######################################
# Create configuration directory and files
# Copies config.sh.example to configuration directory
# Globals:
#   CONFIG_DIR - Configuration directory
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
create_config() {
    echo "Setting up configuration..."
    
    # Expand tilde in paths
    CONFIG_DIR="${CONFIG_DIR/#\~/$HOME}"
    
    # Create configuration directory
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        echo "Creating configuration directory: ${CONFIG_DIR}"
        if ! mkdir -p "${CONFIG_DIR}"; then
            echo "ERROR: Failed to create configuration directory" >&2
            return 1
        fi
    fi
    
    # Copy config.sh.example if it exists
    if [[ -f "config.sh.example" ]]; then
        local dest_config="${CONFIG_DIR}/config.sh.example"
        if ! cp config.sh.example "${dest_config}"; then
            echo "ERROR: Failed to copy config.sh.example" >&2
            return 1
        fi
        echo "✓ Configuration example copied to: ${dest_config}"
        
        # Create actual config file if it doesn't exist
        local config_file="${CONFIG_DIR}/config.sh"
        if [[ ! -f "${config_file}" ]]; then
            if cp config.sh.example "${config_file}"; then
                echo "✓ Configuration file created: ${config_file}"
                echo "  You can edit this file to customize settings"
            fi
        else
            echo "  Configuration file already exists: ${config_file}"
        fi
    else
        echo "WARNING: config.sh.example not found, skipping" >&2
    fi
    
    return 0
}


#######################################
# Verify installation was successful
# Checks that all files are in place and executable
# Globals:
#   INSTALL_DIR - Installation directory
#   CONFIG_DIR - Configuration directory
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
verify_installation() {
    echo "Verifying installation..."
    
    local verification_failed=false
    local script_path="${INSTALL_DIR}/brew-config.sh"
    
    # Check script exists
    if [[ ! -f "${script_path}" ]]; then
        echo "ERROR: Script not found at ${script_path}" >&2
        verification_failed=true
    fi
    
    # Check script is executable
    if [[ ! -x "${script_path}" ]]; then
        echo "ERROR: Script is not executable: ${script_path}" >&2
        verification_failed=true
    fi
    
    # Check configuration directory exists
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        echo "ERROR: Configuration directory not found: ${CONFIG_DIR}" >&2
        verification_failed=true
    fi
    
    # Check permissions
    if [[ ! -w "${INSTALL_DIR}" ]]; then
        echo "WARNING: Installation directory is not writable: ${INSTALL_DIR}" >&2
    fi
    
    if [[ "${verification_failed}" == true ]]; then
        return 1
    fi
    
    echo "✓ Installation verified successfully"
    return 0
}

#######################################
# Generate launchd plist file for scheduled execution
# Creates a plist file based on the schedule pattern
# Globals:
#   SCHEDULE_PATTERN - Schedule pattern (daily|weekly|interval)
#   INSTALL_DIR - Installation directory
# Arguments:
#   None
# Outputs:
#   Plist XML to stdout
# Returns:
#   0 on success
#######################################
generate_plist() {
    local script_path="${INSTALL_DIR}/brew-config.sh"
    local log_dir="${HOME}/.local/share/homebrew-config/logs"
    
    # Ensure log directory exists
    mkdir -p "${log_dir}" 2>/dev/null || true
    
    # Start plist
    cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.homebrew-config</string>
    <key>ProgramArguments</key>
    <array>
        <string>${script_path}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>LAUNCHED_BY_LAUNCHD</key>
        <string>1</string>
    </dict>
    <key>StandardOutPath</key>
    <string>${log_dir}/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${log_dir}/launchd-stderr.log</string>
EOF

    # Add schedule based on pattern
    case "${SCHEDULE_PATTERN}" in
        daily)
            cat << EOF
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
EOF
            ;;
        weekly)
            cat << EOF
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
EOF
            ;;
        [0-9]*)
            # Interval in seconds
            cat << EOF
    <key>StartInterval</key>
    <integer>${SCHEDULE_PATTERN}</integer>
EOF
            ;;
        *)
            echo "ERROR: Invalid schedule pattern: ${SCHEDULE_PATTERN}" >&2
            return 1
            ;;
    esac
    
    # Close plist
    cat << EOF
</dict>
</plist>
EOF
    
    return 0
}

#######################################
# Setup scheduled execution using launchd
# Creates and loads launchd plist file
# Globals:
#   SCHEDULE_PATTERN - Schedule pattern
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
setup_schedule() {
    echo "Setting up scheduled execution..."
    
    local plist_dir="${HOME}/Library/LaunchAgents"
    local plist_file="${plist_dir}/com.user.homebrew-config.plist"
    
    # Create LaunchAgents directory if it doesn't exist
    if [[ ! -d "${plist_dir}" ]]; then
        echo "Creating LaunchAgents directory: ${plist_dir}"
        if ! mkdir -p "${plist_dir}"; then
            echo "ERROR: Failed to create LaunchAgents directory" >&2
            return 1
        fi
    fi
    
    # Generate and save plist file
    if ! generate_plist > "${plist_file}"; then
        echo "ERROR: Failed to generate plist file" >&2
        return 1
    fi
    
    echo "✓ Plist file created: ${plist_file}"
    
    # Validate plist syntax
    if ! plutil -lint "${plist_file}" &> /dev/null; then
        echo "ERROR: Invalid plist syntax" >&2
        return 1
    fi
    
    echo "✓ Plist syntax validated"
    
    # Unload existing job if present
    launchctl unload "${plist_file}" 2>/dev/null || true
    
    # Load the plist
    if launchctl load "${plist_file}"; then
        echo "✓ Scheduled execution configured successfully"
        
        # Display schedule info
        case "${SCHEDULE_PATTERN}" in
            daily)
                echo "  Schedule: Daily at 2:00 AM"
                ;;
            weekly)
                echo "  Schedule: Weekly on Sunday at 2:00 AM"
                ;;
            [0-9]*)
                echo "  Schedule: Every ${SCHEDULE_PATTERN} seconds"
                ;;
        esac
        
        return 0
    else
        echo "ERROR: Failed to load launchd job" >&2
        return 1
    fi
}

#######################################
# Main installation function
# Orchestrates the installation process
# Arguments:
#   $@ - Command-line arguments
# Returns:
#   0 on success, 1 on failure
#######################################
main() {
    echo "=========================================="
    echo "Homebrew Configuration Management"
    echo "Installation Script v${SCRIPT_VERSION}"
    echo "=========================================="
    echo
    
    # Parse arguments
    if ! parse_install_arguments "$@"; then
        exit 1
    fi
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "ERROR: This script is designed for macOS only" >&2
        exit 1
    fi
    
    # Install script
    if ! install_script; then
        echo "ERROR: Script installation failed" >&2
        exit 1
    fi
    
    # Create configuration
    if ! create_config; then
        echo "ERROR: Configuration setup failed" >&2
        exit 1
    fi
    
    # Verify installation
    if ! verify_installation; then
        echo "ERROR: Installation verification failed" >&2
        exit 1
    fi
    
    # Setup schedule if requested
    if [[ -n "${SCHEDULE_PATTERN}" ]]; then
        echo
        if ! setup_schedule; then
            echo "WARNING: Scheduled execution setup failed" >&2
            echo "You can still run the script manually: ${INSTALL_DIR}/brew-config.sh"
        fi
    fi
    
    # Display installation summary
    echo
    echo "=========================================="
    echo "Installation Complete!"
    echo "=========================================="
    echo
    echo "Installed files:"
    echo "  Script:        ${INSTALL_DIR}/brew-config.sh"
    echo "  Configuration: ${CONFIG_DIR}/config.sh"
    echo "  Example:       ${CONFIG_DIR}/config.sh.example"
    echo
    echo "Next steps:"
    echo "  1. Edit configuration: ${CONFIG_DIR}/config.sh"
    echo "  2. Run the script: ${INSTALL_DIR}/brew-config.sh"
    echo "  3. Add ${INSTALL_DIR} to your PATH if not already present"
    echo
    echo "For help: ${INSTALL_DIR}/brew-config.sh --help"
    echo
    
    return 0
}

# Run main function
main "$@"
