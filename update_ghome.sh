#!/bin/zsh
set -euo pipefail


# Require at least one argument: the directory where the json is written
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 milestone number" >&2
	exit 2
fi

milestone="$1"
pymile=/opt/projects/gemc/home/scripts/fetch_github_milestone.py
out_dir=/opt/projects/gemc/home/_data/github/

python3  $pymile \
  --owner gemc \
  --repo src \
  --milestone $milestone \
  --output-dir $out_dir

# also update the documentation dynamically
ghome=/opt/projects/gemc/home/
cd $ghome
export PATH=$PATH:/opt/projects/gemc/g4install/macosx26-clang21-arm64/gemc/dev/bin
python3 scripts/generate_options_docs.py

# update bio
  python3 bio/mauri/scripts/update_material.py --size 1000
