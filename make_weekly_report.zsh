#!/bin/zsh

# Compile the week's daily journal entries into a toned-down public weekly report on the homepage.
# The generator lives in the journal repo; this launcher is invoked by cron through
# run_with_lock_and_log.zsh (which handles locking, logging, and error email).

# cron runs in a background session with no access to the macOS login Keychain, so the `claude`
# CLI cannot read its stored login and fails with "Not logged in". Supply a long-lived token
# instead: rotate it with ./rotate_claude_token.zsh (or run `claude setup-token` by hand) so the
# file below holds `export CLAUDE_CODE_OAUTH_TOKEN=...` (kept in $HOME, mode 600, never committed).
# Sourced only if present.
env_file="$HOME/.claude-cron.env"
[[ -f "$env_file" ]] && source "$env_file"

# Generate the weekly report. Its exit status is what cron ultimately cares about.
/opt/projects/casetta/journal/make_weekly.py
report_rc=$?

# Long-lived tokens from `claude setup-token` expire after roughly a year, and cron cannot rotate
# them unattended (setup-token is an interactive browser flow). Nag by email once the token file is
# older than the threshold so rotation never lapses silently: mtime is a proxy for "last rotated",
# since the opaque token carries no readable expiry. Override the window with
# CLAUDE_TOKEN_MAX_AGE_DAYS if needed.
token_max_age_days="${CLAUDE_TOKEN_MAX_AGE_DAYS:-300}"
if [[ -f "$env_file" ]]; then
	token_mtime=$(stat -f %m "$env_file" 2>/dev/null)
	if [[ -n "$token_mtime" ]]; then
		token_age_days=$(( ( $(date +%s) - token_mtime ) / 86400 ))
		if (( token_age_days >= token_max_age_days )); then
			# Emit to stderr and force a nonzero exit so run_with_lock_and_log.zsh emails the
			# reminder. The report already ran above; a failing report takes precedence over the nag.
			print -r -- "Claude cron token is ${token_age_days} days old (>= ${token_max_age_days})." >&2
			print -r -- "Rotate it: run /opt/projects/cronjobs/rotate_claude_token.zsh" >&2
			(( report_rc == 0 )) && report_rc=3
		fi
	fi
fi

exit $report_rc
