#!/bin/zsh

set -u

# cronjob sends an email whenever there is stdout or stderr
# in this script:
# - usage error in the wrapper: emailed
# - missing or non-executable target script: emailed
# - cannot create log dir or temp file: emailed
# - wrapped script returns nonzero other than 1: emailed
# - wrapped script succeeds: no email
# - lock busy (flock -n returns 1): no email, only log entry
#
# Additional behavior:
# - log files are timestamped
# - wrapped script stderr is written to the log file
# - log files older than 2 weeks are removed automatically

cleanup() {
	[ -n "${errfile:-}" ] && [ -f "$errfile" ] && rm -f "$errfile"
}

trap cleanup EXIT INT TERM

# Require at least one argument: the script to run under flock protection.
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 /full/path/to/script [args ...]" >&2
	exit 2
fi

# First argument is the target script. Any remaining arguments are passed to it.
script="$1"
shift

# Fail early if the target script does not exist.
if [ ! -f "$script" ]; then
	echo "Error: script '$script' does not exist" >&2
	exit 2
fi

# Fail early if the target script exists but is not executable.
if [ ! -x "$script" ]; then
	echo "Error: script '$script' is not executable" >&2
	exit 2
fi

# Extract a base name from the script path.
script_name="${script:t}"
script_base="${script_name:r}"

# Build lock and log paths automatically from the target script name.
lockfile="$HOME/.${script_base}.lock"
logdir="$HOME/cronjobs/logs"

# Timestamped log file, for example:
#   ~/cronjobs/logs/osg_fairshare-20260318-142530.log
timestamp="$(date '+%Y%m%d-%H%M%S')"
logfile="$logdir/${script_base}-${timestamp}.log"

# Ensure the common log directory exists.
mkdir -p "$logdir" || {
	echo "Error: cannot create log directory '$logdir'" >&2
	exit 2
}

# Remove matching log files older than 2 weeks.
# -mtime +13 means strictly older than 14 days.
find "$logdir" -type f -name "${script_base}-*.log" -mtime +13 -delete 2>/dev/null

# Create a temporary file to capture stderr from the wrapped script.
errfile=$(mktemp) || {
	echo "Error: mktemp failed" >&2
	exit 2
}

# Helper: append wrapped-script stderr to the current log file, if any.
append_stderr_to_log() {
	if [ -s "$errfile" ]; then
		{
			echo "----- ${script_base} stderr begin -----"
			cat "$errfile"
			echo "----- ${script_base} stderr end -----"
		} >> "$logfile"
	fi
}

# Run the target script under a non-blocking flock lock.
#
# Redirections:
#   > /dev/null   : discard normal stdout from the wrapped script
#   2> "$errfile" : capture wrapped script stderr into a temp file
flock -n -E 75 "$lockfile" "$script" "$@" > /dev/null 2> "$errfile"
rc=$?

# rc=0 means the wrapped script ran successfully.
# We still save any wrapped-script stderr to the log file,
# but we print nothing, so cron sends no email.
if [ "$rc" -eq 0 ]; then
	if [ -s "$errfile" ]; then
		{
			echo "===== wrapped script stderr ====="
			echo "date:    $(date)"
			echo "machine: $(hostname)"
			echo "script:  $script"
			echo "rc:      $rc"
			echo "================================="
		} >> "$logfile"
		append_stderr_to_log
	fi
	exit 0
fi

# rc=1 from flock -n means lock busy in this usage.
# We write a log entry but print nothing to stdout/stderr,
# so cron sends no email.
if [ "$rc" -eq 75 ]; then
	{
		echo "===== lock busy ====="
		echo "date:    $(date)"
		echo "machine: $(hostname)"
		echo "script:  $script"
		echo "message: ${script_base} skipped: lock busy"
		echo "====================="
	} >> "$logfile"
	exit 0
fi

# Any other nonzero rc is treated as a real failure.
# We write details to the timestamped log file
# and also to stderr so cron will email it.
{
	echo "===== cron wrapper failure ====="
	echo "date:    $(date)"
	echo "machine: $(hostname)"
	echo "script:  $script"
	echo "rc:      $rc"
	echo "logfile: $logfile"
	echo "================================"
} >> "$logfile"

append_stderr_to_log

echo "===== cron wrapper failure =====" >&2
echo "date:    $(date)" >&2
echo "machine: $(hostname)" >&2
echo "script:  $script" >&2
echo "rc:      $rc" >&2
echo "logfile: $logfile" >&2
echo "================================" >&2

if [ -s "$errfile" ]; then
	echo "----- ${script_base} stderr begin -----" >&2
	cat "$errfile" >&2
	echo "----- ${script_base} stderr end -----" >&2
fi

exit "$rc"