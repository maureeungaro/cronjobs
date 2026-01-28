#!/bin/zsh

src="/volatile/clas12/osg/osgLog.json"
dest="/u/group/clas/www/gemc/html/web_interface/data/"
logfile="logs/osgLog.txt"

cp "$src" "$dest"

# recreate the log file with current date/time
rm -f "$logfile"
date > "$logfile"

