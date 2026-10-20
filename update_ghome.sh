#!/bin/zsh
set -euo pipefail

# Milestone numbers are repository-specific; '-' disables pygemc updates.
if [ "$#" -ne 3 ]; then
	echo "Usage: $0 src_milestone pygemc_milestone_or_- clas12_systems_milestone" >&2
	exit 2
fi

src_milestone="$1"
pygemc_milestone="$2"
c12s_milestone="$3"

if [[ "$src_milestone" != <1-> || "$c12s_milestone" != <1-> ||
	( "$pygemc_milestone" != "-" && "$pygemc_milestone" != <1-> ) ]]; then
	echo "Milestones must be positive integers; use '-' to skip pygemc." >&2
	exit 2
fi

pygemc_args=()
if [[ "$pygemc_milestone" != "-" ]]; then
	pygemc_args=(--repo-milestone "pygemc:$pygemc_milestone")
fi

out_dir=/opt/projects/gemc/home/_data/github/
ghome=/opt/projects/gemc/home


# gemc documentation dynamically
cd "$ghome"
local pgemc=/opt/jlab_software/macosx26-clang21-arm64/gemc/dev
export PATH=$pgemc/bin:$pgemc/python_env/bin:$PATH
python3 scripts/generate_options_docs.py
source ~/venv/yaml/bin/activate

#python3 scripts/generate_example_assets.py
python3 scripts/fetch_github_milestone.py \
	--owner gemc \
	--repo src \
	--milestone "$src_milestone" \
	"${pygemc_args[@]}" \
	--repo-milestone "clas12-systems:$c12s_milestone" \
	--output-dir "$out_dir"

# also update the home bio documentation dynamically
cd /opt/projects/home/
python3 bio/mauri/scripts/update_material.py --size 1000


# update

update_issues=/opt/projects/cronjobs/update_issues.py

# Run from each repo checkout so update_issues.py auto-detects that repo and
# updates the latest versioned file in its releases/ directory (never dev.md).
cd /opt/projects/gemc/src            && python3 "$update_issues" gemc/src            "$src_milestone"
if [[ "$pygemc_milestone" != "-" ]]; then
	cd /opt/projects/gemc/pygemc && python3 "$update_issues" gemc/pygemc "$pygemc_milestone"
else
	echo "Skipping gemc/pygemc: no milestone configured."
fi
cd /opt/projects/gemc/clas12-systems && python3 "$update_issues" gemc/clas12-systems "$c12s_milestone"

