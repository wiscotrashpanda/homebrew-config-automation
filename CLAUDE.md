# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Homebrew automation system for macOS that manages Homebrew installation, upgrades, and Brewfile generation with Git version control integration. The system uses a run-once execution model suitable for on-demand or scheduled execution via launchd.

## Key Architecture Principles

### Execution Model
- **Single-run design**: The main script (`brew-config.sh`) executes all operations once and exits
- No loops, timers, or background processes in the main script
- Scheduling logic is completely separate from the task runner
- Suitable for invocation by launchd, cron, or manual command-line execution

### Component Separation
- `brew-config.sh`: Pure task runner that orchestrates Homebrew operations
- `install.sh`: Handles deployment of application bundle and plist generation
- Pre-built application bundle: Provides macOS System Settings integration with custom icon
- The task runner contains NO scheduling or plist generation logic

### Application Bundle Structure
The repository includes a pre-built `Homebrew Config Automation.app` bundle:
- Wrapper executable calls the installed `brew-config.sh` script
- Provides recognizable name and icon in System Settings Login Items
- Uses Emkaytec developer identifier: `com.emkaytec.homebrewconfig`
- The bundle is deployed to `~/Applications/` during installation

## Development Commands

### Testing the Main Script
```bash
# Test manual execution with default settings
./brew-config.sh

# Test with custom destination directory
./brew-config.sh -d /path/to/destination

# Test with custom configuration file
./brew-config.sh -c /path/to/config.sh

# View help and options
./brew-config.sh -h
```

### Installation Testing
```bash
# Run installation script
./install.sh

# Verify installation locations
ls -l ~/bin/brew-config.sh
ls -l ~/Applications/Homebrew\ Config\ Automation.app
ls -l ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
```

### Launchd Testing
```bash
# Load the scheduled job
launchctl load ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist

# Check job status
launchctl list | grep com.emkaytec.homebrewconfig

# Unload the job
launchctl unload ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
```

### Log Inspection
```bash
# View active log
tail -f ~/.local/share/homebrew-config/logs/homebrew-config.log

# View launchd output (if scheduled)
tail -f ~/.local/share/homebrew-config/logs/launchd-stdout.log
tail -f ~/.local/share/homebrew-config/logs/launchd-stderr.log

# Check log rotation
ls -lh ~/.local/share/homebrew-config/logs/
```

## Critical Implementation Details

### Exit Codes
- `0`: Success
- `1`: Critical failure (Homebrew installation failed, Brewfile generation failed)
- `2`: Configuration error
- `3`: Permission error

### Error Handling Strategy
- **Critical errors** (exit immediately): Homebrew installation failure, Brewfile generation failure, invalid configuration, permission errors
- **Non-critical errors** (log and continue): Homebrew upgrade failure, Git commit failure, log rotation failure

### Configuration Precedence
Configuration is loaded in this order (highest to lowest priority):
1. Command-line arguments
2. Configuration file specified with `-c`
3. Default configuration file at `~/.config/brew-automation/config.sh`
4. Environment variables
5. Built-in defaults

### Git Integration Logic
1. Check if destination directory is a Git repository
2. Only commit if the Brewfile content has changed from the previous version
3. Skip commit and log the event if content is identical
4. Log warning and skip commit if destination is not a Git repository
5. Non-critical: log errors but continue script execution if Git operations fail

### Log Rotation Behavior
- Active log: `~/.local/share/homebrew-config/logs/homebrew-config.log`
- Rotated when size exceeds 10MB
- Keep maximum of 5 rotated log files
- Log format: `[YYYY-MM-DDTHH:MM:SS±TZ] [LEVEL] Message`
- Levels: INFO, WARN, ERROR, FATAL

### Launchd Plist Generation
The installation script (`install.sh`) generates the plist file with:
- Label: `com.emkaytec.homebrewconfig`
- References the deployed app bundle executable path
- Default schedule: 02:00 daily
- Does NOT automatically load the plist (user must run `launchctl load`)

## Installation Locations
- Script: `~/bin/brew-config.sh`
- App Bundle: `~/Applications/Homebrew Config Automation.app/`
- Plist: `~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist`
- Config: `~/.config/homebrew-config/config.sh`
- Logs: `~/.local/share/homebrew-config/logs/`

## Shell Compatibility
- Use bash or zsh features available by default on macOS
- Assume minimal installed components (fresh macOS installation)
- No external dependencies beyond what ships with macOS

## Security Requirements
- Sanitize all user-provided paths
- Validate configuration values before use
- Prevent command injection through arguments
- Script permissions: executable only by owner
- Configuration file: readable only by owner
- No credentials stored in script or configuration
