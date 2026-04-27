#!/bin/zsh

set -u
cleanup_days=5

# logdir can be set by c.l.
logdir_default="$HOME/cronjobs/logs"
logdir="$logdir_default"

while getopts ":l:" opt; do
	case "$opt" in
		l) logdir="$OPTARG" ;;
		:)
			echo "Error: -$OPTARG requires an argument" >&2
			exit 2
			;;
		\?)
			echo "Error: invalid option: -$OPTARG" >&2
			echo "Usage: $0 [-l logdir] /full/path/to/script [args ...]" >&2
			exit 2
			;;
	esac
done
shift $((OPTIND - 1))

# cronjob sends an email whenever there is stdout or stderr
# in this script:
# - usage error in the wrapper: emailed
# - missing or non-executable target script: emailed
# - cannot create log dir or temp file: emailed
# - wrapped script returns nonzero: emailed
#   for diff jobs, rc=1 means differences were found
# - wrapped script succeeds: no email
# - lock busy (flock -n returns 75 because of -E 75): no email, only log entry
#
# Additional behavior:
# - log files are timestamped
# - wrapped script stderr is written to the log file
# - log files older than 2 weeks are removed automatically

cleanup() {
	[ -n "${outfile:-}" ] && [ -f "$outfile" ] && rm -f "$outfile"
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

# Timestamped log file, for example:
#   ~/cronjobs/logs/osg_fairshare-20260318-142530.log
timestamp="$(date '+%Y%m%d-%H%M%S')"
logfile="$logdir/${script_base}-${timestamp}.log"

# Ensure the common log directory exists.
mkdir -p "$logdir" || {
	echo "Error: cannot create log directory '$logdir'" >&2
	exit 2
}

purge_mtime=$((cleanup_days - 1))
find "$logdir" -type f -name "${script_base}-*.log" -mtime +"$purge_mtime" -delete 2>/dev/null

# Create temporary files to capture stdout and stderr from the wrapped script.
outfile=$(mktemp) || {
	echo "Error: mktemp failed" >&2
	exit 2
}

errfile=$(mktemp) || {
	echo "Error: mktemp failed" >&2
	exit 2
}

append_stdout_to_log() {
	if [ -s "$outfile" ]; then
		{
			echo "----- ${script_base} stdout begin -----"
			cat "$outfile"
			echo "----- ${script_base} stdout end -----"
		} >>"$logfile"
	fi
}
# Helper: append wrapped-script stderr to the current log file, if any.
append_stderr_to_log() {
	if [ -s "$errfile" ]; then
		{
			echo "----- ${script_base} stderr begin -----"
			cat "$errfile"
			echo "----- ${script_base} stderr end -----"
		} >>"$logfile"
	fi
}

{
	echo "===== wrapped script run ====="
	echo "date:       $(date)"
	echo "machine:    $(hostname)"
	echo "script:     $script"
	echo "args:       $*"
	echo "lockfile:   $lockfile"
	echo "lock_state: attempting non-blocking lock"
	echo "logfile:    $logfile"
	echo "=============================="
} >>"$logfile"

# Run the target script under a non-blocking flock lock.
#
# Redirections:
# captures wrapped-script stdout and stderr separately
# later appends stdout/stderr to the log
# still captures stderr separately
# makes lock-busy return 75 instead of ambiguous 1
flock -n -E 75 "$lockfile" "$script" "$@" >"$outfile" 2>"$errfile"
rc=$?

# rc=0 means the wrapped script ran successfully.
# We save stdout/stderr to the log file,
# but print nothing, so cron sends no email.
if [ "$rc" -eq 0 ]; then
	append_stdout_to_log
	append_stderr_to_log
	exit 0
fi

# rc=75 means lock busy because flock was called with -E 75.
# We write a log entry but print nothing to stdout/stderr,
# so cron sends no email.
if [ "$rc" -eq 75 ]; then
	{
		echo "===== lock busy ====="
		echo "date:       $(date)"
		echo "machine:    $(hostname)"
		echo "script:     $script"
		echo "args:       $*"
		echo "lockfile:   $lockfile"
		echo "lock_state: busy"
		echo "message:    ${script_base} skipped: lock busy"
		echo "logfile:    $logfile"
		echo "====================="
	} >>"$logfile"

	append_stdout_to_log
	append_stderr_to_log
	exit 0
fi

# Any other nonzero rc means the wrapped command returned nonzero.
# For diff jobs, rc=1 usually means differences were found.
{
	echo "===== wrapped script returned nonzero ====="
	echo "date:       $(date)"
	echo "machine:    $(hostname)"
	echo "script:     $script"
	echo "args:       $*"
	echo "rc:         $rc"
	echo "lockfile:   $lockfile"
	echo "lock_state: not lock-busy; wrapped command returned nonzero"
	echo "logfile:    $logfile"
	echo "==========================================="
} >>"$logfile"

append_stdout_to_log
append_stderr_to_log

echo "===== wrapped script returned nonzero =====" >&2
echo "date:       $(date)" >&2
echo "machine:    $(hostname)" >&2
echo "script:     $script" >&2
echo "args:       $*" >&2
echo "rc:         $rc" >&2
echo "lockfile:   $lockfile" >&2
echo "lock_state: not lock-busy; wrapped command returned nonzero" >&2
echo "logfile:    $logfile" >&2
echo "===========================================" >&2

if [ -s "$outfile" ]; then
	echo "----- ${script_base} stdout begin -----" >&2
	cat "$outfile" >&2
	echo "----- ${script_base} stdout end -----" >&2
fi

if [ -s "$errfile" ]; then
	echo "----- ${script_base} stderr begin -----" >&2
	cat "$errfile" >&2
	echo "----- ${script_base} stderr end -----" >&2
fi

exit "$rc"