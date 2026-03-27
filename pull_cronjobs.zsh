#!/bin/zsh

cron_location="$HOME/cronjobs"

echo
echo Pulling $cron_location
cd   $cron_location
git  pull
