# Homebrew Config Automation

Automated Homebrew management system for macOS that handles installation, upgrades, and Brewfile generation with Git version control integration.

## Overview

This system automatically:
- Installs Homebrew if not present
- Upgrades installed Homebrew packages
- Generates a Brewfile from your current Homebrew configuration
- Commits changes to Git (if the destination is a Git repository)
- Maintains rotating log files

The system uses a **single-run execution model** - the script executes all operations once and exits, making it suitable for manual execution or scheduled runs via launchd or cron.

## Features

- **Automated Homebrew Management**: Install and upgrade Homebrew without manual intervention
- **Brewfile Generation**: Maintain an up-to-date record of all installed packages
- **Git Integration**: Automatically commit Brewfile changes with timestamps
- **Intelligent Change Detection**: Only creates Git commits when the Brewfile actually changes
- **Log Rotation**: Automatically manages log file sizes with configurable limits
- **Flexible Configuration**: Configure via command-line, config file, or environment variables
- **macOS Integration**: Application bundle with custom icon visible in System Settings
- **Error Handling**: Distinguishes between critical and non-critical failures

## Prerequisites

- macOS (tested on macOS 10.15 and later)
- Bash or Zsh (included with macOS)
- Internet connection (for Homebrew installation and upgrades)

No additional dependencies required - works with a fresh macOS installation.

## Installation

### Quick Install

1. Clone or download this repository:
   ```bash
   git clone https://github.com/yourusername/homebrew-config-automation.git
   cd homebrew-config-automation
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Follow the on-screen instructions.

### Custom Installation

Install to custom locations:
```bash
./install.sh --script-dir /usr/local/bin --app-dir /Applications
```

Set a custom schedule (e.g., 3:30 AM daily):
```bash
./install.sh --schedule-hour 3 --schedule-minute 30
```

### Installation Locations

After installation, files are placed at:
- **Script**: `~/bin/brew-config.sh`
- **App Bundle**: `~/Applications/Homebrew Config Automation.app`
- **Plist**: `~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist`
- **Config**: `~/.config/homebrew-config/config.sh`
- **Logs**: `~/.local/share/homebrew-config/logs/`

## Configuration

### Configuration File

The default configuration file is located at `~/.config/homebrew-config/config.sh`. Edit this file to customize settings:

```bash
nano ~/.config/homebrew-config/config.sh
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `BREWFILE_DESTINATION` | Directory where Brewfile is saved | `~/Config` |
| `LOG_DIR` | Directory for log files | `~/.local/share/homebrew-config/logs` |
| `MAX_LOG_SIZE` | Maximum log file size before rotation (bytes) | `10485760` (10MB) |
| `MAX_LOG_FILES` | Number of rotated log files to keep | `5` |
| `GIT_COMMIT_ENABLED` | Enable automatic Git commits | `true` |

### Configuration Precedence

Configuration is loaded in this order (highest priority first):
1. Command-line arguments
2. Configuration file specified with `-c`
3. Default configuration file (`~/.config/homebrew-config/config.sh`)
4. Environment variables
5. Built-in defaults

### Example Configurations

#### Store Brewfile in a Dotfiles Repository
```bash
BREWFILE_DESTINATION="${HOME}/dotfiles"
GIT_COMMIT_ENABLED=true
```

#### Store in iCloud for Sync Across Devices
```bash
BREWFILE_DESTINATION="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/Config"
GIT_COMMIT_ENABLED=false
```

#### Keep More Log History
```bash
MAX_LOG_SIZE=52428800  # 50MB
MAX_LOG_FILES=10
```

## Usage

### Manual Execution

Run the script manually at any time:

```bash
# Run with default settings
~/bin/brew-config.sh

# Run with custom destination
~/bin/brew-config.sh -d /path/to/config

# Run with custom config file
~/bin/brew-config.sh -c /path/to/config.sh

# Show help
~/bin/brew-config.sh --help

# Show version
~/bin/brew-config.sh --version
```

### Scheduled Execution

#### Using launchd (Recommended)

Load the scheduled job to run automatically:

```bash
# Load the job
launchctl load ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist

# Check status
launchctl list | grep com.emkaytec.homebrewconfig

# Unload the job
launchctl unload ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
```

The default schedule runs daily at 02:00 AM. To change the schedule, edit the plist file or reinstall with different schedule parameters.

#### Managing in System Settings

After loading the job, you can manage it in **System Settings**:
1. Open **System Settings**
2. Go to **General** → **Login Items & Extensions**
3. Find **Homebrew Config Automation** in the list
4. Toggle it on or off

The application will appear with its custom icon and name.

#### Using Cron (Alternative)

Add to your crontab if you prefer cron:

```bash
# Edit crontab
crontab -e

# Add entry (runs daily at 2:00 AM)
0 2 * * * $HOME/bin/brew-config.sh
```

## Logs

### Viewing Logs

Check the main log file:
```bash
tail -f ~/.local/share/homebrew-config/logs/homebrew-config.log
```

View launchd output (if using scheduled execution):
```bash
tail -f ~/.local/share/homebrew-config/logs/launchd-stdout.log
tail -f ~/.local/share/homebrew-config/logs/launchd-stderr.log
```

List all log files:
```bash
ls -lh ~/.local/share/homebrew-config/logs/
```

### Log Format

Logs use the following format:
```
[YYYY-MM-DDTHH:MM:SS+0000] [LEVEL] Message
```

**Log Levels**:
- `INFO`: Normal operations
- `WARN`: Non-critical issues (e.g., destination is not a Git repo)
- `ERROR`: Failures that don't prevent continuation (e.g., upgrade failed)
- `FATAL`: Critical failures requiring exit (e.g., Homebrew installation failed)

### Log Rotation

- Logs automatically rotate when they exceed 10MB (configurable)
- Keeps the 5 most recent rotated logs (configurable)
- Rotated logs are named: `homebrew-config-YYYYMMDD-HHMMSS.log`

## Git Integration

### How It Works

1. After generating the Brewfile, the script checks if the destination directory is a Git repository
2. If yes, it checks whether the Brewfile content has changed
3. If changed, it stages and commits the Brewfile with a timestamp
4. If not changed, it skips the commit and logs the event

### Commit Message Format

```
Update Brewfile - 2025-01-15T14:30:00Z

Automated update from homebrew-config script
```

### Setting Up Git Integration

To enable Git integration:

1. Initialize a Git repository in your Brewfile destination:
   ```bash
   cd ~/Config  # Or your custom destination
   git init
   ```

2. Optionally, add a remote:
   ```bash
   git remote add origin https://github.com/yourusername/brewfile.git
   ```

3. The script will automatically commit changes when run

**Note**: The script does NOT push to remote repositories. You can set up automatic pushing with Git hooks or push manually.

## Troubleshooting

### Homebrew Installation Fails

**Symptom**: Script exits with error about Homebrew installation

**Solutions**:
- Check internet connection
- Verify you have admin privileges
- Try installing Homebrew manually: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Permission Denied Errors

**Symptom**: Script cannot write to destination or log directory

**Solutions**:
- Check directory permissions: `ls -la ~/Config`
- Ensure the destination directory is writable: `chmod u+w ~/Config`
- Check log directory permissions: `ls -la ~/.local/share/homebrew-config/logs`

### Scheduled Job Not Running

**Symptom**: launchd job is loaded but not executing

**Solutions**:
- Check job status: `launchctl list | grep com.emkaytec.homebrewconfig`
- Check launchd logs: `tail ~/.local/share/homebrew-config/logs/launchd-stderr.log`
- Verify plist syntax: `plutil -lint ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist`
- Reload the job:
  ```bash
  launchctl unload ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
  launchctl load ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
  ```

### Git Commits Not Being Created

**Symptom**: Brewfile is generated but no Git commits

**Possible Reasons**:
1. Destination is not a Git repository (check for `WARN` in logs)
2. Brewfile content hasn't changed (check for "skipping Git commit" in logs)
3. `GIT_COMMIT_ENABLED` is set to `false` in config
4. Git user.name or user.email not configured

**Solutions**:
- Initialize Git: `cd ~/Config && git init`
- Configure Git:
  ```bash
  git config user.name "Your Name"
  git config user.email "your@email.com"
  ```
- Check config: `cat ~/.config/homebrew-config/config.sh`

### Script Not in PATH

**Symptom**: Command not found when running `brew-config.sh`

**Solution**: Add `~/bin` to your PATH:
```bash
# For zsh (macOS default)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

## Uninstallation

### Using the Uninstall Script (Recommended)

The easiest way to uninstall is using the provided uninstall script:

```bash
# Preview what will be removed (dry run)
./uninstall.sh --dry-run

# Uninstall with confirmation prompt
./uninstall.sh

# Uninstall without confirmation
./uninstall.sh --force

# Keep configuration files
./uninstall.sh --keep-config

# Keep log files
./uninstall.sh --keep-logs

# Keep both config and logs
./uninstall.sh --keep-config --keep-logs
```

The uninstall script will:
- Automatically unload the launchd job if loaded
- Remove all application components
- Preserve your Brewfile and its destination directory
- Give you options to keep configuration and log files
- Provide clear feedback about what was removed

### Manual Uninstallation

If you prefer to remove components manually:

1. Unload the launchd job (if loaded):
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
   ```

2. Remove installed files:
   ```bash
   rm ~/bin/brew-config.sh
   rm -rf ~/Applications/Homebrew\ Config\ Automation.app
   rm ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
   rm -rf ~/.config/homebrew-config
   rm -rf ~/.local/share/homebrew-config
   ```

3. (Optional) Remove from PATH by editing `~/.zshrc` or `~/.bash_profile`

### What Gets Removed

- Script: `~/bin/brew-config.sh`
- App Bundle: `~/Applications/Homebrew Config Automation.app`
- Launchd Plist: `~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist`
- Configuration: `~/.config/homebrew-config/` (optional)
- Logs: `~/.local/share/homebrew-config/` (optional)

### What Does NOT Get Removed

- **Your Brewfile and its destination directory** (e.g., `~/Config`)
- Homebrew itself
- Any packages installed via Homebrew
- Any Git repositories containing your Brewfiles

**Note**: Uninstallation does NOT remove Homebrew or any installed packages.

## Advanced Usage

### Running with Different Configurations

Use multiple configuration files for different scenarios:

```bash
# Work configuration
brew-config.sh -c ~/config/work-brew-config.sh

# Personal configuration
brew-config.sh -c ~/config/personal-brew-config.sh
```

### Integrating with Dotfiles

Store your Brewfile in a dotfiles repository:

```bash
# In config.sh
BREWFILE_DESTINATION="${HOME}/dotfiles"
GIT_COMMIT_ENABLED=true

# Set up Git remote
cd ~/dotfiles
git remote add origin https://github.com/yourusername/dotfiles.git
```

### Custom Scheduling Patterns

Edit the plist file for custom schedules:

```bash
nano ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
```

Examples:
- **Multiple times per day**: Add multiple `StartCalendarInterval` dictionaries
- **Specific weekdays**: Add `<key>Weekday</key><integer>1</integer>` (1=Monday)
- **Run at startup**: Set `<key>RunAtLoad</key><true/>`

After editing, reload:
```bash
launchctl unload ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
launchctl load ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
```

## Exit Codes

The script uses the following exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Critical failure (Homebrew installation or Brewfile generation failed) |
| 2 | Configuration error |
| 3 | Permission error |

## Security Considerations

- The script requires internet access to install/upgrade Homebrew
- No credentials are stored in the script or configuration
- Git authentication uses your system's Git configuration
- Configuration file should be readable only by owner (set automatically to `600`)
- Logs may contain package names but no sensitive data

## Development

### Project Structure

```
homebrew-config-automation/
├── brew-config.sh                 # Main script (pure task runner)
├── install.sh                     # Installation and deployment
├── uninstall.sh                   # Uninstallation script
├── config.sh.example              # Configuration template
├── Homebrew Config Automation.app # Pre-built app bundle
│   └── Contents/
│       ├── Info.plist            # Bundle metadata
│       ├── MacOS/                # Wrapper executable
│       └── Resources/            # App icon
├── AppIcon.icns                  # Custom icon file
├── .gitignore                    # Git ignore rules
├── AGENTS.md                     # Contributor guidelines for automation agents
└── README.md                     # This file
```

### Testing

Test the main script:
```bash
./brew-config.sh -d /tmp/test-config
```

Test installation:
```bash
./install.sh --script-dir /tmp/test-install
```

Test uninstallation (dry run):
```bash
./uninstall.sh --dry-run
```

### Contributing

Contributions are welcome! Please ensure:
- Scripts follow bash best practices
- All functions include comments
- Changes maintain macOS compatibility
- No external dependencies beyond macOS defaults

## License

MIT License - See LICENSE file for details

## Author

Maintained by Emkaytec

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/yourusername/homebrew-config-automation/issues
- Documentation: See this README and AGENTS.md for technical details

## Changelog

### Version 1.0.0
- Initial release
- Automated Homebrew installation and upgrade
- Brewfile generation with Git integration
- Log rotation
- macOS application bundle with custom icon
- Launchd integration for scheduled execution
