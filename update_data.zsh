#!/bin/zsh

set -eu

html_location="${HOME}/html"

typeset -A output_names=(
	dev "osg-devel.json"
	main "osg-production.json"
)

for branch output_name in ${(kv)output_names}; do
	base_dir="${html_location}/${branch}/simGrid"
	data_dir="${base_dir}/web_portal/data"
	script="${base_dir}/list_owner_submission.py"

	[[ -x "${script}"   ]] || {
		print  -u2 "Error: missing or non-executable script: ${script}"
		exit  1
	}

	"${script}" --from-db -j "${data_dir}/${output_name}" || {
		print -u2 "Error running ${script} for branch ${branch}"
		exit 1
	}
done
