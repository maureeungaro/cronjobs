#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
stage_ci_artifacts.zsh - Download latest CI artifacts and stage them for later CVMFS sync.

Stages into:
  <workdir>/stage/<distro>/clas12Tags/<gt>/experiments
  <workdir>/stage/<distro>/mlibrary/<mt>

Usage:
  stage_ci_artifacts.zsh [options]

Options:
  -w, --workdir DIR     Working directory (default: /work/clas12/ungaro/tmp)
  -u, --repo-url URL    Repo URL (default: https://github.com/gemc/clas12Tags.git)
  -n, --repo-name NAME  Repo name directory (default: clas12Tags)
  -d, --distros LIST    Comma-separated list (default: fedora,almalinux)
      --gt TAG          gemc tag (default: dev)
      --mt TAG          mlibrary tag (default: dev)
      --dry-run         Print actions, do not modify filesystem
  -h, --help            Show this help

Notes:
  - Requires: git, python3, and a working bin/get_last_ci_artifact.py in the repo.
  - Uses ~/.mauri token indirectly through get_last_ci_artifact.py.
EOF
}

# -----------------------------
# Defaults
# -----------------------------
dry_run=0
workdir=/work/clas12/ungaro/tmp
repo_url=https://github.com/gemc/clas12Tags.git
repo_name=clas12Tags
repo_subdir=experiments
artifact_py=$HOME/cronjobs/bin/get_last_ci_artifact.py
distros_csv="fedora,almalinux"

gt="dev"   # gemc tag
mt="dev"   # mlibrary tag

# -----------------------------
# Arg parsing
# -----------------------------
while (( $# )); do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    -w|--workdir) workdir="${2:?missing value for $1}"; shift 2 ;;
    -u|--repo-url) repo_url="${2:?missing value for $1}"; shift 2 ;;
    -n|--repo-name) repo_name="${2:?missing value for $1}"; shift 2 ;;
    -d|--distros) distros_csv="${2:?missing value for $1}"; shift 2 ;;
    --gt) gt="${2:?missing value for $1}"; shift 2 ;;
    --mt) mt="${2:?missing value for $1}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 -- "Unknown option: $1"; usage; exit 2 ;;
  esac
done

# -----------------------------
# Helpers
# -----------------------------
die() { print -u2 -- "ERROR: $*"; exit 1; }
ensure_dir() { mkdir -p -- "${1:?missing dir}"; }

run() {
  if (( dry_run )); then
    print -- "[dry-run] $*"
  else
    eval "$@"
  fi
}

sync_repo() {
  local wd="${1:?missing workdir}"
  local url="${2:?missing repo url}"
  local name="${3:?missing repo name}"

  ensure_dir "$wd"
  cd "$wd"

  echo
  echo "Cloning or pulling ${name} repo in ${wd}"
  if [[ -d "$name/.git" ]]; then
    cd "$name"
	if ! run git pull --ff-only; then
	  echo "git pull failed in $repo" >&2
	  exit 1
	fi
  else
    run "git clone ${(qq)url} ${(qq)name}"
    cd "$name"
  fi
}

# -----------------------------
# Main
# -----------------------------
(( dry_run )) && echo "Running in --dry-run mode: no changes will be made."

ensure_dir "$workdir"
sync_repo "$workdir" "$repo_url" "$repo_name"
repo_root="$(pwd)"  # inside repo
[[ -f "$artifact_py" ]] || die "Artifact script not found: $artifact_py"

stage_base="${workdir}/stage"
ensure_dir "$stage_base"

# Parse distros
distros=("${(@s:,:)distros_csv}")

echo
echo "Staging distros: ${distros[*]}"
echo "Stage base: $stage_base"
echo "Tags: gt=${gt} mt=${mt}"

for d in "${distros[@]}"; do
  echo
  echo "---- Staging: $d ----"

  tmp="${stage_base}/${d}.new"
  final="${stage_base}/${d}"

  # Clean tmp, then rebuild
  run "rm -rf -- ${(qq)tmp}"
  ensure_dir "$tmp/${repo_name}/${gt}/experiments"
  ensure_dir "$tmp/mlibrary/${mt}"

  # 1) Stage experiments from repo into clas12Tags/<gt>/experiments
  [[ -d "${repo_root}/${repo_subdir}" ]] || die "Repo subdir not found: ${repo_root}/${repo_subdir}"
  echo "Copying repo experiments -> ${tmp}/${repo_name}/${gt}/experiments"
  run "cp -R -- ${(qq)repo_root}/${repo_subdir}/. ${(qq)tmp}/${repo_name}/${gt}/experiments/"

  # 2) Download+unpack artifact into staged clas12Tags/<gt>
  echo "Downloading latest CI artifact for ${d} into staged ${gt}/ (via get_last_ci_artifact.py)"
  if (( dry_run )); then
    print -- "[dry-run] cd ${(qq)tmp}/${repo_name}/${gt} && ${(qq)artifact_py} $d"
  else
    cd "$tmp/$repo_name/$gt"
    "$artifact_py" "$d"
  fi

  # 3) Finalize: copy mlibrary/* -> ../../mlibrary/<mt> (within staging tree)
  if (( dry_run )); then
    print -- "[dry-run] if [[ -d mlibrary ]]; then cp -R -- mlibrary/* ${(qq)tmp}/mlibrary/${mt}; fi"
    print -- "[dry-run] rm -f -- gemc.zip || true"
  else
    cd "$tmp/$repo_name/$gt"
    if [[ -d "mlibrary" ]]; then
      cp -R -- mlibrary/* "$tmp/mlibrary/$mt"
      rm -rf mlibrary
    else
      echo "NOTE: no 'mlibrary/' directory produced by artifact in $(pwd) (skipping mlibrary/${mt} update)"
    fi
    rm -f -- gemc.zip 2>/dev/null || true
  fi

  # 4) Atomic publish: replace final with tmp
  echo "Publishing staged tree: ${final}"
  if (( dry_run )); then
    print -- "[dry-run] rm -rf -- ${(qq)final} && mv -- ${(qq)tmp} ${(qq)final}"
  else
    rm -rf -- "$final"
    mv -- "$tmp" "$final"
  fi
done

echo
echo "Done staging."