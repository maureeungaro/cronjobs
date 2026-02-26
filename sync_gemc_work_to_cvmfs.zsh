#!/bin/zsh
set -euo pipefail

usage() {
	cat <<'EOF'
sync_staged_to_cvmfs.zsh - Sync staged artifacts + experiments into /scigroup CVMFS locations.

Reads from:
  <workdir>/stage/<distro>/clas12Tags/<gt>/experiments
  <workdir>/stage/<distro>/mlibrary/<mt>

Writes to:
  expdir[<distro>] (<gt>/experiments)
  and to the matching <root>/mlibrary/<mt>

Usage:
  sync_staged_to_cvmfs.zsh [options]

Options:
  -w, --workdir DIR     Working directory (default: /work/clas12/ungaro/tmp)
  -d, --distros LIST    Comma-separated list (default: fedora,almalinux)
      --gt TAG          gemc tag (default: dev)
      --mt TAG          mlibrary tag (default: dev)
      --dry-run         Print actions, do not modify filesystem
  -h, --help            Show this help

Notes:
  - Prefers rsync. If rsync is missing, this script will error (install rsync).
  - Uses rsync --delete to emulate prune_not_in_repo + copy behavior.
EOF
}

# -----------------------------
# Defaults
# -----------------------------
dry_run=0
workdir=/work/clas12/ungaro/tmp
repo_name=clas12Tags
distros_csv="fedora,almalinux"

gt="dev"   # gemc tag
mt="dev"   # mlibrary tag

distros=(fedora almalinux)

typeset -A expdir
expdir[fedora]=/scigroup/cvmfs/geant4/fedora36-gcc12/clas12Tags/dev/experiments
expdir[almalinux]=/scigroup/cvmfs/geant4/almalinux9-gcc11/clas12Tags/dev/experiments

# -----------------------------
# Arg parsing
# -----------------------------
while (($#)); do
	case "$1" in
		--dry-run)
			dry_run=1
			shift
			;;
		-w | --workdir)
			workdir="${2:?missing value for $1}"
			shift 2
			;;
		-d | --distros)
			distros_csv="${2:?missing value for $1}"
			shift 2
			;;
		--gt)
			gt="${2:?missing value for $1}"
			shift 2
			;;
		--mt)
			mt="${2:?missing value for $1}"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			print -u2 -- "Unknown option: $1"
			usage
			exit 2
			;;
	esac
done

# -----------------------------
# Helpers
# -----------------------------
die() {
	print -u2 -- "ERROR: $*"
	exit 1
}
ensure_dir() { mkdir -p -- "${1:?missing dir}"; }

run() {
	if ((dry_run)); then
		print -- "[dry-run] $*"
	else
		eval "$@"
	fi
}

have() { command -v "$1" >/dev/null 2>&1; }

ensure_bin_exec() {
  local bindir="${1:?missing bindir}"
  [[ -d "$bindir" ]] || return 0
  echo "Fixing executable permissions under $bindir"
  if (( dry_run )); then
    print -- "[dry-run] chmod a+rx -- ${(qq)bindir}"
    print -- "[dry-run] find ${(qq)bindir} -type f -exec chmod a+rx {} +"
  else
    chmod a+rx -- "$bindir" || true
    # make all files in bin executable
    find "$bindir" -type f -exec chmod a+rx {} + || true
  fi
}

# -----------------------------
# Main
# -----------------------------
((dry_run)) && echo "Running in --dry-run mode: no changes will be made."

have rsync || die "rsync not found on this machine; install/load it."

stage_base="${workdir}/stage"
[[ -d "$stage_base" ]] || die "Stage base not found: $ noticed: ${stage_base}"

distros=("${(@s:,:)distros_csv}")

echo
echo "Syncing distros: ${distros[*]}"
echo "Stage base: $stage_base"
echo "Tags: gt=${gt} mt=${mt}"

for d in "${distros[@]}"; do
	[[ -n "${expdir[$d]:-}" ]] || die "No expdir mapping for distro '$d'"

	stage_root="${stage_base}/${d}/${repo_name}"
	src_tag="${stage_root}/${gt}"
	src_exp="${src_tag}/experiments"
	src_mlib="${stage_base}/${d}/mlibrary/${mt}"

	[[ -d "$src_exp" ]] || die "Staged experiments not found: $src_exp"

	# rewrite expdir[...] from .../clas12Tags/dev/experiments -> .../clas12Tags/<gt>/experiments
	tgt_exp="${expdir[$d]%/clas12Tags/dev/experiments}/clas12Tags/${gt}/experiments"
	tgt_tag="${tgt_exp%/experiments}"   # .../clas12Tags/<gt>

	# derive distro root and mlibrary target from tgt_tag
	base="${tgt_tag%/clas12Tags/${gt}}" # .../<distro-root> (sibling of clas12Tags)
	tgt_mlib="${base}/mlibrary/${mt}"   # .../<distro-root>/mlibrary/<mt>

	echo
	echo "---- Sync: $d ----"
	echo "  src_tag : $src_tag"
	echo "  tgt_tag : $tgt_tag"
	echo "  src_exp : $src_exp"
	echo "  tgt_exp : $tgt_exp"
	echo "  src_mlib: $src_mlib"
	echo "  tgt_mlib: $tgt_mlib"

	ensure_dir "$tgt_tag"
	ensure_dir "$tgt_exp"
	ensure_dir "$tgt_mlib"

	rsync_copy=(-a)                 # copy/update only (NO pruning)
	rsync_mirror=(-a --delete)      # mirror with pruning

	(( dry_run )) && rsync_copy+=(-n -v)
	(( dry_run )) && rsync_mirror+=(-n -v)

	# 1) Copy/update <gt>/ WITHOUT pruning
	[[ -d "$src_tag" ]] || die "Staged tag not found: $src_tag"
	run "rsync ${(@q)rsync_copy} ${(qq)src_tag}/ ${(qq)tgt_tag}/"
	ensure_bin_exec "$tgt_tag/bin"

	# 2) Mirror <gt>/experiments WITH pruning
	[[ -d "$src_exp" ]] || die "Staged experiments not found: $src_exp"
	run "rsync ${(@q)rsync_mirror} ${(qq)src_exp}/ ${(qq)tgt_exp}/"

	# 3) Copy/update mlibrary/<mt> WITHOUT pruning
	if [[ -d "$src_mlib" ]]; then
	  run "rsync ${(@q)rsync_copy} ${(qq)src_mlib}/ ${(qq)tgt_mlib}/"
	else
	  echo "NOTE: staged mlibrary/${mt} not found for $d (skipping mlibrary sync)"
	fi

done

echo
echo "Done syncing."