#!/bin/bash

################################################################################
# Brewfile Backup - Installation Script
################################################################################
#
# This script automates the installation and setup of the Brewfile backup system.
#
# What it does:
#   1. Checks for required dependencies (brew, gh, jq)
#   2. Installs missing dependencies via Homebrew
#   3. Configures GitHub CLI authentication if needed
#   4. Sets up the launchd configuration
#   5. Runs an initial backup
#
# Usage:
#   ./install.sh
#
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/brewfile_backup.sh"
PLIST_TEMPLATE="$SCRIPT_DIR/com.user.brewfile-backup.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.brewfile-backup.plist"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

################################################################################
# Main Installation Steps
################################################################################

print_header "Brewfile Backup Installation"

# Step 1: Check if Homebrew is installed
print_info "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    print_error "Homebrew is not installed"
    echo ""
    echo "Please install Homebrew first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo ""
    exit 1
fi
print_success "Homebrew is installed"

# Step 2: Check and install GitHub CLI
print_info "Checking for GitHub CLI (gh)..."
if ! command -v gh &>/dev/null; then
    print_warning "GitHub CLI not found, installing..."
    if brew install gh; then
        print_success "GitHub CLI installed successfully"
    else
        print_error "Failed to install GitHub CLI"
        exit 1
    fi
else
    print_success "GitHub CLI is already installed"
fi

# Step 3: Check and install jq
print_info "Checking for jq (JSON processor)..."
if ! command -v jq &>/dev/null; then
    print_warning "jq not found, installing..."
    if brew install jq; then
        print_success "jq installed successfully"
    else
        print_error "Failed to install jq"
        exit 1
    fi
else
    print_success "jq is already installed"
fi

# Step 4: Check GitHub CLI authentication
print_info "Checking GitHub CLI authentication..."
if ! gh auth status &>/dev/null; then
    print_warning "GitHub CLI is not authenticated"
    echo ""
    echo "Please authenticate with GitHub. You will need to:"
    echo "  1. Choose 'GitHub.com'"
    echo "  2. Choose your preferred protocol (HTTPS or SSH)"
    echo "  3. Authenticate via web browser or token"
    echo ""
    read -p "Press Enter to start authentication..."

    if gh auth login; then
        print_success "GitHub authentication successful"
    else
        print_error "GitHub authentication failed"
        exit 1
    fi
else
    print_success "GitHub CLI is authenticated"
fi

# Step 5: Make backup script executable
print_info "Making backup script executable..."
if chmod +x "$BACKUP_SCRIPT"; then
    print_success "Backup script is executable"
else
    print_error "Failed to make script executable"
    exit 1
fi

# Step 6: Run initial backup
print_header "Running Initial Backup"
print_info "This will create your first Brewfile backup..."
echo ""

if "$BACKUP_SCRIPT"; then
    print_success "Initial backup completed successfully"
else
    print_error "Initial backup failed"
    echo ""
    echo "Please check the error messages above and try running manually:"
    echo "  $BACKUP_SCRIPT"
    echo ""
    exit 1
fi

# Step 7: Set up launchd (optional)
echo ""
print_header "Automatic Scheduling Setup"
echo "Would you like to set up automatic daily backups via launchd?"
echo "This will run the backup script automatically every day at 2:00 AM."
echo ""
read -p "Set up automatic backups? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setting up launchd configuration..."

    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$HOME/Library/LaunchAgents"

    # Copy and modify plist file
    if sed "s|ABSOLUTE_PATH_TO_SCRIPT|$BACKUP_SCRIPT|g" "$PLIST_TEMPLATE" > "$PLIST_DEST"; then
        print_success "Launchd configuration created at $PLIST_DEST"
    else
        print_error "Failed to create launchd configuration"
        exit 1
    fi

    # Load the launch agent
    print_info "Loading launch agent..."
    if launchctl load "$PLIST_DEST" 2>/dev/null; then
        print_success "Launch agent loaded successfully"
    else
        # If already loaded, unload and reload
        print_warning "Agent already loaded, reloading..."
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        if launchctl load "$PLIST_DEST"; then
            print_success "Launch agent reloaded successfully"
        else
            print_error "Failed to load launch agent"
            exit 1
        fi
    fi

    # Verify it's loaded
    if launchctl list | grep -q "com.user.brewfile-backup"; then
        print_success "Launch agent is running"
    else
        print_warning "Launch agent may not be running properly"
    fi

    echo ""
    print_success "Automatic backups configured!"
    echo ""
    print_info "The backup will run daily at 2:00 AM"
    print_info "To run manually: launchctl start com.user.brewfile-backup"
    print_info "To disable: launchctl unload $PLIST_DEST"
else
    print_info "Skipping automatic backup setup"
    echo ""
    echo "You can set it up later by running:"
    echo "  1. Edit $PLIST_TEMPLATE"
    echo "  2. Replace ABSOLUTE_PATH_TO_SCRIPT with $BACKUP_SCRIPT"
    echo "  3. Copy to ~/Library/LaunchAgents/"
    echo "  4. Run: launchctl load ~/Library/LaunchAgents/com.user.brewfile-backup.plist"
fi

# Final summary
print_header "Installation Complete!"

echo "Configuration:"
echo "  • Backup script: $BACKUP_SCRIPT"
echo "  • Config directory: ~/.config/brewfile-backup/"
echo "  • Log file: ~/.config/brewfile-backup/backup.log"
echo ""

# Get Gist URL from config
GIST_URL=$(jq -r '.gist_url // ""' "$HOME/.config/brewfile-backup/config.json" 2>/dev/null || echo "")
if [[ -n "$GIST_URL" ]]; then
    echo "Your Brewfile backup:"
    echo "  • Gist URL: $GIST_URL"
    echo ""
fi

echo "Next steps:"
echo "  • View your backup: cat ~/.config/brewfile-backup/Brewfile"
echo "  • Run manually: $BACKUP_SCRIPT"
echo "  • View logs: tail -f ~/.config/brewfile-backup/backup.log"
echo "  • Test dry-run: $BACKUP_SCRIPT --dry-run"
echo "  • Force backup: $BACKUP_SCRIPT --force"
echo ""

print_success "All done! Your Homebrew configuration is now being backed up to GitHub Gists."
echo ""
