#!/bin/zsh

html_location="$HOME/html"

repo_names=("clas12-config" "simGrid")
branches=("dev" "main")

for branch in "${branches[@]}"; do
	for location in "${repo_names[@]}"; do
		echo
		echo $html_location/$branch/$location
		cd $html_location/$branch/$location
		git checkout $branch
		git pull
	done
done
