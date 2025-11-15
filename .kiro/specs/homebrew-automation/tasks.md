# Implementation Plan

- [x] 1. Set up project structure and configuration files

  - Create directory structure for the homebrew-config project
  - Create .gitignore file to exclude logs and development artifacts
  - Create config.sh.example with all configuration parameters documented
  - _Requirements: 12.1, 12.2, 12.4_

- [x] 2. Implement core logging system

  - [x] 2.1 Create logging functions with timestamp formatting

    - Write log_message() function that formats messages with ISO 8601 timestamps
    - Implement log level support (INFO, WARN, ERROR, FATAL)
    - Write setup_logging() function to initialize log directory and file
    - _Requirements: 5.1, 5.2_

  - [x] 2.2 Implement log rotation mechanism
    - Write rotate_logs() function to check file size and rotate when needed
    - Implement logic to rename old logs with timestamp suffix
    - Add cleanup logic to delete logs exceeding MAX_LOG_FILES count
    - _Requirements: 5.3, 5.4_

- [ ] 3. Implement configuration management

  - [x] 3.1 Create configuration loading system

    - Write load_configuration() function to read from config file
    - Implement default value fallbacks for all configuration parameters
    - Add path expansion for tilde and environment variables
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 3.2 Implement command-line argument parsing
    - Write parse_arguments() function to handle ONLY destination and config file options
    - Implement help message display with show_help() function
    - Add version information display
    - Ensure CLI arguments override configuration file values
    - Remove ALL schedule-related command-line options (--schedule, --generate-plist, --schedule-time)
    - _Requirements: 9.2, 9.4, 9.6_

- [x] 4. Implement Homebrew detection and installation

  - [x] 4.1 Create Homebrew detection logic

    - Write check_homebrew() function to verify if Homebrew is installed
    - Check for brew command in PATH
    - Log detection results
    - _Requirements: 1.1_

  - [x] 4.2 Implement Homebrew installation
    - Write install_homebrew() function using official installation script
    - Add error handling for installation failures
    - Log installation progress and completion
    - Exit with error code if installation fails
    - _Requirements: 1.2, 1.3, 1.4_

- [x] 5. Implement Homebrew upgrade functionality

  - Write upgrade_homebrew() function to execute brew upgrade
  - Capture and log upgrade output
  - Handle upgrade failures gracefully (log error but continue)
  - Log summary of packages upgraded
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 6. Implement Brewfile generation and saving

  - [x] 6.1 Create Brewfile generation logic

    - Write generate_brewfile() function using brew bundle dump
    - Implement destination directory creation if it doesn't exist
    - Add error handling for generation failures
    - _Requirements: 3.1, 3.3_

  - [x] 6.2 Implement Brewfile saving
    - Write save_brewfile() function to write file to destination
    - Validate destination directory is writable
    - Log file path and timestamp after saving
    - Exit with error code if save fails
    - _Requirements: 3.2, 3.4, 3.5_

- [x] 7. Implement Git integration

  - [x] 7.1 Create Git repository detection

    - Write function to check if destination is a Git repository
    - Log warning if not a Git repository
    - _Requirements: 6.3_

  - [x] 7.2 Implement Git commit logic
    - Write commit_to_git() function to stage and commit Brewfile
    - Check if Brewfile has changes before committing
    - Skip commit if no changes detected
    - Create commit with descriptive message including timestamp
    - Handle commit failures gracefully (log but don't exit)
    - _Requirements: 6.1, 6.2, 6.4, 6.5, 6.6, 6.7_

- [x] 8. Implement main orchestration logic

  - Write main() function to coordinate all operations
  - Implement execution flow: parse args → load config → setup logging → check/install Homebrew → upgrade → generate Brewfile → save → commit → exit
  - Add error handling to distinguish critical vs non-critical failures
  - Implement proper exit codes (0 for success, non-zero for failures)
  - Log script start with version and timestamp
  - Ensure script exits immediately after completing all operations (no loops or waits)
  - Remove ALL plist generation logic from main() function
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.4, 9.1, 9.3, 9.5, 5.5, 10.8_

- [x] 9. Create installation script

  - [x] 9.1 Implement core installation logic

    - Write install.sh script with install_script() function
    - Copy brew-config.sh to installation location (~/bin or user-specified)
    - Create configuration directory and copy config.sh.example
    - Create log directory with proper permissions
    - _Requirements: 12.1, 12.2, 12.4_

  - [x] 9.2 Deploy pre-built application bundle

    - Write deploy_app_bundle() function to copy app bundle to ~/Applications/
    - Verify app bundle structure and permissions
    - Ensure wrapper executable is executable
    - _Requirements: 10.1, 10.2, 14.1, 14.5_

  - [x] 9.3 Generate launchd plist

    - Write generate_plist() function to create plist file
    - Configure plist to reference deployed app bundle executable path
    - Set default schedule time to 02:00
    - Save plist to ~/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist
    - _Requirements: 10.3, 10.4, 10.5, 14.6_

  - [x] 9.4 Add installation validation
    - Write verify_installation() function to check all files are in place
    - Validate script is executable
    - Validate app bundle is deployed correctly
    - Check directory permissions
    - Output installation locations to user
    - Provide instructions for loading plist
    - _Requirements: 10.6, 10.7, 12.3, 12.5_

- [x] 10. Create pre-built application bundle

  - [x] 10.1 Create application bundle structure

    - Create directory structure: Homebrew Config Automation.app/Contents/{MacOS,Resources}
    - Create wrapper executable script in MacOS directory
    - Make wrapper executable with proper permissions
    - _Requirements: 14.1, 14.5_

  - [x] 10.2 Create Info.plist

    - Write Info.plist with proper bundle metadata
    - Set CFBundleIdentifier to com.emkaytec.homebrewconfig
    - Set CFBundleDisplayName to "Homebrew Config Automation"
    - Configure LSUIElement and LSBackgroundOnly for background execution
    - Reference AppIcon in CFBundleIconFile
    - _Requirements: 14.2, 14.4_

  - [x] 10.3 Add icon to bundle
    - Copy AppIcon.icns to Resources directory
    - Verify icon file is in proper ICNS format
    - _Requirements: 14.3_

- [x] 11. Clean up brew-config.sh to be pure task runner

  - Remove generate_launchd_plist() function entirely
  - Remove GENERATE_PLIST and SCHEDULE_TIME global variables
  - Remove --generate-plist and --schedule-time from parse_arguments()
  - Remove --schedule option and SCHEDULE_PATTERN variable
  - Remove plist generation logic from main() function
  - Update show_help() to remove all scheduling-related options
  - Ensure main() function executes all operations in sequence and exits
  - Verify script exits with appropriate status code after completion
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 9.6, 10.8_

- [x] 13. Update comprehensive documentation

  - [x] 13.1 Update README.md with new architecture

    - Update installation instructions to reflect app bundle deployment
    - Remove references to --generate-plist option
    - Document that install.sh handles all setup including plist
    - Update usage examples to show brew-config.sh as pure task runner
    - _Requirements: 11.1, 11.2, 11.6_

  - [x] 13.2 Update scheduling documentation

    - Document that install.sh generates the plist automatically
    - Provide instructions for loading plist with launchctl
    - Document log file locations and rotation policy
    - Add troubleshooting section with common issues
    - Include configuration modification instructions
    - _Requirements: 11.3, 11.4, 11.5, 11.7, 11.8_

  - [x] 13.3 Update inline code documentation
    - Update function headers to reflect removed plist functions
    - Update show_help() documentation
    - Update comments in config.sh.example
    - _Requirements: 11.1, 11.2_

- [x] 14. Update test suite

  - [x] 14.1 Update unit tests

    - Update test-config.sh to remove schedule-related tests
    - Verify logging and rotation tests still work
    - _Requirements: 4.3, 5.1, 5.3_

  - [x] 14.2 Update integration tests

    - Verify test-homebrew.sh still works
    - Verify test-brewfile.sh still works
    - Verify test-git.sh still works
    - _Requirements: 1.1, 3.1, 6.1, 7.1_

  - [x] 14.3 Add installation tests
    - Create test for app bundle deployment
    - Create test for plist generation
    - Verify install.sh works correctly
    - _Requirements: 10.1, 10.2, 10.3_

- [x] 15. Final integration and validation

  - Test complete workflow on fresh macOS installation
  - Verify all configuration options work correctly
  - Test that install.sh deploys app bundle and generates plist correctly
  - Test multiple consecutive manual executions of brew-config.sh
  - Validate log rotation works as expected
  - Ensure Git commits are created only when Brewfile changes
  - Verify all error conditions are handled properly
  - Confirm brew-config.sh has no scheduling logic
  - Verify app bundle displays correctly in System Settings with icon
  - _Requirements: 12.6, 12.7, 12.8, 7.5, 8.1, 8.4, 10.7, 14.7_

- [x] 16. Create uninstall script

  - [x] 16.1 Implement core uninstallation logic

    - Write uninstall.sh script with unload_launchd() function to unload the launchd job
    - Write remove_app_bundle() function to remove application bundle from ~/Applications/
    - Write remove_plist() function to remove launchd plist from ~/Library/LaunchAgents/
    - Write remove_script() function to remove brew-config.sh from ~/bin/
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

  - [x] 16.2 Implement configuration and log cleanup

    - Write remove_config() function to remove ~/.config/homebrew-config/ directory
    - Write remove_logs() function to remove ~/.local/share/homebrew-config/ directory
    - Ensure Brewfile and destination directory are NOT removed
    - _Requirements: 16.6, 16.7, 16.8, 16.9_

  - [x] 16.3 Add uninstallation validation and reporting

    - Write verify_uninstallation() function to confirm all components are removed
    - Write display_summary() function to show what was removed
    - Add error handling to continue on failures and report them
    - _Requirements: 16.10, 16.11_

  - [ ]\* 16.4 Update documentation for uninstallation
    - Update README.md with uninstallation instructions
    - Document what is removed and what is preserved
    - Add troubleshooting for common uninstallation issues
    - _Requirements: 16.10_
