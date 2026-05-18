#!/bin/zsh
set -euo pipefail

cron_location="$HOME/cronjobs"
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

echo
echo Pulling $cron_location
cd   $cron_location
git  pull
cd

echo Crontabbing: "$cron_location/$cronfile"
/usr/bin/crontab "$cron_location/$cronfile"
