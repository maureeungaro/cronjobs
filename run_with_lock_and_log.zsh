#!/bin/zsh

set -u

# cronjob sends an email whenever there is a stdout or stderr
# in this script:
# - usage error in the wrapper: emailed
# - missing or non-executable target script: emailed
# - cannot create log dir or temp file: emailed
# - wrapped script returns nonzero other than 1: emailed
# - wrapped script succeeds: no email
# - lock busy (flock -n returns 1): no email, only log entry

# cleanup() removes the temporary stderr capture file if it was created.
# This avoids leaving stale files behind after the wrapper exits.
cleanup() {
	[ -n "${errfile:-}" ] && [ -f "$errfile" ] && rm -f "$errfile"
}

# trap tells the shell to run cleanup() when the script exits normally
# or when it receives one of these signals:
#   EXIT : shell is exiting for any reason
#   INT  : interrupt signal (for example Ctrl-C)
#   TERM : termination signal
# This ensures the temporary file is removed even if the script is interrupted.
trap cleanup EXIT INT TERM

# Require at least one argument: the script to run under flock protection.
# Writing to stderr here is intentional so cron will email on wrapper misuse.
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 /full/path/to/script [args ...]" >&2
	exit 2
fi

# First argument is the target script. Any remaining arguments are passed to it.
script="$1"
shift

# Fail early if the target script does not exist.
# This goes to stderr, so cron will email it.
if [ ! -f "$script" ]; then
	echo "Error: script '$script' does not exist" >&2
	exit 2
fi

# Fail early if the target script exists but is not executable.
# This goes to stderr, so cron will email it.
if [ ! -x "$script" ]; then
	echo "Error: script '$script' is not executable" >&2
	exit 2
fi

# Extract a base name from the script path.
# Example:
#   /home/me/cronjobs/osg_fairshare.zsh
# becomes:
#   script_name = osg_fairshare.zsh
#   script_base = osg_fairshare
script_name="${script:t}"
script_base="${script_name:r}"

# Build lock and log paths automatically from the target script name.
# For osg_fairshare.zsh, these become:
#   lockfile = ~/.osg_fairshare.lock
#   logfile  = ~/cronjobs/logs/osg_fairshare.log
lockfile="$HOME/.${script_base}.lock"
logdir="$HOME/cronjobs/logs"
logfile="$logdir/${script_base}.log"

# Ensure the common log directory exists.
# Error goes to stderr, so cron will email it.
mkdir -p "$logdir" || {
	echo "Error: cannot create log directory '$logdir'" >&2
	exit 2
}

# Create a temporary file to capture stderr from the wrapped script.
# If mktemp fails, write to stderr so cron emails it.
errfile=$(mktemp) || {
	echo "Error: mktemp failed" >&2
	exit 2
}

# Run the target script under a non-blocking flock lock.
#
# flock -n behavior:
#   - if lock is acquired, run the target script
#   - if lock is already held elsewhere, return immediately with rc=1
#
# Redirections:
#   > /dev/null   : discard normal stdout from the wrapped script
#   2> "$errfile" : capture wrapped script stderr into a temp file
#
# Email effect:
#   - success produces no stdout/stderr from this wrapper -> no cron email
#   - lock busy is handled below by appending to a log file -> no cron email
#   - real failure is re-emitted to stderr below -> cron email
flock -n "$lockfile" "$script" "$@" > /dev/null 2> "$errfile"
rc=$?

# rc=0 means the wrapped script ran successfully.
# We print nothing, so cron sends no email.
if [ "$rc" -eq 0 ]; then
	exit 0
fi

# rc=1 from flock -n means lock busy in this usage.
# We write a log entry but print nothing to stdout/stderr,
# so cron sends no email.
if [ "$rc" -eq 1 ]; then
	echo "$(date) ${script_base} skipped: lock busy" >> "$logfile"
	exit 0
fi

# Any other nonzero rc is treated as a real failure.
# We intentionally write to stderr so cron will email it.
echo "$(date) ${script_base} failed with exit code $rc" >&2

# If the wrapped script produced stderr, include it in the email body.
# This is useful for diagnosing the failure from the cron email itself.
if [ -s "$errfile" ]; then
	echo "----- ${script_base} stderr begin -----" >&2
	cat "$errfile" >&2
	echo "----- ${script_base} stderr end -----" >&2
fi

# Preserve the wrapped script exit code.
exit "$rc"