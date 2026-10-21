#!/bin/zsh
set -euo pipefail

cron_location="$HOME/cronjobs"
myemv_location="$HOME/myenv"
user="$(whoami)"
hmachine=$(hostname -s)

case "$hmachine" in
	enpungaro-m2n)
		cron_location="/opt/projects/cronjobs"
		cronfile="enpungaro-m2n.crontab"
		;;
	ifarm2401)
		cronfile="2401.crontab"
		;;
	ifarm2402)
		cronfile="2402.crontab"
		;;
	jlabl2)
		cronfile="jlabl2.crontab"
		;;
	gemc-rh9)
		myemv_location="na"
		case "$user" in
			ungaro)
				cronfile="gemc.ungaro.crontab"
				;;
			gemc)
				cronfile="gemc.gemc.crontab"
				;;
			*)
				exit 0
				;;
		esac
		;;
	*)
		exit 0
		;;
esac

# Pull a repo without letting a dirty tree or a pull failure abort the script.
# --autostash stashes local changes, rebases, then re-applies them, so
# uncommitted work no longer blocks the pull. On any failure we warn and
# continue so the crontab install below always runs.
safe_pull() {
	local dir="$1"
	echo
	echo "Pulling $dir"
	if ! git -C "$dir" pull --rebase --autostash; then
		echo "WARNING: git pull failed in $dir; continuing" >&2
	fi
}

safe_pull "$cron_location"

if [[ $myemv_location != "na" ]]; then
	safe_pull "$myemv_location"
fi


echo Crontabbing: "$cron_location/$cronfile"
/usr/bin/crontab "$cron_location/$cronfile"
