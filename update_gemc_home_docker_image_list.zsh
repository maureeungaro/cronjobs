#!/usr/bin/env zsh
set -euo pipefail

# Defaults
MATRIX_PRODUCER="/opt/projects/gemc/src/ci/distros_tags.sh"
DEFAULT_OUTPUT="/opt/projects/gemc/home/_data/docker.yml"
DEFAULT_REGISTRY="ghcr.io/gemc/src"

usage() {
  cat <<EOF
Usage:
  $0
  $0 INPUT_FILE
  $0 INPUT_FILE OUTPUT_FILE
  $0 - OUTPUT_FILE < input.txt

Behavior:
  With no arguments:
    runs ${MATRIX_PRODUCER}
    writes ${DEFAULT_OUTPUT}

  With INPUT_FILE:
    reads INPUT_FILE
    writes ${DEFAULT_OUTPUT}

  With INPUT_FILE OUTPUT_FILE:
    reads INPUT_FILE
    writes OUTPUT_FILE

Environment override:
  REGISTRY=ghcr.io/gemc/src $0
EOF
}

if [[ $# -gt 0 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  usage
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 2
fi

input=""
output="$DEFAULT_OUTPUT"

if [[ $# -eq 0 ]]; then
  input="__RUN_MATRIX_PRODUCER__"
elif [[ $# -eq 1 ]]; then
  input="$1"
elif [[ $# -eq 2 ]]; then
  input="$1"
  output="$2"
else
  usage >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

raw="$tmpdir/input.txt"
matrix_build="$tmpdir/matrix_build.json"
matrix_manifest="$tmpdir/matrix_manifest.json"
registry_file="$tmpdir/registry.txt"

if [[ "$input" == "__RUN_MATRIX_PRODUCER__" ]]; then
  if [[ ! -x "$MATRIX_PRODUCER" ]]; then
    echo "Error: matrix producer is not executable: $MATRIX_PRODUCER" >&2
    exit 4
  fi

  "$MATRIX_PRODUCER" > "$raw"

elif [[ "$input" == "-" ]]; then
  cat > "$raw"

else
  if [[ ! -f "$input" ]]; then
    echo "Error: input file not found: $input" >&2
    exit 4
  fi

  cp "$input" "$raw"
fi

awk \
  -v build="$matrix_build" \
  -v manifest="$matrix_manifest" \
  -v registry_file="$registry_file" '
  /^[[:space:]]*==[[:space:]]*matrix_build[[:space:]]*==[[:space:]]*$/ {
    section = "build"
    next
  }

  /^[[:space:]]*==[[:space:]]*matrix_manifest[[:space:]]*==[[:space:]]*$/ {
    section = "manifest"
    next
  }

  /^[[:space:]]*images located at:[[:space:]]*/ {
    sub(/^[[:space:]]*images located at:[[:space:]]*/, "")
    print > registry_file
    next
  }

  /^[[:space:]]*$/ {
    next
  }

  section == "build" && /^[[:space:]]*\{/ {
    print > build
    next
  }

  section == "manifest" && /^[[:space:]]*\{/ {
    print > manifest
    next
  }
' "$raw"

if [[ ! -s "$matrix_build" ]]; then
  echo "Error: could not find matrix_build JSON." >&2
  exit 3
fi

if [[ ! -s "$matrix_manifest" ]]; then
  echo "Error: could not find matrix_manifest JSON." >&2
  exit 3
fi

jq empty "$matrix_build" >/dev/null
jq empty "$matrix_manifest" >/dev/null

registry=${REGISTRY:-}

if [[ -z "$registry" && -s "$registry_file" ]]; then
  registry=$(cat "$registry_file")
fi

registry=${registry:-$DEFAULT_REGISTRY}

mkdir -p "$(dirname "$output")"

jq -n -r \
  --slurpfile build "$matrix_build" \
  --slurpfile manifest "$matrix_manifest" \
  --arg registry "$registry" '
  def pretty_id($s):
    if $s == "almalinux" then "AlmaLinux"
    elif $s == "archlinux" then "ArchLinux"
    elif $s == "debian" then "Debian"
    elif $s == "fedora" then "Fedora"
    elif $s == "ubuntu" then "Ubuntu"
    else ($s[0:1] | ascii_upcase) + $s[1:]
    end;

  ($build[0].include // []) as $builds |

  def has_arch($row; $arch):
    any($builds[];
      .image == $row.image and
      .image_tag == $row.image_tag and
      .geant4_tag == $row.geant4_tag and
      .gemc_tag == $row.gemc_tag and
      .arch == $arch
    );

  ["images:"] +
  (
    ($manifest[0].include // [])
    | unique_by([.image, .image_tag, .geant4_tag, .gemc_tag])
    | sort_by(
        if .gemc_tag == "dev" then 0 else 1 end,
        .image
      )
    | map(
        "  - id: \(pretty_id(.image))\n" +
        "    osversion: \(.image_tag)\n" +
        "    tag: \($registry):\(.gemc_tag)-\(.image)-\(.image_tag)\n" +
        "    amd64: \(if has_arch(.; "amd64") then "yes" else "no" end)\n" +
        "    arm64: \(if has_arch(.; "arm64") then "yes" else "no" end)\n" +
        "    gemcv: \(.gemc_tag)"
      )
  )
  | join("\n")
' > "$output"

echo "Wrote $output"