#!/bin/zsh
set -euo pipefail


# Require at least one argument: the directory where the json is written
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 milestone number" >&2
	exit 2
fi

milestone="$1"
pygemc_milestone="$2"

pymile=/opt/projects/gemc/home/scripts/fetch_github_milestone.py
out_dir=/opt/projects/gemc/home/_data/github/
ghome=/opt/projects/gemc/home
gsrc=/opt/projects/gemc/src
gpygemc=/opt/projects/gemc/pygemc

  python3 $pymile \
    --owner gemc \
    --repo src \
    --milestone $milestone \
    --repo-milestone pygemc:$pygemc_milestone \
    --output-dir $out_dir

# also update the rendered GEMC license page from the canonical repositories
if ! cmp -s "$gsrc/LICENSE.md" "$gpygemc/LICENSE.md"; then
  echo "ERROR: src/LICENSE.md and pygemc/LICENSE.md differ; update the homepage license manually." >&2
  exit 1
fi
cp "$gsrc/LICENSE.md" "$ghome/license.md"

# also update the gemc documentation dynamically
cd "$ghome"
local pgemc=/opt/jlab_software/macosx26-clang21-arm64/gemc/dev
export PATH=$pgemc/bin:$pgemc/python_env/bin:$PATH
python3 scripts/generate_options_docs.py

# also update the hom bio documentation dynamically
cd /opt/projects/home/
python3 bio/mauri/scripts/update_material.py --size 1000


# also update the release notes of src and pygemc
rpynotes=/opt/projects/gemc/pygemc/ci/update_milestone_issues.py

# project / milestone number / release version
cd /opt/projects/gemc/
python3 "$rpynotes" gemc/pygemc 1
python3 "$rpynotes" gemc/src    2
