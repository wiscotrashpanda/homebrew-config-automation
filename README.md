# Homebrew Brewfile Backup

Automatically backup your Homebrew configuration to a private GitHub Gist. Never lose track of your installed packages, casks, and taps again!

## Features

- **Automatic Backups**: Runs daily via macOS launchd
- **Change Detection**: Only uploads when your configuration changes (saves bandwidth and API calls)
- **Private Storage**: Stores Brewfiles in private GitHub Gists
- **Simple Setup**: One-command installation via install script
- **No Dependencies**: Uses only standard macOS tools plus Homebrew and GitHub CLI
- **Comprehensive Logging**: Track all backup operations
- **Manual Control**: Run, force, or dry-run backups anytime

## Quick Start

### Automated Installation (Recommended)

```bash
git clone https://github.com/yourusername/homebrew-config-automation.git
cd homebrew-config-automation
./install.sh
```

The installation script will:
1. Check for and install required dependencies (GitHub CLI, jq)
2. Guide you through GitHub authentication
3. Run your first backup
4. Optionally set up automatic daily backups

### Manual Installation

If you prefer to set things up manually:

1. **Install dependencies:**
   ```bash
   brew install gh jq
   ```

2. **Authenticate with GitHub:**
   ```bash
   gh auth login
   ```

3. **Make the script executable:**
   ```bash
   chmod +x brewfile_backup.sh
   ```

4. **Run your first backup:**
   ```bash
   ./brewfile_backup.sh
   ```

5. **(Optional) Set up automatic backups:**
   ```bash
   # Edit the plist file to set your script path
   sed "s|ABSOLUTE_PATH_TO_SCRIPT|$(pwd)/brewfile_backup.sh|g" \
       com.user.brewfile-backup.plist > ~/Library/LaunchAgents/com.user.brewfile-backup.plist

   # Load the launch agent
   launchctl load ~/Library/LaunchAgents/com.user.brewfile-backup.plist
   ```

## Requirements

- **macOS**: Built for macOS with launchd support
- **Homebrew**: [Install Homebrew](https://brew.sh)
- **GitHub CLI**: Installed via `brew install gh`
- **jq**: JSON processor, installed via `brew install jq`

## Usage

### Command-Line Options

```bash
./brewfile_backup.sh              # Normal backup (skip if unchanged)
./brewfile_backup.sh --force      # Force backup even if unchanged
./brewfile_backup.sh --dry-run    # Generate Brewfile but don't upload
./brewfile_backup.sh --help       # Show help message
```

### Automatic Backups

Once installed, the backup runs automatically every day at 2:00 AM. You don't need to do anything!

### Manual Backup Trigger

To run the backup immediately:

```bash
# If installed via launchd:
launchctl start com.user.brewfile-backup

# Or run the script directly:
./brewfile_backup.sh
```

### Viewing Logs

```bash
# View the log file
tail -f ~/.config/brewfile-backup/backup.log

# View launchd output (if using scheduled backups)
cat /tmp/brewfile-backup.stdout
cat /tmp/brewfile-backup.stderr
```

## How It Works

1. **Generation**: Uses `brew bundle dump` to create a Brewfile listing all installed packages, casks, taps, and Mac App Store apps

2. **Change Detection**: Calculates a SHA-256 hash of the Brewfile and compares it with the last backup. If unchanged, skips upload

3. **Upload**: Uses GitHub CLI (`gh api`) to create or update a private Gist with your Brewfile

4. **Configuration**: Saves the Gist ID and hash to `~/.config/brewfile-backup/config.json` for future runs

## File Locations

```
~/.config/brewfile-backup/
├── config.json    # Persistent configuration (Gist ID, last hash, timestamp)
├── backup.log     # Execution log
└── Brewfile       # Generated Brewfile (cached)

~/Library/LaunchAgents/
└── com.user.brewfile-backup.plist  # launchd configuration
```

## Configuration

### Changing the Schedule

Edit `~/Library/LaunchAgents/com.user.brewfile-backup.plist`:

```xml
<!-- Run at 3:30 AM instead of 2:00 AM -->
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>3</integer>
    <key>Minute</key>
    <integer>30</integer>
</dict>
```

After editing, reload the agent:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.brewfile-backup.plist
launchctl load ~/Library/LaunchAgents/com.user.brewfile-backup.plist
```

### Multiple Backups Per Day

```xml
<key>StartCalendarInterval</key>
<array>
    <dict><key>Hour</key><integer>2</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
</array>
```

## Restoring from Backup

Your Brewfile is backed up to a private Gist. To restore:

1. **Find your Gist URL** in the config file:
   ```bash
   jq -r '.gist_url' ~/.config/brewfile-backup/config.json
   ```

2. **Download the Brewfile**:
   ```bash
   # Via web browser: visit the Gist URL
   # Or via command line:
   gh gist view YOUR_GIST_ID --raw > Brewfile
   ```

3. **Restore packages**:
   ```bash
   brew bundle install
   ```

This will install all packages, casks, taps, and Mac App Store apps listed in the Brewfile.

## Troubleshooting

### "GitHub CLI is not authenticated"

Run `gh auth login` and follow the prompts. Make sure to grant access to gists.

### "jq (JSON processor) is not installed"

Run `brew install jq`.

### Script runs but doesn't upload

Check if changes were detected:
```bash
tail -20 ~/.config/brewfile-backup/backup.log
```

If you see "Brewfile unchanged", no upload occurred because nothing changed. Use `--force` to upload anyway.

### launchd job not running

Verify the job is loaded:
```bash
launchctl list | grep brewfile
```

If not listed, load it:
```bash
launchctl load ~/Library/LaunchAgents/com.user.brewfile-backup.plist
```

Check for errors:
```bash
cat /tmp/brewfile-backup.stderr
```

### PATH issues with launchd

The plist file includes common Homebrew paths. If you have a custom Homebrew location, edit the plist file:

```xml
<key>PATH</key>
<string>/your/custom/path:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
```

## Uninstalling

### Remove automatic backups:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.brewfile-backup.plist
rm ~/Library/LaunchAgents/com.user.brewfile-backup.plist
```

### Remove configuration and logs:
```bash
rm -rf ~/.config/brewfile-backup
```

### Delete your Gist:
Visit your [Gists page](https://gist.github.com/) and delete the "Homebrew Brewfile Backup" Gist.

## Advanced Usage

### Integration with Other Scripts

Source the functions from `brewfile_backup.sh`:

```bash
#!/bin/bash
source /path/to/brewfile_backup.sh

# Use individual functions
init_config
check_dependencies
generate_brewfile
echo "Brewfile hash: $BREWFILE_HASH"
```

### Custom Gist Description

Edit the `create_gist()` function in `brewfile_backup.sh` and change the description:

```bash
--arg desc "My Custom Brewfile Backup - $(hostname)" \
```

### Multiple Machines

Each machine creates its own Gist by default. If you want to share a single Gist across machines:

1. Run the backup on the first machine
2. Copy `~/.config/brewfile-backup/config.json` to other machines
3. All machines will update the same Gist

## Security

- **GitHub Authentication**: Uses GitHub CLI's secure keychain storage. Your token is never stored in plain text.
- **Private Gists**: All Gists are created as private by default.
- **File Permissions**: Config file is set to `600` (owner read/write only).
- **No Secrets in Brewfile**: Brewfiles contain package names but no passwords or secrets.

## Exit Codes

- `0`: Success (including no changes detected)
- `1`: Authentication error (gh not installed/authenticated)
- `2`: Homebrew error (brew not available or dump failed)
- `3`: GitHub API error (gist creation/update failed)
- `4`: Configuration error
- `99`: Unexpected error

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - feel free to use and modify as needed.

## Credits

Built with:
- [Homebrew](https://brew.sh/) - The missing package manager for macOS
- [GitHub CLI](https://cli.github.com/) - GitHub's official command line tool
- [jq](https://stedolan.github.io/jq/) - Lightweight JSON processor

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/homebrew-config-automation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/homebrew-config-automation/discussions)

---

**Made with ❤️ for Homebrew users who like to keep their setups backed up**
