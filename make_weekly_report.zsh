#!/bin/zsh

# Compile the week's daily journal entries into a toned-down public weekly report on the homepage.
# The generator lives in the journal repo; this launcher is invoked by cron through
# run_with_lock_and_log.zsh (which handles locking, logging, and error email).

# cron runs in a background session with no access to the macOS login Keychain, so the `claude`
# CLI cannot read its stored login and fails with "Not logged in". Supply a long-lived token
# instead: run `claude setup-token` once and put `export CLAUDE_CODE_OAUTH_TOKEN=...` in the file
# below (kept in $HOME, mode 600, never committed). Sourced only if present.
[[ -f "$HOME/.claude-cron.env" ]] && source "$HOME/.claude-cron.env"

/opt/projects/casetta/journal/make_weekly.py
