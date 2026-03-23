#!/bin/zsh

html_location="$HOME/html"
repo_names=("clas12-config" "simGrid")
branches=("dev" "main")

# copy  /group/clas/www/gemc/html/web_interface/data/osgLog.json to the data
for branch in "${branches[@]}"; do
	cp /group/clas/www/gemc/html/web_interface/data/osgLog.json $html_location/$branch/web_portal/data
done
