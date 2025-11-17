# Repository Guidelines

This repo automates Homebrew maintenance on macOS via portable Bash scripts and a lightweight app bundle. Follow these practices to keep automation predictable and production-safe.

## Project Structure & Module Organization
- Core automation lives in `brew-config.sh`; it orchestrates install, upgrade, Brewfile export, logging, and Git commits.
- Deployment helpers: `install.sh` schedules the job and installs artifacts, while `uninstall.sh` removes launch agents and scripts.
- Supporting assets include `config.sh.example` (user overrides), `Homebrew Config Automation.app` (launchd-friendly wrapper), and `AppIcon.icns`.
- Documentation is in `README.md` and AI assistant briefs in `CLAUDE.md`; keep new guidance alongside these references.

## Build, Test, and Development Commands
- `./brew-config.sh -d /tmp/test-config` runs the main workflow with a disposable destination to verify Brewfile generation and logging.
- `./install.sh --script-dir /tmp/test-install` validates installer flow without touching `/usr/local`.
- `./uninstall.sh --dry-run` exercises cleanup logic safely; use before changing uninstall semantics.

## Coding Style & Naming Conventions
- Bash scripts use `set -euo pipefail`, four-space indents, and lowercase `snake_case` functions with descriptive verbs (e.g., `setup_logging`).
- Prefer `readonly` for constants, `local` for function scope, and guard external commands with error handling/logging helpers.
- Keep config keys uppercase with underscores (e.g., `MAX_LOG_FILES`) and mirror defaults defined near the top of `brew-config.sh`.

## Testing Guidelines
- Smoke-test every change with the commands above plus targeted flag combinations (`-c custom/config.sh`, `--schedule-hour 2`).
- When touching logging or Git logic, inspect `~/.local/share/homebrew-config/logs/homebrew-config.log` and confirm Brewfile diffs.
- Name temporary dirs under `/tmp/homebrew-config-*` to avoid collisions and simplify cleanup.

## Commit & Pull Request Guidelines
- Follow existing history: short, imperative messages such as `Add uninstall script` or `Fix installation order`.
- Each PR should explain scope, mention affected scripts, reference any GitHub issues, and include screenshots only when UI assets change.
- Document new flags or config keys in both `README.md` and `config.sh.example`, and summarize manual test evidence in the PR body.

## Security & Configuration Tips
- Do not introduce dependencies outside macOS defaults or Homebrew core; scripts must run on fresh systems.
- Ensure generated files (config, logs) remain user-owned and mode `600`/`700` where applicable; avoid echoing secrets to stdout.
