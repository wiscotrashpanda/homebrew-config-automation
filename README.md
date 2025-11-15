# Homebrew Configuration Management

Automates Homebrew installation, upgrades, and Brewfile generation on macOS systems. This script ensures Homebrew stays updated and maintains a version-controlled record of your installed packages.

## Overview

This tool provides automated management of your Homebrew installation:

- **Automatic Installation**: Installs Homebrew if not already present
- **Automatic Upgrades**: Keeps Homebrew and packages up-to-date
- **Brewfile Generation**: Creates a Brewfile listing all installed packages
- **Git Integration**: Automatically commits Brewfile changes
- **Scheduled Execution**: Optional automated runs via launchd
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
cd homebrew-config

# Run the installation script
./install.sh
```

### Custom Installation

```bash
# Install to a custom directory
./install.sh --install-dir /usr/local/bin

# Install with daily scheduled execution
./install.sh --schedule daily

# Install with custom configuration directory
./install.sh --config-dir ~/.my-config
```

### Installation Options

- `-i, --install-dir DIR` - Installation directory for script (default: `~/bin`)
- `-c, --config-dir DIR` - Configuration directory (default: `~/.config/homebrew-config`)
- `-s, --schedule PATTERN` - Setup scheduled execution (daily|weekly|INTERVAL)
- `-h, --help` - Show help message

### What Gets Installed

- **Script**: `~/bin/brew-config.sh` (or your specified directory)
- **Configuration**: `~/.config/homebrew-config/config.sh`
- **Example Config**: `~/.config/homebrew-config/config.sh.example`
- **Logs**: `~/.local/share/homebrew-config/logs/`
- **Launchd Plist** (if scheduled): `~/Library/LaunchAgents/com.user.homebrew-config.plist`

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

# Schedule pattern (for launchd setup)
SCHEDULE_PATTERN="daily"
```

### Configuration Parameters

| Parameter              | Description                       | Default                               |
| ---------------------- | --------------------------------- | ------------------------------------- |
| `BREWFILE_DESTINATION` | Directory where Brewfile is saved | `~/Config`                            |
| `LOG_DIR`              | Directory for log files           | `~/.local/share/homebrew-config/logs` |
| `MAX_LOG_SIZE`         | Maximum log file size in bytes    | `10485760` (10MB)                     |
| `MAX_LOG_FILES`        | Number of rotated logs to keep    | `5`                                   |
| `GIT_COMMIT_ENABLED`   | Enable automatic Git commits      | `true`                                |
| `SCHEDULE_PATTERN`     | Schedule for launchd              | `daily`                               |

### Configuration Precedence

Configuration is loaded in this order (highest to lowest priority):

1. Command-line arguments
2. Configuration file specified with `-c`
3. Default configuration file (`~/.config/homebrew-config/config.sh`)
4. Environment variables
5. Built-in defaults

### Modifying Configuration After Installation

1. Edit the configuration file:

   ```bash
   nano ~/.config/homebrew-config/config.sh
   ```

2. Changes take effect on the next script execution

3. To change the schedule, edit the plist and reload:

   ```bash
   # Edit the plist
   nano ~/Library/LaunchAgents/com.user.homebrew-config.plist

   # Reload launchd
   launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist
   launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
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
- `-s, --schedule PATTERN` - Setup scheduled execution
- `-c, --config FILE` - Configuration file path
- `--generate-plist` - Generate launchd plist file for scheduled execution
- `--schedule-time HH:MM` - Time for scheduled execution (24-hour format, default: 02:00)
- `-h, --help` - Show help message
- `-v, --version` - Show version information

### Common Usage Scenarios

**First-time setup on a new Mac:**

```bash
# Install and run immediately
./install.sh
brew-config.sh
```

**Daily automated updates:**

```bash
# Install with daily schedule
./install.sh --schedule daily
```

**Custom Brewfile location for dotfiles:**

```bash
# Run with custom destination
brew-config.sh --destination ~/dotfiles
```

**Set up scheduled execution at a specific time:**

```bash
# Generate plist for daily execution at 3:30 AM
brew-config.sh --generate-plist --schedule-time 03:30

# Load the plist
launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

**Weekly updates with custom interval:**

```bash
# Install with weekly schedule
./install.sh --schedule weekly
```

## Scheduling

### Setting Up Scheduled Execution

Scheduled execution uses macOS launchd to run the script automatically. You can set up scheduling in two ways:

#### Option 1: Using --generate-plist (Recommended)

The easiest way to set up scheduled execution is to use the built-in plist generator:

```bash
# Generate plist for daily execution at 2:00 AM (default)
brew-config.sh --generate-plist

# Generate plist for daily execution at a custom time
brew-config.sh --generate-plist --schedule-time 03:30

# Generate plist for daily execution at 6:00 AM
brew-config.sh --generate-plist --schedule-time 06:00
```

After generating the plist, load it with launchctl:

```bash
launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

The `--generate-plist` option will:

- Create a properly formatted plist file
- Use the script's actual installation path
- Set up logging for launchd output
- Display instructions for loading the plist

#### Option 2: During Installation

```bash
./install.sh --schedule daily
```

#### Option 3: Manual Setup

```bash
# Create and load the plist manually
# (See Configuration section above)
```

### Schedule Patterns

| Pattern  | Description                  | Example             |
| -------- | ---------------------------- | ------------------- |
| `daily`  | Runs at 2:00 AM every day    | `--schedule daily`  |
| `weekly` | Runs at 2:00 AM every Sunday | `--schedule weekly` |
| `3600`   | Runs every hour (in seconds) | `--schedule 3600`   |
| `86400`  | Runs every 24 hours          | `--schedule 86400`  |

### Managing Scheduled Execution

**Check if running:**

```bash
launchctl list | grep homebrew-config
```

**View schedule:**

```bash
cat ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

**Disable schedule:**

```bash
launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

**Enable schedule:**

```bash
launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

**Remove schedule:**

```bash
launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist
rm ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

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

### Plist Generation Issues

**Issue: --generate-plist fails with "Invalid schedule time format"**

Solution: Ensure time is in HH:MM format (24-hour)

```bash
# Correct format
brew-config.sh --generate-plist --schedule-time 03:30

# Incorrect formats
brew-config.sh --generate-plist --schedule-time 3:30    # Missing leading zero
brew-config.sh --generate-plist --schedule-time 15:30PM # Don't use AM/PM
```

**Issue: Generated plist doesn't use the correct script path**

Solution: The script automatically detects its installation path. If you move the script after generating the plist, regenerate it:

```bash
brew-config.sh --generate-plist
launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist
launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
```

**Issue: Plist generation succeeds but launchctl load fails**

Solutions:

1. Check if a plist with the same name is already loaded:

   ```bash
   launchctl list | grep homebrew-config
   ```

2. Unload the existing plist first:

   ```bash
   launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist
   launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
   ```

3. Verify plist syntax:
   ```bash
   plutil -lint ~/Library/LaunchAgents/com.user.homebrew-config.plist
   ```

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
   launchctl list | grep homebrew-config
   ```

2. Check launchd logs:

   ```bash
   cat ~/.local/share/homebrew-config/logs/launchd-stderr.log
   ```

3. Reload the job:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist
   launchctl load ~/Library/LaunchAgents/com.user.homebrew-config.plist
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
# 1. Unload launchd job (if scheduled)
launchctl unload ~/Library/LaunchAgents/com.user.homebrew-config.plist

# 2. Remove installed files
rm ~/bin/brew-config.sh
rm -rf ~/.config/homebrew-config
rm -rf ~/.local/share/homebrew-config
rm ~/Library/LaunchAgents/com.user.homebrew-config.plist

# 3. (Optional) Remove Brewfile
rm ~/Config/Brewfile
```

Note: This does not uninstall Homebrew itself. To uninstall Homebrew, see: https://docs.brew.sh/FAQ#how-do-i-uninstall-homebrew

## Development

### Project Structure

```
homebrew-config/
├── brew-config.sh          # Main script
├── install.sh              # Installation script
├── config.sh.example       # Example configuration
├── .gitignore             # Git ignore rules
└── README.md              # This file
```

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
- Scheduled execution via launchd
- Comprehensive logging with rotation
- Full configuration support
