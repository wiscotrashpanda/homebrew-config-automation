#!/bin/bash
#
# Uninstallation Script for Homebrew Configuration Automation
# Removes the automation application while preserving Brewfiles
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
DEFAULT_LOG_DIR="${HOME}/.local/share/homebrew-config"

# Uninstallation variables
SCRIPT_DIR="${DEFAULT_SCRIPT_DIR}"
APP_DIR="${DEFAULT_APP_DIR}"
CONFIG_DIR="${DEFAULT_CONFIG_DIR}"
PLIST_DIR="${DEFAULT_PLIST_DIR}"
LOG_DIR="${DEFAULT_LOG_DIR}"

# Script information
readonly SCRIPT_NAME="brew-config.sh"
readonly APP_NAME="Homebrew Config Automation.app"
readonly PLIST_NAME="com.emkaytec.homebrewconfig.plist"

# Options
KEEP_CONFIG=false
KEEP_LOGS=false
DRY_RUN=false
FORCE=false

# Detection Functions
#############################################

check_component() {
    local component_path="$1"
    local component_name="$2"

    if [[ -e "${component_path}" ]]; then
        print_info "Found: ${component_name}"
        return 0
    else
        print_warning "Not found: ${component_name}"
        return 1
    fi
}

detect_installation() {
    print_header "Detecting Installation"

    local found_any=false

    # Check script
    if check_component "${SCRIPT_DIR}/${SCRIPT_NAME}" "Script"; then
        found_any=true
    fi

    # Check app bundle
    if check_component "${APP_DIR}/${APP_NAME}" "App Bundle"; then
        found_any=true
    fi

    # Check plist
    if check_component "${PLIST_DIR}/${PLIST_NAME}" "Launchd Plist"; then
        found_any=true
    fi

    # Check config
    if check_component "${CONFIG_DIR}" "Configuration Directory"; then
        found_any=true
    fi

    # Check logs
    if check_component "${LOG_DIR}" "Log Directory"; then
        found_any=true
    fi

    echo ""

    if [[ "${found_any}" == "false" ]]; then
        print_warning "No installation components found"
        return 1
    fi

    return 0
}

#############################################
# Uninstallation Functions
#############################################

unload_launchd_job() {
    local plist_path="${PLIST_DIR}/${PLIST_NAME}"

    if [[ ! -f "${plist_path}" ]]; then
        print_info "Launchd plist not found, skipping unload"
        return 0
    fi

    # Check if job is loaded
    if launchctl list | grep -q "com.emkaytec.homebrewconfig"; then
        print_info "Unloading launchd job..."

        if [[ "${DRY_RUN}" == "true" ]]; then
            print_info "[DRY RUN] Would unload: ${plist_path}"
        else
            if launchctl unload "${plist_path}" 2>/dev/null; then
                print_success "Launchd job unloaded"
            else
                print_warning "Failed to unload launchd job (may not be loaded)"
            fi
        fi
    else
        print_info "Launchd job is not loaded"
    fi
}

remove_script() {
    local script_path="${SCRIPT_DIR}/${SCRIPT_NAME}"

    if [[ ! -f "${script_path}" ]]; then
        print_info "Script not found, skipping removal"
        return 0
    fi

    print_info "Removing script..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would remove: ${script_path}"
    else
        if rm -f "${script_path}"; then
            print_success "Script removed: ${script_path}"
        else
            print_error "Failed to remove script: ${script_path}"
            return 1
        fi
    fi
}

remove_app_bundle() {
    local app_path="${APP_DIR}/${APP_NAME}"

    if [[ ! -d "${app_path}" ]]; then
        print_info "App bundle not found, skipping removal"
        return 0
    fi

    print_info "Removing app bundle..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would remove: ${app_path}"
    else
        if rm -rf "${app_path}"; then
            print_success "App bundle removed: ${app_path}"
        else
            print_error "Failed to remove app bundle: ${app_path}"
            return 1
        fi
    fi
}

remove_plist() {
    local plist_path="${PLIST_DIR}/${PLIST_NAME}"

    if [[ ! -f "${plist_path}" ]]; then
        print_info "Plist not found, skipping removal"
        return 0
    fi

    print_info "Removing launchd plist..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would remove: ${plist_path}"
    else
        if rm -f "${plist_path}"; then
            print_success "Launchd plist removed: ${plist_path}"
        else
            print_error "Failed to remove plist: ${plist_path}"
            return 1
        fi
    fi
}

remove_config() {
    if [[ "${KEEP_CONFIG}" == "true" ]]; then
        print_info "Keeping configuration directory (--keep-config specified)"
        return 0
    fi

    if [[ ! -d "${CONFIG_DIR}" ]]; then
        print_info "Configuration directory not found, skipping removal"
        return 0
    fi

    print_info "Removing configuration directory..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would remove: ${CONFIG_DIR}"
    else
        if rm -rf "${CONFIG_DIR}"; then
            print_success "Configuration removed: ${CONFIG_DIR}"
        else
            print_error "Failed to remove configuration: ${CONFIG_DIR}"
            return 1
        fi
    fi
}

remove_logs() {
    if [[ "${KEEP_LOGS}" == "true" ]]; then
        print_info "Keeping log directory (--keep-logs specified)"
        return 0
    fi

    if [[ ! -d "${LOG_DIR}" ]]; then
        print_info "Log directory not found, skipping removal"
        return 0
    fi

    print_info "Removing log directory..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "[DRY RUN] Would remove: ${LOG_DIR}"
    else
        if rm -rf "${LOG_DIR}"; then
            print_success "Logs removed: ${LOG_DIR}"
        else
            print_error "Failed to remove logs: ${LOG_DIR}"
            return 1
        fi
    fi
}

confirm_uninstall() {
    if [[ "${FORCE}" == "true" ]]; then
        return 0
    fi

    echo ""
    print_warning "This will remove the Homebrew Config Automation application"
    print_info "Your Brewfile and its destination directory will NOT be removed"
    echo ""

    read -p "Continue with uninstallation? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
}

#############################################
# Usage and Help Functions
#############################################

show_help() {
    cat << EOF
Homebrew Configuration Automation - Uninstallation Script

Removes the automation application while preserving Brewfiles.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --script-dir DIR    Script installation directory (default: ~/bin)
    --app-dir DIR       Application bundle directory (default: ~/Applications)
    --config-dir DIR    Configuration directory (default: ~/.config/homebrew-config)
    --plist-dir DIR     LaunchAgent plist directory (default: ~/Library/LaunchAgents)
    --log-dir DIR       Log directory (default: ~/.local/share/homebrew-config)
    --keep-config       Keep configuration directory
    --keep-logs         Keep log directory
    --dry-run           Show what would be removed without removing
    -f, --force         Skip confirmation prompt
    -h, --help          Show this help message

EXAMPLES:
    # Uninstall with confirmation
    $(basename "$0")

    # Uninstall and keep configuration
    $(basename "$0") --keep-config

    # Uninstall and keep logs
    $(basename "$0") --keep-logs

    # Preview what would be removed
    $(basename "$0") --dry-run

    # Uninstall without confirmation
    $(basename "$0") --force

    # Keep both config and logs
    $(basename "$0") --keep-config --keep-logs

WHAT WILL BE REMOVED:
    - Script: ~/bin/brew-config.sh
    - App Bundle: ~/Applications/Homebrew Config Automation.app
    - Plist: ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
    - Config: ~/.config/homebrew-config/ (unless --keep-config)
    - Logs: ~/.local/share/homebrew-config/ (unless --keep-logs)

WHAT WILL NOT BE REMOVED:
    - Your Brewfile and its destination directory
    - Homebrew itself and installed packages
    - Any Git repositories containing Brewfiles

NOTE:
    This script does NOT remove Homebrew or any packages installed via Homebrew.
    It only removes the automation application components.
EOF
}

parse_arguments() {
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
            --log-dir)
                require_argument "--log-dir" "${2:-}"
                LOG_DIR="$(expand_path "$2")"
                shift 2
                ;;
            --keep-config)
                KEEP_CONFIG=true
                shift
                ;;
            --keep-logs)
                KEEP_LOGS=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
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
    print_header "Homebrew Config Automation - Uninstaller"

    # Parse arguments
    parse_arguments "$@"

    # Show dry run notice
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_warning "DRY RUN MODE - No files will be removed"
        echo ""
    fi

    # Detect what's installed
    if ! detect_installation; then
        print_info "Nothing to uninstall"
        exit 0
    fi

    # Confirm uninstall (unless --force or --dry-run)
    if [[ "${DRY_RUN}" != "true" ]]; then
        confirm_uninstall
    fi

    print_header "Uninstalling Components"

    # Unload launchd job first
    unload_launchd_job

    # Remove components
    remove_script
    remove_app_bundle
    remove_plist
    remove_config
    remove_logs

    # Final summary
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_header "Dry Run Complete"
        print_info "No files were actually removed"
        print_info "Run without --dry-run to perform uninstallation"
    else
        print_header "Uninstallation Complete!"

        echo "The following components have been removed:"
        echo "  - Homebrew Config Automation script"
        echo "  - Application bundle"
        echo "  - Launchd plist"

        if [[ "${KEEP_CONFIG}" == "true" ]]; then
            echo "  - Configuration (kept as requested)"
        else
            echo "  - Configuration directory"
        fi

        if [[ "${KEEP_LOGS}" == "true" ]]; then
            echo "  - Logs (kept as requested)"
        else
            echo "  - Log directory"
        fi

        echo ""
        print_success "Uninstallation successful!"
        echo ""
        print_info "Your Brewfile and its destination directory were preserved"
        print_info "Homebrew and all installed packages remain untouched"

        if [[ "${KEEP_CONFIG}" == "true" ]] || [[ "${KEEP_LOGS}" == "true" ]]; then
            echo ""
            print_info "To manually remove kept files:"
            if [[ "${KEEP_CONFIG}" == "true" ]]; then
                echo "  rm -rf ${CONFIG_DIR}"
            fi
            if [[ "${KEEP_LOGS}" == "true" ]]; then
                echo "  rm -rf ${LOG_DIR}"
            fi
        fi
    fi
}

# Run main function
main "$@"
