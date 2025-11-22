#!/usr/bin/env python3
"""
Brewfile Backup Script

This script automatically backs up your Homebrew configuration (Brewfile) to a
private GitHub Gist. It's designed to run unattended on a schedule via launchd.

The script:
1. Authenticates with GitHub (via GitHub CLI or environment variable)
2. Generates a Brewfile from the current Homebrew installation
3. Detects if the Brewfile has changed since the last backup
4. Creates or updates a private GitHub Gist with the Brewfile
5. Stores configuration and state for subsequent runs

Author: Generated via Claude Code
License: MIT
"""

import argparse
import hashlib
import json
import logging
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

try:
    import requests
except ImportError:
    print("Error: 'requests' package not found. Install it with: pip3 install requests")
    sys.exit(1)


# =============================================================================
# Custom Exceptions
# =============================================================================

class AuthenticationError(Exception):
    """Raised when GitHub authentication fails."""
    pass


class BrewfileGenerationError(Exception):
    """Raised when Brewfile generation fails."""
    pass


class GistAPIError(Exception):
    """Raised when GitHub Gist API operations fail."""
    pass


class ConfigurationError(Exception):
    """Raised when configuration operations fail."""
    pass


# =============================================================================
# Exit Codes
# =============================================================================

EXIT_SUCCESS = 0           # Successful execution
EXIT_AUTH_ERROR = 1        # Authentication failed
EXIT_BREW_ERROR = 2        # Homebrew not available
EXIT_API_ERROR = 3         # GitHub API error
EXIT_CONFIG_ERROR = 4      # Configuration error
EXIT_UNKNOWN_ERROR = 99    # Unexpected error


# =============================================================================
# Authentication Module
# =============================================================================

class GitHubAuth:
    """
    Handles GitHub authentication for Gist API access.

    This class attempts to obtain a GitHub API token using two methods:
    1. GitHub CLI (gh) - preferred method, uses system keychain
    2. Environment variable (GITHUB_TOKEN) - fallback method

    The GitHub CLI method is preferred because it stores tokens securely in
    the system keychain and doesn't require manual token management.
    """

    @staticmethod
    def get_token() -> str:
        """
        Obtain GitHub API token for authentication.

        Tries authentication methods in order:
        1. GitHub CLI (gh auth token)
        2. GITHUB_TOKEN environment variable

        Returns:
            str: Valid GitHub API token

        Raises:
            AuthenticationError: If no valid authentication method is available

        Example:
            >>> token = GitHubAuth.get_token()
            >>> print(f"Token length: {len(token)}")
            Token length: 40
        """
        logging.debug("Attempting to obtain GitHub token")

        # Method 1: Try GitHub CLI (preferred)
        token = GitHubAuth._try_github_cli()
        if token:
            logging.info("Authenticated via GitHub CLI")
            return token

        # Method 2: Try environment variable (fallback)
        token = GitHubAuth._try_environment_variable()
        if token:
            logging.info("Authenticated via GITHUB_TOKEN environment variable")
            return token

        # No authentication method available
        error_msg = (
            "GitHub authentication failed. No valid token found.\n\n"
            "Please use one of the following methods:\n\n"
            "1. GitHub CLI (recommended):\n"
            "   gh auth login --scopes gist\n\n"
            "2. Environment variable:\n"
            "   export GITHUB_TOKEN='your_token_here'\n\n"
            "To create a token, visit:\n"
            "https://github.com/settings/tokens/new?scopes=gist&description=Brewfile+Backup"
        )
        raise AuthenticationError(error_msg)

    @staticmethod
    def _try_github_cli() -> Optional[str]:
        """
        Attempt to get token from GitHub CLI.

        This method:
        1. Checks if 'gh' command exists
        2. Verifies authentication status
        3. Extracts the token

        Returns:
            Optional[str]: Token if successful, None otherwise
        """
        # Check if gh command exists
        gh_path = shutil.which('gh')
        if not gh_path:
            logging.debug("GitHub CLI (gh) not found in PATH")
            return None

        logging.debug(f"Found GitHub CLI at: {gh_path}")

        # Check if gh is authenticated
        try:
            result = subprocess.run(
                ['gh', 'auth', 'status'],
                capture_output=True,
                text=True,
                timeout=5
            )

            # gh auth status returns 0 when authenticated
            if result.returncode != 0:
                logging.debug("GitHub CLI not authenticated")
                return None

            logging.debug("GitHub CLI is authenticated")

        except subprocess.TimeoutExpired:
            logging.warning("GitHub CLI auth status check timed out")
            return None
        except Exception as e:
            logging.debug(f"Error checking gh auth status: {e}")
            return None

        # Get the token
        try:
            result = subprocess.run(
                ['gh', 'auth', 'token'],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0 and result.stdout.strip():
                token = result.stdout.strip()
                logging.debug(f"Successfully obtained token from gh (length: {len(token)})")
                return token
            else:
                logging.debug("Failed to get token from gh auth token")
                return None

        except subprocess.TimeoutExpired:
            logging.warning("GitHub CLI auth token retrieval timed out")
            return None
        except Exception as e:
            logging.debug(f"Error getting token from gh: {e}")
            return None

    @staticmethod
    def _try_environment_variable() -> Optional[str]:
        """
        Attempt to get token from GITHUB_TOKEN environment variable.

        Returns:
            Optional[str]: Token if found and non-empty, None otherwise
        """
        token = os.environ.get('GITHUB_TOKEN', '').strip()

        if token:
            logging.debug(f"Found GITHUB_TOKEN in environment (length: {len(token)})")
            return token
        else:
            logging.debug("GITHUB_TOKEN environment variable not set or empty")
            return None


# =============================================================================
# Brewfile Generator Module
# =============================================================================

class BrewfileGenerator:
    """
    Handles generation of Brewfile from the current Homebrew installation.

    This class wraps the `brew bundle dump` command, which exports all
    installed Homebrew packages, casks, taps, and Mac App Store apps to
    a Brewfile format.

    The Brewfile can be used to recreate the same Homebrew environment
    on another machine or after a fresh install.
    """

    def __init__(self, output_dir: Path):
        """
        Initialize the Brewfile generator.

        Args:
            output_dir: Directory where temporary Brewfile will be created
        """
        self.output_dir = output_dir
        self.brewfile_path = output_dir / "Brewfile.tmp"

    def generate(self) -> Tuple[str, str]:
        """
        Generate Brewfile from current Homebrew installation.

        This method:
        1. Validates that Homebrew is installed
        2. Executes `brew bundle dump --force`
        3. Reads the generated Brewfile
        4. Calculates SHA-256 hash of the content
        5. Cleans up the temporary file

        Returns:
            Tuple[str, str]: (brewfile_content, sha256_hash)

        Raises:
            BrewfileGenerationError: If Homebrew is not available or generation fails

        Example:
            >>> generator = BrewfileGenerator(Path('/tmp'))
            >>> content, hash = generator.generate()
            >>> print(f"Generated {len(content)} bytes, hash: {hash[:8]}...")
            Generated 1234 bytes, hash: a1b2c3d4...
        """
        logging.debug("Starting Brewfile generation")

        # Step 1: Check if Homebrew is installed
        self._check_brew_installed()

        # Step 2: Generate the Brewfile
        self._run_brew_bundle_dump()

        # Step 3: Read the Brewfile content
        content = self._read_brewfile()

        # Step 4: Calculate hash
        content_hash = self._calculate_hash(content)

        # Step 5: Clean up temporary file
        self._cleanup()

        logging.info(f"Generated Brewfile: {len(content)} bytes, {len(content.splitlines())} lines")
        logging.debug(f"Brewfile hash: {content_hash}")

        return content, content_hash

    def _check_brew_installed(self) -> None:
        """
        Check if Homebrew is installed and accessible.

        Raises:
            BrewfileGenerationError: If Homebrew is not found
        """
        brew_path = shutil.which('brew')

        if not brew_path:
            error_msg = (
                "Homebrew not found. Please install Homebrew first:\n"
                "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n\n"
                "Common Homebrew locations:\n"
                "  - macOS Intel: /usr/local/bin/brew\n"
                "  - macOS Apple Silicon: /opt/homebrew/bin/brew\n\n"
                "Make sure Homebrew is in your PATH."
            )
            logging.error("Homebrew not found in PATH")
            raise BrewfileGenerationError(error_msg)

        logging.debug(f"Found Homebrew at: {brew_path}")

        # Verify brew is executable
        try:
            result = subprocess.run(
                ['brew', '--version'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0:
                version = result.stdout.strip().split('\n')[0]
                logging.debug(f"Homebrew version: {version}")
            else:
                raise BrewfileGenerationError(f"Homebrew check failed: {result.stderr}")

        except subprocess.TimeoutExpired:
            raise BrewfileGenerationError("Homebrew version check timed out")
        except Exception as e:
            raise BrewfileGenerationError(f"Error verifying Homebrew: {e}")

    def _run_brew_bundle_dump(self) -> None:
        """
        Execute `brew bundle dump` to generate the Brewfile.

        The --force flag overwrites any existing Brewfile at the output location.
        The --file flag specifies where to write the Brewfile.

        Raises:
            BrewfileGenerationError: If the command fails
        """
        # Ensure output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)

        logging.debug(f"Running brew bundle dump to: {self.brewfile_path}")

        try:
            # Run brew bundle dump
            # --force: Overwrite existing Brewfile
            # --file: Specify output location
            result = subprocess.run(
                ['brew', 'bundle', 'dump', '--force', f'--file={self.brewfile_path}'],
                capture_output=True,
                text=True,
                timeout=60  # Generous timeout for large installations
            )

            if result.returncode != 0:
                error_msg = f"brew bundle dump failed:\n{result.stderr}"
                logging.error(error_msg)
                raise BrewfileGenerationError(error_msg)

            logging.debug("brew bundle dump completed successfully")

            # Log any warnings or messages from brew
            if result.stdout.strip():
                logging.debug(f"brew output: {result.stdout.strip()}")
            if result.stderr.strip():
                logging.warning(f"brew stderr: {result.stderr.strip()}")

        except subprocess.TimeoutExpired:
            error_msg = "brew bundle dump timed out after 60 seconds"
            logging.error(error_msg)
            raise BrewfileGenerationError(error_msg)
        except Exception as e:
            error_msg = f"Unexpected error running brew bundle dump: {e}"
            logging.error(error_msg)
            raise BrewfileGenerationError(error_msg)

    def _read_brewfile(self) -> str:
        """
        Read the generated Brewfile.

        Returns:
            str: Contents of the Brewfile

        Raises:
            BrewfileGenerationError: If the file doesn't exist or can't be read
        """
        if not self.brewfile_path.exists():
            error_msg = f"Brewfile was not created at: {self.brewfile_path}"
            logging.error(error_msg)
            raise BrewfileGenerationError(error_msg)

        try:
            content = self.brewfile_path.read_text(encoding='utf-8')

            # Warn if Brewfile is empty
            if not content.strip():
                logging.warning("Generated Brewfile is empty (no packages installed?)")

            return content

        except Exception as e:
            error_msg = f"Error reading Brewfile: {e}"
            logging.error(error_msg)
            raise BrewfileGenerationError(error_msg)

    @staticmethod
    def _calculate_hash(content: str) -> str:
        """
        Calculate SHA-256 hash of the Brewfile content.

        This hash is used for change detection - we only upload to Gist
        if the hash differs from the previous backup.

        Args:
            content: Brewfile content to hash

        Returns:
            str: Hexadecimal SHA-256 hash
        """
        return hashlib.sha256(content.encode('utf-8')).hexdigest()

    def _cleanup(self) -> None:
        """
        Clean up temporary Brewfile.

        Removes the temporary Brewfile created during generation.
        Errors during cleanup are logged but don't raise exceptions.
        """
        try:
            if self.brewfile_path.exists():
                self.brewfile_path.unlink()
                logging.debug(f"Cleaned up temporary Brewfile: {self.brewfile_path}")
        except Exception as e:
            logging.warning(f"Failed to clean up temporary Brewfile: {e}")


# =============================================================================
# Gist Manager Module
# =============================================================================

class GistManager:
    """
    Manages GitHub Gist operations for Brewfile storage.

    This class handles creating and updating private GitHub Gists that
    store the Brewfile backup. It uses the GitHub REST API v3.

    GitHub Gists provide:
    - Version history (every update is a new revision)
    - Web-based viewing and downloading
    - Private visibility (not listed publicly)
    - Simple API for CRUD operations
    """

    # GitHub API base URL
    API_BASE = "https://api.github.com"

    # Default Gist settings
    GIST_DESCRIPTION = "Homebrew Brewfile Backup"
    GIST_FILENAME = "Brewfile"

    def __init__(self, token: str):
        """
        Initialize the Gist manager.

        Args:
            token: GitHub API token with 'gist' scope
        """
        self.token = token
        self.session = requests.Session()

        # Set up default headers for all requests
        self.session.headers.update({
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Brewfile-Backup/1.0'
        })

    def create_gist(self, content: str) -> Tuple[str, str]:
        """
        Create a new private Gist with the Brewfile content.

        Args:
            content: Brewfile content to upload

        Returns:
            Tuple[str, str]: (gist_id, gist_url)

        Raises:
            GistAPIError: If the API request fails

        Example:
            >>> manager = GistManager(token)
            >>> gist_id, url = manager.create_gist(brewfile_content)
            >>> print(f"Created Gist: {url}")
            Created Gist: https://gist.github.com/username/abc123...
        """
        logging.info("Creating new Gist")

        url = f"{self.API_BASE}/gists"

        payload = {
            "description": self.GIST_DESCRIPTION,
            "public": False,  # Create as private Gist
            "files": {
                self.GIST_FILENAME: {
                    "content": content
                }
            }
        }

        try:
            response = self.session.post(url, json=payload, timeout=30)

            # Check for successful creation (HTTP 201 Created)
            if response.status_code == 201:
                data = response.json()
                gist_id = data['id']
                gist_url = data['html_url']

                logging.info(f"Created Gist: {gist_id}")
                logging.debug(f"Gist URL: {gist_url}")

                return gist_id, gist_url

            else:
                self._handle_api_error(response, "create Gist")

        except requests.exceptions.Timeout:
            error_msg = "Request to create Gist timed out after 30 seconds"
            logging.error(error_msg)
            raise GistAPIError(error_msg)
        except requests.exceptions.RequestException as e:
            error_msg = f"Network error while creating Gist: {e}"
            logging.error(error_msg)
            raise GistAPIError(error_msg)

    def update_gist(self, gist_id: str, content: str) -> None:
        """
        Update an existing Gist with new Brewfile content.

        This creates a new revision in the Gist's history. All previous
        versions remain accessible through the Gist's revision history.

        Args:
            gist_id: ID of the Gist to update
            content: New Brewfile content

        Raises:
            GistAPIError: If the API request fails

        Example:
            >>> manager = GistManager(token)
            >>> manager.update_gist('abc123...', new_content)
        """
        logging.info(f"Updating Gist: {gist_id}")

        url = f"{self.API_BASE}/gists/{gist_id}"

        payload = {
            "files": {
                self.GIST_FILENAME: {
                    "content": content
                }
            }
        }

        try:
            response = self.session.patch(url, json=payload, timeout=30)

            # Check for successful update (HTTP 200 OK)
            if response.status_code == 200:
                logging.info("Gist updated successfully")
                logging.debug(f"Response status: {response.status_code}")
            else:
                self._handle_api_error(response, "update Gist")

        except requests.exceptions.Timeout:
            error_msg = f"Request to update Gist {gist_id} timed out after 30 seconds"
            logging.error(error_msg)
            raise GistAPIError(error_msg)
        except requests.exceptions.RequestException as e:
            error_msg = f"Network error while updating Gist: {e}"
            logging.error(error_msg)
            raise GistAPIError(error_msg)

    def gist_exists(self, gist_id: str) -> bool:
        """
        Check if a Gist exists and is accessible.

        This is useful to verify that a stored Gist ID is still valid.
        The Gist might not exist if it was deleted or if the token
        doesn't have access to it.

        Args:
            gist_id: ID of the Gist to check

        Returns:
            bool: True if Gist exists and is accessible, False otherwise

        Example:
            >>> manager = GistManager(token)
            >>> if manager.gist_exists('abc123...'):
            ...     print("Gist exists")
            ... else:
            ...     print("Gist not found, will create new one")
        """
        logging.debug(f"Checking if Gist exists: {gist_id}")

        url = f"{self.API_BASE}/gists/{gist_id}"

        try:
            response = self.session.get(url, timeout=30)

            if response.status_code == 200:
                logging.debug("Gist exists and is accessible")
                return True
            elif response.status_code == 404:
                logging.debug("Gist not found (may have been deleted)")
                return False
            else:
                # For other errors (403, 401, etc.), log but return False
                # This allows the script to create a new Gist instead of failing
                logging.warning(
                    f"Unexpected status checking Gist: {response.status_code}"
                )
                return False

        except requests.exceptions.Timeout:
            logging.warning("Request to check Gist timed out")
            return False
        except requests.exceptions.RequestException as e:
            logging.warning(f"Error checking if Gist exists: {e}")
            return False

    def _handle_api_error(self, response: requests.Response, operation: str) -> None:
        """
        Handle GitHub API error responses.

        Provides detailed error messages based on HTTP status codes.

        Args:
            response: The failed response object
            operation: Description of the operation that failed

        Raises:
            GistAPIError: Always raises with a descriptive error message
        """
        status_code = response.status_code

        # Try to extract error message from response
        try:
            error_data = response.json()
            api_message = error_data.get('message', 'No error message provided')
        except Exception:
            api_message = response.text[:200] if response.text else 'No response body'

        # Build detailed error message based on status code
        if status_code == 401:
            error_msg = (
                f"Authentication failed ({status_code}): {api_message}\n\n"
                "Your GitHub token may be invalid or expired.\n"
                "Please re-authenticate:\n"
                "  gh auth login --scopes gist\n"
                "Or generate a new token at:\n"
                "  https://github.com/settings/tokens"
            )
        elif status_code == 403:
            error_msg = (
                f"Permission denied ({status_code}): {api_message}\n\n"
                "Your token may not have the 'gist' scope.\n"
                "Please re-authenticate with the correct scope:\n"
                "  gh auth login --scopes gist"
            )
        elif status_code == 404:
            error_msg = (
                f"Gist not found ({status_code}): {api_message}\n\n"
                "The Gist may have been deleted.\n"
                "A new Gist will be created on the next run."
            )
        elif status_code == 422:
            error_msg = (
                f"Validation failed ({status_code}): {api_message}\n\n"
                "The request data was invalid."
            )
        elif status_code == 429:
            error_msg = (
                f"Rate limit exceeded ({status_code}): {api_message}\n\n"
                "GitHub API rate limit reached.\n"
                "Please try again later."
            )
        elif status_code >= 500:
            error_msg = (
                f"GitHub server error ({status_code}): {api_message}\n\n"
                "GitHub's servers are experiencing issues.\n"
                "Please try again later."
            )
        else:
            error_msg = (
                f"Failed to {operation} ({status_code}): {api_message}"
            )

        logging.error(error_msg)
        raise GistAPIError(error_msg)


# =============================================================================
# Configuration Manager Module
# =============================================================================

class ConfigManager:
    """
    Manages persistent configuration and state.

    This class handles reading and writing configuration data to a JSON file
    stored in the user's config directory. The configuration stores:
    - Gist ID (for subsequent updates)
    - Last backup hash (for change detection)
    - Last backup timestamp
    - Gist URL (for user reference)

    The configuration follows XDG Base Directory specification and is stored
    at: ~/.config/brewfile-backup/config.json
    """

    def __init__(self, config_dir: Optional[Path] = None):
        """
        Initialize the configuration manager.

        Args:
            config_dir: Override default config directory (mainly for testing)
        """
        if config_dir:
            self.config_dir = config_dir
        else:
            # Default: ~/.config/brewfile-backup/
            self.config_dir = Path.home() / ".config" / "brewfile-backup"

        self.config_file = self.config_dir / "config.json"

        # Ensure config directory exists with proper permissions
        self._ensure_config_dir()

    def load(self) -> dict:
        """
        Load configuration from file.

        If the configuration file doesn't exist or is invalid, returns
        an empty configuration dictionary.

        Returns:
            dict: Configuration data with keys:
                - gist_id (str): GitHub Gist ID
                - last_hash (str): SHA-256 hash of last backup
                - last_backup (str): ISO 8601 timestamp
                - gist_url (str): URL to view the Gist

        Example:
            >>> config = ConfigManager().load()
            >>> if 'gist_id' in config:
            ...     print(f"Using existing Gist: {config['gist_id']}")
            ... else:
            ...     print("No previous backup found")
        """
        if not self.config_file.exists():
            logging.debug("No existing configuration file found")
            return {}

        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)

            logging.debug(f"Loaded configuration from {self.config_file}")

            # Validate configuration structure
            if not isinstance(config, dict):
                logging.warning("Configuration file is not a valid dictionary, returning empty config")
                return {}

            return config

        except json.JSONDecodeError as e:
            logging.warning(f"Configuration file is corrupted (invalid JSON): {e}")
            logging.warning("Starting with empty configuration")
            return {}
        except Exception as e:
            logging.warning(f"Error reading configuration file: {e}")
            return {}

    def save(self, config: dict) -> None:
        """
        Save configuration to file.

        Writes the configuration atomically by first writing to a temporary
        file and then renaming it. This prevents corruption if the script
        is interrupted during writing.

        Args:
            config: Configuration dictionary to save

        Raises:
            ConfigurationError: If saving fails

        Example:
            >>> manager = ConfigManager()
            >>> config = {
            ...     'gist_id': 'abc123',
            ...     'last_hash': 'def456',
            ...     'last_backup': '2025-11-22T02:00:00Z'
            ... }
            >>> manager.save(config)
        """
        # Ensure config directory exists
        self._ensure_config_dir()

        # Write to temporary file first (atomic write)
        temp_file = self.config_file.with_suffix('.tmp')

        try:
            with open(temp_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
                # Ensure data is written to disk
                f.flush()
                os.fsync(f.fileno())

            # Atomic rename (POSIX guarantees atomicity)
            temp_file.replace(self.config_file)

            # Set restrictive permissions (owner read/write only)
            os.chmod(self.config_file, 0o600)

            logging.debug(f"Saved configuration to {self.config_file}")

        except Exception as e:
            error_msg = f"Failed to save configuration: {e}"
            logging.error(error_msg)

            # Clean up temp file if it exists
            if temp_file.exists():
                try:
                    temp_file.unlink()
                except Exception:
                    pass

            raise ConfigurationError(error_msg)

    def update(self, **kwargs) -> dict:
        """
        Update configuration with new values.

        This is a convenience method that loads the current config,
        updates it with the provided values, and saves it back.

        Args:
            **kwargs: Configuration values to update

        Returns:
            dict: Updated configuration

        Example:
            >>> manager = ConfigManager()
            >>> config = manager.update(
            ...     gist_id='abc123',
            ...     last_hash='def456',
            ...     last_backup=datetime.utcnow().isoformat() + 'Z'
            ... )
        """
        config = self.load()
        config.update(kwargs)
        self.save(config)
        return config

    def _ensure_config_dir(self) -> None:
        """
        Ensure configuration directory exists with proper permissions.

        Creates the directory if it doesn't exist. Sets permissions to
        755 (rwxr-xr-x) for the directory.

        Raises:
            ConfigurationError: If directory creation fails
        """
        try:
            self.config_dir.mkdir(parents=True, exist_ok=True)

            # Set directory permissions (owner rwx, group rx, other rx)
            os.chmod(self.config_dir, 0o755)

            logging.debug(f"Configuration directory: {self.config_dir}")

        except Exception as e:
            error_msg = f"Failed to create configuration directory {self.config_dir}: {e}"
            logging.error(error_msg)
            raise ConfigurationError(error_msg)

    def get_log_file(self) -> Path:
        """
        Get the path to the log file.

        The log file is stored in the same directory as the config file.

        Returns:
            Path: Path to backup.log
        """
        return self.config_dir / "backup.log"


# =============================================================================
# Logger Setup
# =============================================================================

def setup_logging(log_file: Path, verbose: bool = False) -> None:
    """
    Configure logging for the script.

    Sets up two handlers:
    1. File handler: Logs to backup.log with INFO level
    2. Stream handler: Logs to stderr (captured by launchd)

    Args:
        log_file: Path to the log file
        verbose: If True, set log level to DEBUG

    The log format includes timestamp, level, and message.
    File handler rotates automatically via external tools (newsyslog).
    """
    log_level = logging.DEBUG if verbose else logging.INFO

    # Create formatters
    file_formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    stream_formatter = logging.Formatter(
        '%(levelname)s - %(message)s'
    )

    # File handler - writes to backup.log
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setLevel(log_level)
    file_handler.setFormatter(file_formatter)

    # Stream handler - writes to stderr (captured by launchd)
    stream_handler = logging.StreamHandler(sys.stderr)
    stream_handler.setLevel(log_level)
    stream_handler.setFormatter(stream_formatter)

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(stream_handler)

    logging.debug(f"Logging configured: level={logging.getLevelName(log_level)}, file={log_file}")


# =============================================================================
# Main Backup Logic
# =============================================================================

def run_backup(force: bool = False, dry_run: bool = False) -> int:
    """
    Execute the backup process.

    This is the main orchestration function that:
    1. Authenticates with GitHub
    2. Generates the Brewfile
    3. Checks if content has changed (unless --force)
    4. Creates or updates the Gist
    5. Saves configuration

    Args:
        force: If True, upload even if content hasn't changed
        dry_run: If True, generate Brewfile but skip upload

    Returns:
        int: Exit code (0 for success, non-zero for errors)
    """
    logging.info("=" * 60)
    logging.info("Starting Brewfile backup")
    logging.info("=" * 60)

    try:
        # Initialize configuration manager
        config_manager = ConfigManager()
        config = config_manager.load()

        # Step 1: Authenticate with GitHub
        logging.info("Step 1/4: Authenticating with GitHub")
        try:
            token = GitHubAuth.get_token()
        except AuthenticationError as e:
            logging.error(f"Authentication failed:\n{e}")
            return EXIT_AUTH_ERROR

        # Step 2: Generate Brewfile
        logging.info("Step 2/4: Generating Brewfile")
        try:
            generator = BrewfileGenerator(config_manager.config_dir)
            content, current_hash = generator.generate()
        except BrewfileGenerationError as e:
            logging.error(f"Brewfile generation failed:\n{e}")
            return EXIT_BREW_ERROR

        # Step 3: Check if content has changed
        logging.info("Step 3/4: Checking for changes")
        last_hash = config.get('last_hash')

        if not force and last_hash == current_hash:
            logging.info("Content unchanged since last backup (hash matches)")
            logging.info("Skipping upload (use --force to upload anyway)")
            logging.info("Backup completed successfully (no changes)")
            return EXIT_SUCCESS

        if last_hash:
            logging.info("Content has changed, proceeding with upload")
        else:
            logging.info("No previous backup found, creating new Gist")

        if dry_run:
            logging.info("Dry run mode: Skipping upload")
            logging.info(f"Would upload {len(content)} bytes ({len(content.splitlines())} lines)")
            logging.info(f"Current hash: {current_hash}")
            return EXIT_SUCCESS

        # Step 4: Upload to Gist
        logging.info("Step 4/4: Uploading to GitHub Gist")
        gist_manager = GistManager(token)

        try:
            gist_id = config.get('gist_id')

            # Check if we have a Gist ID and if it still exists
            if gist_id and gist_manager.gist_exists(gist_id):
                # Update existing Gist
                logging.info(f"Updating existing Gist: {gist_id}")
                gist_manager.update_gist(gist_id, content)
                gist_url = config.get('gist_url', f"https://gist.github.com/{gist_id}")
            else:
                # Create new Gist
                if gist_id:
                    logging.warning(f"Previous Gist {gist_id} not found, creating new one")

                logging.info("Creating new Gist")
                gist_id, gist_url = gist_manager.create_gist(content)

            # Save configuration
            config_manager.update(
                gist_id=gist_id,
                gist_url=gist_url,
                last_hash=current_hash,
                last_backup=datetime.utcnow().isoformat() + 'Z'
            )

            logging.info("=" * 60)
            logging.info("Backup completed successfully!")
            logging.info(f"Gist ID: {gist_id}")
            logging.info(f"Gist URL: {gist_url}")
            logging.info(f"Size: {len(content)} bytes ({len(content.splitlines())} lines)")
            logging.info(f"Hash: {current_hash}")
            logging.info("=" * 60)

            return EXIT_SUCCESS

        except GistAPIError as e:
            logging.error(f"Gist API error:\n{e}")
            return EXIT_API_ERROR

    except ConfigurationError as e:
        logging.error(f"Configuration error:\n{e}")
        return EXIT_CONFIG_ERROR
    except Exception as e:
        logging.error(f"Unexpected error: {e}", exc_info=True)
        return EXIT_UNKNOWN_ERROR


# =============================================================================
# Main Entry Point
# =============================================================================

def main():
    """Main entry point for the script."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Backup Homebrew Brewfile to GitHub Gist',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    Run backup (scheduled mode)
  %(prog)s --verbose          Run with debug logging
  %(prog)s --force            Force upload even if unchanged
  %(prog)s --dry-run          Generate Brewfile but skip upload

Configuration:
  Config file: ~/.config/brewfile-backup/config.json
  Log file:    ~/.config/brewfile-backup/backup.log

Authentication:
  Preferred: gh auth login --scopes gist
  Fallback:  export GITHUB_TOKEN='your_token'
        """
    )

    parser.add_argument(
        '--force',
        action='store_true',
        help='Force upload even if content is unchanged'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Generate Brewfile but skip upload to Gist'
    )

    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose (debug) logging'
    )

    args = parser.parse_args()

    # Set up logging
    config_manager = ConfigManager()
    log_file = config_manager.get_log_file()

    try:
        setup_logging(log_file, verbose=args.verbose)
    except Exception as e:
        print(f"Error setting up logging: {e}", file=sys.stderr)
        return EXIT_CONFIG_ERROR

    # Run the backup
    return run_backup(force=args.force, dry_run=args.dry_run)


if __name__ == '__main__':
    sys.exit(main())
