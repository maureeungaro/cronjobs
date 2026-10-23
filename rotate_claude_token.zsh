#!/bin/zsh

# Interactively rotate the long-lived Claude token the cron jobs rely on.
#
# `claude setup-token` can only run interactively (it opens a browser OAuth flow), so rotation
# cannot happen from cron. Run this by hand whenever make_weekly_report.zsh emails that the token
# is stale. It runs setup-token, extracts the resulting token from its output, and writes
# ~/.claude-cron.env in the correct `export CLAUDE_CODE_OAUTH_TOKEN=...` form at mode 600 -- which
# avoids the bare-paste mistake that silently breaks `source`.

set -u
setopt pipefail

env_file="$HOME/.claude-cron.env"

if ! command -v claude >/dev/null 2>&1; then
	print -r -- "Error: 'claude' CLI not found in PATH." >&2
	exit 1
fi

print -r -- "Launching 'claude setup-token' -- complete the browser login when prompted..."
print -r -- ""

# Run setup-token, mirror everything to the terminal so the login URL and prompts stay visible,
# and capture the output so the token can be pulled out of it. pipefail makes $? reflect claude's
# exit status rather than tee's.
raw="$(claude setup-token 2>&1 | tee /dev/tty)"
rc=$?
if (( rc != 0 )); then
	print -r -- "Error: 'claude setup-token' exited with status $rc; token not changed." >&2
	exit $rc
fi

# The token looks like sk-ant-oatNN-...; take the last such match in case setup-token printed other
# text alongside it.
token="$(print -r -- "$raw" | grep -oE 'sk-ant-oat[0-9]+-[A-Za-z0-9_-]+' | tail -1)"
if [[ -z "$token" ]]; then
	print -r -- "Error: no token (sk-ant-oat...) found in setup-token output; $env_file unchanged." >&2
	exit 1
fi

# Write the env file atomically at mode 600: build a temp file in $HOME, then move it into place.
tmp="$(mktemp "$HOME/.claude-cron.env.XXXXXX")" || {
	print -r -- "Error: mktemp failed; $env_file unchanged." >&2
	exit 1
}
chmod 600 "$tmp"
{
	print -r -- "# Long-lived token for headless \`claude\` runs from cron (sourced by make_weekly_report.zsh)."
	print -r -- "# Rotate with /opt/projects/cronjobs/rotate_claude_token.zsh. Mode 600; never commit (lives in \$HOME)."
	print -r -- "export CLAUDE_CODE_OAUTH_TOKEN=$token"
} >"$tmp"
mv "$tmp" "$env_file"
chmod 600 "$env_file"

print -r -- ""
print -r -- "Wrote $env_file (mode 600). Token rotated."
