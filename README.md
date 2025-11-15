# Homebrew Configuration Management

Automates Homebrew installation, upgrades, and Brewfile generation on macOS systems. This script ensures Homebrew stays updated and maintains a version-controlled record of your installed packages.

## Overview

This tool provides automated management of your Homebrew installation:

- **Automatic Installation**: Installs Homebrew if not already present
- **Automatic Upgrades**: Keeps Homebrew and packages up-to-date
- **Brewfile Generation**: Creates a Brewfile listing all installed packages
- **Git Integration**: Automatically commits Brewfile changes
- **Scheduled Execution**: Optional automated runs via launchd with application bundle
- **Comprehensive Logging**: Detailed logs with automatic rotation

## Prerequisites

- **Operating System**: macOS (tested on macOS 10.15+)
- **Shell**: bash or zsh (default on macOS)
- **Git** (optional): For automatic commits of Brewfile changes
- **Disk Space**: Minimal (logs are rotated and capped at 50MB total)

No additional dependencies required - the script uses only tools available in a fresh macOS installation.

## Installation

### Quick Install

```bash
# Clone or download this repository
git clone <repository-url>
cd homebrew-config-automation

# Run the installation script
./install.sh
```

The installation script will:

1. Copy `brew-config.sh` to `~/bin/`
2. Deploy the application bundle to `~/Applications/`
3. Generate a launchd plist file (default schedule: daily at 02:00)
4. Create configuration directory and files

### Custom Installation

```bash
# Install to a custom directory
./install.sh --install-dir /usr/local/bin

# Install with custom configuration directory
./install.sh --config-dir ~/.my-config
```

### Installation Options

- `-i, --install-dir DIR` - Installation directory for script (default: `~/bin`)
- `-c, --config-dir DIR` - Configuration directory (default: `~/.config/homebrew-config`)
- `-h, --help` - Show help message

### What Gets Installed

- **Script**: `~/bin/brew-config.sh`
- **App Bundle**: `~/Applications/Homebrew Config Automation.app`
- **Plist**: `~/Library/LaunchAgents/com.homebrewconfig.automation.plist`
- **Configuration**: `~/.config/homebrew-config/config.sh`
- **Example Config**: `~/.config/homebrew-config/config.sh.example`
- **Logs**: `~/.local/share/homebrew-config/logs/`

## Configuration

### Configuration File

Edit `~/.config/homebrew-config/config.sh` to customize behavior:

```bash
# Brewfile destination directory
BREWFILE_DESTINATION="${HOME}/Config"

# Log directory
LOG_DIR="${HOME}/.local/share/homebrew-config/logs"

# Maximum log file size (10MB)
MAX_LOG_SIZE=10485760

# Number of rotated logs to keep
MAX_LOG_FILES=5

# Enable/disable Git commits
GIT_COMMIT_ENABLED=true
```

### Configuration Parameters

| Parameter              | Description                       | Default                               |
| ---------------------- | --------------------------------- | ------------------------------------- |
| `BREWFILE_DESTINATION` | Directory where Brewfile is saved | `~/Config`                            |
| `LOG_DIR`              | Directory for log files           | `~/.local/share/homebrew-config/logs` |
| `MAX_LOG_SIZE`         | Maximum log file size in bytes    | `10485760` (10MB)                     |
| `MAX_LOG_FILES`        | Number of rotated logs to keep    | `5`                                   |
| `GIT_COMMIT_ENABLED`   | Enable automatic Git commits      | `true`                                |

### Configuration Precedence

Configuration is loaded in this order (highest to lowest priority):

1. Command-line arguments
2. Configuration file specified with `-c`
3. Default configuration file (`~/.config/homebrew-config/config.sh`)
4. Built-in defaults

### Modifying Configuration After Installation

1. Edit the configuration file:

   ```bash
   nano ~/.config/homebrew-config/config.sh
   ```

2. Changes take effect on the next script execution

3. To change the schedule time, edit the plist and reload:

   ```bash
   # Edit the plist
   nano ~/Library/LaunchAgents/com.homebrewconfig.automation.plist

   # Reload launchd
   launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
   launchctl load ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
   ```

## Usage

### Manual Execution

Run the script manually at any time:

```bash
# Run with default settings
brew-config.sh

# Specify custom Brewfile destination
brew-config.sh --destination ~/Dotfiles

# Use custom configuration file
brew-config.sh --config ~/my-config.sh

# Show help
brew-config.sh --help

# Show version
brew-config.sh --version
```

### Command-Line Options

- `-d, --destination DIR` - Brewfile destination directory
- `-c, --config FILE` - Configuration file path
- `-h, --help` - Show help message
- `-v, --version` - Show version information

### Common Usage Scenarios

**First-time setup on a new Mac:**

```bash
# Install and run immediately
./install.sh
brew-config.sh
```

**Custom Brewfile location for dotfiles:**

```bash
# Run with custom destination
brew-config.sh --destination ~/dotfiles
```

## Scheduling

### Setting Up Scheduled Execution

The installation script automatically generates a launchd plist file configured for daily execution at 02:00. The plist references the deployed application bundle, which appears as "Homebrew Config Automation" in System Settings.

**To activate scheduled execution:**

```bash
launchctl load ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
```

**To deactivate:**

```bash
launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
```

### Customizing the Schedule

To change the schedule time, edit the plist file:

```bash
nano ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
```

Change the `Hour` and `Minute` values in the `StartCalendarInterval` section:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>3</integer>  <!-- Change to desired hour (0-23) -->
    <key>Minute</key>
    <integer>30</integer>  <!-- Change to desired minute (0-59) -->
</dict>
```

Then reload the plist:

```bash
launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
launchctl load ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
```

### Managing Scheduled Execution

**Check if running:**

```bash
launchctl list | grep homebrewconfig
```

**View schedule:**

```bash
cat ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
```

**Remove schedule:**

```bash
launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
rm ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
```

### Application Bundle

The scheduled execution uses an application bundle (`Homebrew Config Automation.app`) that:

- Displays with a recognizable name and icon in System Settings
- Appears in Login Items & Extensions
- Wraps the brew-config.sh script for clean execution

## Logs

### Log Location

Logs are stored in: `~/.local/share/homebrew-config/logs/`

- **Active log**: `homebrew-config.log`
- **Rotated logs**: `homebrew-config-YYYYMMDD-HHMMSS.log`
- **Launchd output**: `launchd-stdout.log` and `launchd-stderr.log`

### Log Format

```
[YYYY-MM-DDTHH:MM:SS+0000] [LEVEL] Message
```

**Log Levels:**

- `INFO` - Normal operations
- `WARN` - Non-critical issues
- `ERROR` - Failures that don't prevent continuation
- `FATAL` - Critical failures requiring exit

### Log Rotation

- Logs rotate automatically when they exceed 10MB
- Maximum of 5 rotated logs are kept
- Older logs are automatically deleted

### Viewing Logs

```bash
# View active log
tail -f ~/.local/share/homebrew-config/logs/homebrew-config.log

# View last 50 lines
tail -n 50 ~/.local/share/homebrew-config/logs/homebrew-config.log

# Search for errors
grep ERROR ~/.local/share/homebrew-config/logs/homebrew-config.log

# View launchd output
cat ~/.local/share/homebrew-config/logs/launchd-stdout.log
```

## Troubleshooting

### Common Issues

**Issue: Script not found after installation**

Solution: Add installation directory to PATH

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Issue: Permission denied when running script**

Solution: Make script executable

```bash
chmod +x ~/bin/brew-config.sh
```

**Issue: Homebrew installation fails**

Solution: Check network connection and try manual installation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Issue: Git commits not being created**

Solutions:

1. Ensure destination is a Git repository:

   ```bash
   cd ~/Config
   git init
   ```

2. Check if Git commits are enabled:
   ```bash
   grep GIT_COMMIT_ENABLED ~/.config/homebrew-config/config.sh
   ```

**Issue: Scheduled execution not running**

Solutions:

1. Check if launchd job is loaded:

   ```bash
   launchctl list | grep homebrewconfig
   ```

2. Check launchd logs:

   ```bash
   cat ~/.local/share/homebrew-config/logs/launchd-stderr.log
   ```

3. Reload the job:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
   launchctl load ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
   ```

**Issue: Application bundle not appearing in System Settings**

Solution: The bundle should appear automatically. If not, try:

1. Verify the bundle exists:

   ```bash
   ls -la ~/Applications/Homebrew\ Config\ Automation.app
   ```

2. Reload the plist:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
   launchctl load ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
   ```

**Issue: Log files growing too large**

Solution: Adjust log rotation settings in config file

```bash
# Reduce max log size to 5MB
MAX_LOG_SIZE=5242880

# Keep only 3 rotated logs
MAX_LOG_FILES=3
```

### Error Messages

**"Configuration validation failed"**

- Check that Brewfile destination directory is writable
- Verify log directory can be created

**"Failed to install Homebrew"**

- Check internet connection
- Verify you have admin privileges
- Check available disk space

**"Failed to generate Brewfile"**

- Ensure Homebrew is installed: `brew --version`
- Check destination directory permissions
- Verify disk space available

**"Destination is not a Git repository"**

- This is a warning, not an error
- Initialize Git in destination: `cd ~/Config && git init`
- Or disable Git commits: `GIT_COMMIT_ENABLED=false`

## Uninstallation

To completely remove the script:

```bash
# 1. Unload launchd job
launchctl unload ~/Library/LaunchAgents/com.homebrewconfig.automation.plist

# 2. Remove installed files
rm ~/bin/brew-config.sh
rm -rf ~/Applications/Homebrew\ Config\ Automation.app
rm ~/Library/LaunchAgents/com.homebrewconfig.automation.plist
rm -rf ~/.config/homebrew-config
rm -rf ~/.local/share/homebrew-config

# 3. (Optional) Remove Brewfile
rm ~/Config/Brewfile
```

Note: This does not uninstall Homebrew itself. To uninstall Homebrew, see: https://docs.brew.sh/FAQ#how-do-i-uninstall-homebrew

## Development

### Project Structure

```
homebrew-config-automation/
├── brew-config.sh                          # Main script (pure task runner)
├── install.sh                              # Installation and deployment script
├── Homebrew Config Automation.app/         # Pre-built application bundle
│   └── Contents/
│       ├── Info.plist                      # Bundle metadata
│       ├── MacOS/
│       │   └── Homebrew Config Automation  # Wrapper executable
│       └── Resources/
│           └── AppIcon.icns                # Custom icon
├── config.sh.example                       # Example configuration
├── .gitignore                             # Git ignore rules
└── README.md                              # This file
```

### Architecture

The system consists of:

- **brew-config.sh**: Pure task runner that executes operations and exits
- **Application Bundle**: Provides clean UI in System Settings with icon
- **install.sh**: Handles deployment of all components
- **launchd plist**: References the app bundle for scheduled execution

### Testing

Run the script in a test environment:

```bash
# Test with custom destination
./brew-config.sh --destination /tmp/test-brewfile

# Test configuration loading
./brew-config.sh --config /path/to/test-config.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

[Add your license here]

## Support

For issues, questions, or contributions, please [open an issue](link-to-issues) on the repository.

## Version

Current version: 1.0.0

## Changelog

### 1.0.0 (Initial Release)

- Automatic Homebrew installation and upgrades
- Brewfile generation and management
- Git integration for version control
- Scheduled execution via launchd with application bundle
- Comprehensive logging with rotation
- Full configuration support
- Application bundle with custom icon for System Settings visibility
