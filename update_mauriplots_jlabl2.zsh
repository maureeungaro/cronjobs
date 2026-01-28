#!/bin/zsh

# This script is meant to be run by a cronjob on jlabl4 to update on /userweb/ungaro/public_html:
# - mauriPlots
# - slides
# - pubs

function pull_or_clone() {

	# if 'plots/' is the prefix	of $project_name, the basedir is /userweb/ungaro/public_html/plots
	if [[ $1 == plots/* ]]; then
		basedir=/userweb/ungaro/public_html/plots
	elif [[ $1 == geant4-tutorials ]]; then
		basedir=/userweb/ungaro/public_html/slides
	else
		basedir=/userweb/ungaro/public_html
	fi

	project_name=${1:t}
	project_repo=$2

	echo
	echo "basedir: $basedir"
	echo "project_name: $project_name"
	echo "project_repo: $project_repo"


	cd $basedir || exit
	# optional reset argument will remove and re-clone the repo
	if [[ $# -eq 3 && $3 == "reset" ]]; then
		rm -rf "$project_name"
		mkdir -p "$project_name"
		cd "$project_name/.." || exit
		git clone -s "$project_repo"
		echo "$project_name reset and cloned"
	else
		if [[ -d $project_name ]]; then
			cd "$project_name" || exit
			git pull
			echo "$project_name pulled"
		else
			"cd $basedir" || exit
			git clone "$project_repo"
			echo "$project_name cloned"
		fi
	fi
}

# the plots repos are reset every time
# git pull is enough, removing and re-cloning repos
repo=https://github.com/mauriPlots
plots_r=(pi0_delta_distributions epid ppid vertex efid pfid e_kin_cor)
for r in $plots_r; do
	pull_or_clone "plots/$r" "$repo/$r" reset
done

repo=https://github.com/maureeungaro/slides
pull_or_clone slides $repo

repo=https://github.com/maureeungaro/pubs
pull_or_clone pubs $repo

# cloned inside /userweb/ungaro/public_html/slides
repo=https://github.com/jeffersonlab/geant4-tutorials
pull_or_clone geant4-tutorials $repo
