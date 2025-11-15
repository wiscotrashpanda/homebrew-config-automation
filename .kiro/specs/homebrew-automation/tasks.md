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

- [x] 3. Implement configuration management

  - [x] 3.1 Create configuration loading system

    - Write load_configuration() function to read from config file
    - Implement default value fallbacks for all configuration parameters
    - Add path expansion for tilde and environment variables
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 3.2 Implement command-line argument parsing
    - Write parse_arguments() function to handle all CLI options
    - Implement help message display with show_help() function
    - Add version information display
    - Ensure CLI arguments override configuration file values
    - Remove any schedule-related command-line options
    - _Requirements: 9.2, 9.4_

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
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.4, 9.1, 9.3, 9.5, 5.5_

- [x] 9. Create installation script

  - [x] 9.1 Implement core installation logic

    - Write install.sh script with install_script() function
    - Copy brew-config.sh to installation location (~/bin or user-specified)
    - Create configuration directory and copy config.sh.example
    - Create log directory with proper permissions
    - Note: Scheduling setup is left to the user (documented in README)
    - _Requirements: 11.1, 11.2, 11.4_

  - [x] 9.2 Add installation validation
    - Write verify_installation() function to check all files are in place
    - Validate script is executable
    - Check directory permissions
    - Output installation locations to user
    - _Requirements: 11.3, 11.5_

- [x] 10. Implement launchd plist generation

  - [x] 10.1 Create plist generation function

    - Write generate_launchd_plist() function to create plist file
    - Parse --schedule-time argument to extract hour and minute
    - Use script's actual installation path in plist
    - Save plist to ~/Library/LaunchAgents/com.user.homebrew-config.plist
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 10.2 Add plist generation workflow
    - Check for --generate-plist flag in parse_arguments()
    - When flag is present, call generate_launchd_plist() and exit
    - Display instructions for loading plist with launchctl
    - Do not execute normal operations when generating plist
    - _Requirements: 10.5, 10.6, 10.7_

- [x] 11. Verify single-run execution model

  - Ensure main() function executes all operations in sequence and exits
  - Remove any loops, sleep statements, or timing mechanisms
  - Verify script exits with appropriate status code after completion
  - Test that script can be invoked multiple times without conflicts
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 12. Create comprehensive documentation

  - [x] 12.1 Write README.md with all required sections

    - Add overview and prerequisites sections
    - Write detailed installation instructions
    - Document all configuration parameters with defaults
    - Add usage examples for common scenarios
    - _Requirements: 11.1, 11.2, 11.6_

  - [x] 12.2 Add scheduling and troubleshooting documentation

    - Document --generate-plist option and usage
    - Provide instructions for loading plist with launchctl
    - Provide example cron entry as alternative
    - Document log file locations and rotation policy
    - Add troubleshooting section with common issues
    - Include configuration modification instructions
    - _Requirements: 11.3, 11.4, 11.5, 11.7, 11.8_

  - [x] 12.3 Add inline code documentation
    - Add function headers with descriptions and parameters
    - Comment complex logic sections
    - Document error messages with actionable guidance
    - Add comments to config.sh.example explaining each option
    - _Requirements: 11.1, 11.2_

- [x] 13. Create test suite

  - [x] 13.1 Write unit tests for core functions

    - Create test-config.sh for configuration loading tests
    - Create test-logging.sh for logging and rotation tests
    - Test path expansion and validation logic
    - _Requirements: 4.3, 5.1, 5.3_

  - [x] 13.2 Write integration tests

    - Create test-homebrew.sh for Homebrew detection and installation
    - Create test-brewfile.sh for Brewfile generation and saving
    - Create test-git.sh for Git integration
    - Test error handling for critical and non-critical failures
    - _Requirements: 1.1, 3.1, 6.1, 7.1_

  - [x] 13.3 Create test runner and cleanup
    - Write run-all-tests.sh to execute all test scripts
    - Implement test environment setup and teardown
    - Add test artifact cleanup
    - _Requirements: 13.3_

- [x] 14. Implement --generate-plist command-line option

  - [x] 14.1 Add --generate-plist flag to parse_arguments()

    - Add new command-line option to accept --generate-plist flag
    - Add --schedule-time HH:MM option to specify schedule time (default: 02:00)
    - Update show_help() to document the new options
    - _Requirements: 10.1, 10.2, 10.4_

  - [x] 14.2 Create generate_launchd_plist() function

    - Write function to generate launchd plist XML content
    - Parse --schedule-time argument to extract hour and minute
    - Use script's actual installation path in plist (use $0 or BASH_SOURCE)
    - Save plist to ~/Library/LaunchAgents/com.user.homebrew-config.plist
    - Include StandardOutPath and StandardErrorPath for launchd logs
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 14.3 Integrate plist generation into main workflow

    - Check for --generate-plist flag in main() function
    - When flag is present, call generate_launchd_plist() and exit
    - Display instructions for loading plist with launchctl
    - Do not execute normal operations when generating plist
    - Exit with status code 0 after successful generation
    - _Requirements: 10.5, 10.6, 10.7_

  - [x] 14.4 Update documentation for --generate-plist
    - Update README.md with --generate-plist usage examples
    - Document the --schedule-time option
    - Provide clear instructions for loading the generated plist
    - Add troubleshooting section for plist generation
    - _Requirements: 11.1, 11.2, 11.3_

- [ ] 15. Final integration and validation
  - Test complete workflow on fresh macOS installation
  - Verify all configuration options work correctly
  - Test --generate-plist option and verify plist file is correct
  - Test multiple consecutive manual executions
  - Validate log rotation works as expected
  - Ensure Git commits are created only when Brewfile changes
  - Verify all error conditions are handled properly
  - Confirm script exits cleanly after each run
  - _Requirements: 12.6, 12.7, 12.8, 7.5, 8.1, 8.4, 10.1, 10.7_
