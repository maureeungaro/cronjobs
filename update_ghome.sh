#!/bin/zsh
set -euo pipefail


# Require at least one argument: the directory where the json is written
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 milestone number" >&2
	exit 2
fi

src_milestone="$1"
pygemc_milestone="$2"
c12s_milestone=$3

out_dir=/opt/projects/gemc/home/_data/github/
ghome=/opt/projects/gemc/home

gsrc=/opt/projects/gemc/src
gpygemc=/opt/projects/gemc/pygemc
c12s=/opt/projects/gemc/clas12-systems

# gemc documentation dynamically
cd "$ghome"
local pgemc=/opt/jlab_software/macosx26-clang21-arm64/gemc/dev
export PATH=$pgemc/bin:$pgemc/python_env/bin:$PATH
python3 scripts/generate_options_docs.py
source ~/venv/yaml/bin/activate
python3 scripts/generate_example_assets.py
python3 scripts/fetch_github_milestone.py \
	--owner gemc \
	--repo src \
	--milestone $src_milestone \
	--repo-milestone pygemc:$pygemc_milestone \
	--repo-milestone clas12-systems:$c12s_milestone \
	--output-dir $out_dir

# also update the home bio documentation dynamically
cd /opt/projects/home/
python3 bio/mauri/scripts/update_material.py --size 1000


# project / milestone number / release version
rpynotes=pygemc/ci/update_milestone_issues.py

cd /opt/projects/gemc/
python3 "$rpynotes" gemc/pygemc 1
python3 "$rpynotes" gemc/src    2
