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
