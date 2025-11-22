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
# Main Entry Point (to be implemented in subsequent tasks)
# =============================================================================

def main():
    """Main entry point for the script."""
    print("Brewfile Backup - Authentication Module Implemented")
    print("Testing authentication...")

    try:
        token = GitHubAuth.get_token()
        print(f"✓ Authentication successful (token length: {len(token)})")
    except AuthenticationError as e:
        print(f"✗ Authentication failed:\n{e}")
        return EXIT_AUTH_ERROR

    return EXIT_SUCCESS


if __name__ == '__main__':
    # Set up basic logging for testing
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

    sys.exit(main())
