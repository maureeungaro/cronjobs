#!/bin/zsh

html_location="/group/clas/www/gemc/html/"
repo_name="clas12-config"

cd $html_location/$repo_name ; git pull
cd $html_location/test/$repo_name ; git pull
