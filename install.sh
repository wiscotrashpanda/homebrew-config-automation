#!/bin/bash
#
# Installation Script for Homebrew Configuration Automation
# Deploys the script, application bundle, and generates launchd plist
#

set -e  # Exit on error
set -u  # Exit on undefined variable

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"

# Default installation locations
DEFAULT_SCRIPT_DIR="${HOME}/bin"
DEFAULT_APP_DIR="${HOME}/Applications"
DEFAULT_CONFIG_DIR="${HOME}/.config/homebrew-config"
DEFAULT_PLIST_DIR="${HOME}/Library/LaunchAgents"

# Installation variables
SCRIPT_DIR=""
APP_DIR=""
CONFIG_DIR=""
PLIST_DIR=""
SCHEDULE_HOUR=2
SCHEDULE_MINUTE=0

# Script information
readonly SCRIPT_NAME="brew-config.sh"
readonly APP_NAME="Homebrew Config Automation.app"
readonly PLIST_NAME="com.emkaytec.homebrewconfig.plist"
readonly CONFIG_EXAMPLE="config.sh.example"

# Validation Functions
#############################################

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check for macOS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_error "This script is designed for macOS only"
        exit 1
    fi

    # Check for required files
    if [[ ! -f "${SCRIPT_NAME}" ]]; then
        print_error "Script not found: ${SCRIPT_NAME}"
        print_error "Please run this installer from the repository directory"
        exit 1
    fi

    if [[ ! -d "${APP_NAME}" ]]; then
        print_error "Application bundle not found: ${APP_NAME}"
        print_error "Please run this installer from the repository directory"
        exit 1
    fi

    if [[ ! -f "${CONFIG_EXAMPLE}" ]]; then
        print_warning "Configuration example not found: ${CONFIG_EXAMPLE}"
        print_warning "Configuration example will not be installed"
    fi

    print_success "Prerequisites check passed"
}

#############################################
# Installation Functions
#############################################

install_script() {
    print_info "Installing script to ${SCRIPT_DIR}..."

    # Create script directory if it doesn't exist
    if [[ ! -d "${SCRIPT_DIR}" ]]; then
        mkdir -p "${SCRIPT_DIR}"
        print_info "Created directory: ${SCRIPT_DIR}"
    fi

    # Copy script
    if cp "${SCRIPT_NAME}" "${SCRIPT_DIR}/${SCRIPT_NAME}"; then
        chmod +x "${SCRIPT_DIR}/${SCRIPT_NAME}"
        print_success "Script installed: ${SCRIPT_DIR}/${SCRIPT_NAME}"
    else
        print_error "Failed to install script"
        exit 1
    fi

    # Add to PATH if not already there
    if [[ ":${PATH}:" != *":${SCRIPT_DIR}:"* ]]; then
        print_warning "Note: ${SCRIPT_DIR} is not in your PATH"
        print_info "Add the following line to your ~/.zshrc or ~/.bash_profile:"
        echo ""
        echo "    export PATH=\"${SCRIPT_DIR}:\$PATH\""
        echo ""
    fi
}

deploy_app_bundle() {
    print_info "Deploying application bundle to ${APP_DIR}..."

    # Create applications directory if it doesn't exist
    if [[ ! -d "${APP_DIR}" ]]; then
        mkdir -p "${APP_DIR}"
        print_info "Created directory: ${APP_DIR}"
    fi

    # Remove existing app bundle if present
    if [[ -d "${APP_DIR}/${APP_NAME}" ]]; then
        print_info "Removing existing application bundle..."
        rm -rf "${APP_DIR}/${APP_NAME}"
    fi

    # Copy application bundle
    if cp -R "${APP_NAME}" "${APP_DIR}/"; then
        print_success "Application bundle deployed: ${APP_DIR}/${APP_NAME}"
    else
        print_error "Failed to deploy application bundle"
        exit 1
    fi
}

create_config() {
    print_info "Setting up configuration..."

    # Create config directory if it doesn't exist
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}"
        print_info "Created directory: ${CONFIG_DIR}"
    fi

    # Copy example configuration if it exists and user config doesn't
    local config_file="${CONFIG_DIR}/config.sh"
    if [[ -f "${CONFIG_EXAMPLE}" && ! -f "${config_file}" ]]; then
        if cp "${CONFIG_EXAMPLE}" "${config_file}"; then
            chmod 600 "${config_file}"
            print_success "Configuration file created: ${config_file}"
            print_info "Edit this file to customize your settings"
        else
            print_warning "Failed to create configuration file"
        fi
    elif [[ -f "${config_file}" ]]; then
        print_info "Configuration file already exists: ${config_file}"
    else
        print_warning "No configuration example to copy"
    fi
}

generate_plist() {
    print_info "Generating launchd plist..."

    # Create LaunchAgents directory if it doesn't exist
    if [[ ! -d "${PLIST_DIR}" ]]; then
        mkdir -p "${PLIST_DIR}"
        print_info "Created directory: ${PLIST_DIR}"
    fi

    local plist_path="${PLIST_DIR}/${PLIST_NAME}"
    local app_executable="${APP_DIR}/${APP_NAME}/Contents/MacOS/Homebrew Config Automation"
    local log_dir="${HOME}/.local/share/homebrew-config/logs"

    # Create log directory
    mkdir -p "${log_dir}"

    # Generate plist content
    cat > "${plist_path}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.emkaytec.homebrewconfig</string>
	<key>ProgramArguments</key>
	<array>
		<string>${app_executable}</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>${SCHEDULE_HOUR}</integer>
		<key>Minute</key>
		<integer>${SCHEDULE_MINUTE}</integer>
	</dict>
	<key>StandardOutPath</key>
	<string>${log_dir}/launchd-stdout.log</string>
	<key>StandardErrorPath</key>
	<string>${log_dir}/launchd-stderr.log</string>
	<key>RunAtLoad</key>
	<false/>
</dict>
</plist>
EOF

    if [[ $? -eq 0 ]]; then
        chmod 644 "${plist_path}"
        print_success "Launchd plist created: ${plist_path}"
    else
        print_error "Failed to generate launchd plist"
        exit 1
    fi
}

verify_installation() {
    print_info "Verifying installation..."

    local all_good=true

    # Check script
    if [[ -x "${SCRIPT_DIR}/${SCRIPT_NAME}" ]]; then
        print_success "Script verified: ${SCRIPT_DIR}/${SCRIPT_NAME}"
    else
        print_error "Script verification failed"
        all_good=false
    fi

    # Check app bundle
    if [[ -d "${APP_DIR}/${APP_NAME}" ]]; then
        print_success "App bundle verified: ${APP_DIR}/${APP_NAME}"
    else
        print_error "App bundle verification failed"
        all_good=false
    fi

    # Check plist
    if [[ -f "${PLIST_DIR}/${PLIST_NAME}" ]]; then
        print_success "Plist verified: ${PLIST_DIR}/${PLIST_NAME}"
    else
        print_error "Plist verification failed"
        all_good=false
    fi

    if [[ "${all_good}" == "true" ]]; then
        print_success "All components verified successfully"
        return 0
    else
        print_error "Installation verification failed"
        return 1
    fi
}

#############################################
# Usage and Help Functions
#############################################

show_help() {
    cat << EOF
Homebrew Configuration Automation - Installation Script

Installs the brew-config.sh script, application bundle, and generates
the launchd plist for scheduled execution.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --script-dir DIR       Script installation directory (default: ~/bin)
    --app-dir DIR          Application bundle directory (default: ~/Applications)
    --config-dir DIR       Configuration directory (default: ~/.config/homebrew-config)
    --plist-dir DIR        LaunchAgent plist directory (default: ~/Library/LaunchAgents)
    --schedule-hour HOUR   Schedule hour (0-23, default: 2)
    --schedule-minute MIN  Schedule minute (0-59, default: 0)
    -h, --help             Show this help message

EXAMPLES:
    # Install with default settings
    $(basename "$0")

    # Install to custom locations
    $(basename "$0") --script-dir /usr/local/bin --app-dir /Applications

    # Set custom schedule (daily at 3:30 AM)
    $(basename "$0") --schedule-hour 3 --schedule-minute 30

INSTALLATION LOCATIONS:
    Script:     ~/bin/brew-config.sh
    App Bundle: ~/Applications/Homebrew Config Automation.app
    Plist:      ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
    Config:     ~/.config/homebrew-config/config.sh

After installation, load the scheduled job with:
    launchctl load ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
EOF
}

parse_arguments() {
    # Set defaults
    SCRIPT_DIR="${DEFAULT_SCRIPT_DIR}"
    APP_DIR="${DEFAULT_APP_DIR}"
    CONFIG_DIR="${DEFAULT_CONFIG_DIR}"
    PLIST_DIR="${DEFAULT_PLIST_DIR}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --script-dir)
                require_argument "--script-dir" "${2:-}"
                SCRIPT_DIR="$(expand_path "$2")"
                shift 2
                ;;
            --app-dir)
                require_argument "--app-dir" "${2:-}"
                APP_DIR="$(expand_path "$2")"
                shift 2
                ;;
            --config-dir)
                require_argument "--config-dir" "${2:-}"
                CONFIG_DIR="$(expand_path "$2")"
                shift 2
                ;;
            --plist-dir)
                require_argument "--plist-dir" "${2:-}"
                PLIST_DIR="$(expand_path "$2")"
                shift 2
                ;;
            --schedule-hour)
                require_argument "--schedule-hour" "${2:-}"
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 0 ]] || [[ "$2" -gt 23 ]]; then
                    print_error "--schedule-hour must be between 0 and 23"
                    exit 2
                fi
                SCHEDULE_HOUR="$2"
                shift 2
                ;;
            --schedule-minute)
                require_argument "--schedule-minute" "${2:-}"
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 0 ]] || [[ "$2" -gt 59 ]]; then
                    print_error "--schedule-minute must be between 0 and 59"
                    exit 2
                fi
                SCHEDULE_MINUTE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help to see available options"
                exit 2
                ;;
        esac
    done
}

#############################################
# Main Function
#############################################

main() {
    print_header "Homebrew Config Automation - Installer"

    # Parse arguments
    parse_arguments "$@"

    # Check prerequisites
    check_prerequisites

    # Install components
    install_script
    deploy_app_bundle
    create_config
    generate_plist

    # Verify installation
    if verify_installation; then
        print_header "Installation Complete!"

        echo "Installation Summary:"
        echo "  Script:     ${SCRIPT_DIR}/${SCRIPT_NAME}"
        echo "  App Bundle: ${APP_DIR}/${APP_NAME}"
        echo "  Plist:      ${PLIST_DIR}/${PLIST_NAME}"
        echo "  Config:     ${CONFIG_DIR}/config.sh"
        echo "  Schedule:   Daily at $(printf "%02d:%02d" ${SCHEDULE_HOUR} ${SCHEDULE_MINUTE})"
        echo ""
        echo "Next Steps:"
        echo ""
        echo "1. (Optional) Edit configuration:"
        echo "   \$ nano ${CONFIG_DIR}/config.sh"
        echo ""
        echo "2. Test manual execution:"
        echo "   \$ ${SCRIPT_DIR}/${SCRIPT_NAME}"
        echo ""
        echo "3. Load the scheduled job:"
        echo "   \$ launchctl load ${PLIST_DIR}/${PLIST_NAME}"
        echo ""
        echo "4. Check job status:"
        echo "   \$ launchctl list | grep com.emkaytec.homebrewconfig"
        echo ""
        echo "5. View logs:"
        echo "   \$ tail -f ~/.local/share/homebrew-config/logs/homebrew-config.log"
        echo ""
        print_success "Setup complete!"
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

# Run main function
main "$@"
