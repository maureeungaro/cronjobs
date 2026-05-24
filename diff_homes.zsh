#!/bin/zsh
set -euo pipefail

has_diff=0

compare_dirs() {
  local dir1=$1
  local dir2=$2
  shift 2
  local extra_args=("$@")

  diff -rq "$dir1" "$dir2" "${extra_args[@]}" | while IFS= read -r line; do
    has_diff=1
    if [[ "$line" == Only\ in\ * ]]; then
      # "Only in /some/dir: filename"
      local location=$(echo "$line" | sed 's/Only in \(.*\): \(.*\)/\1/')
      local filename=$(echo "$line" | sed 's/Only in \(.*\): \(.*\)/\2/')
      echo "ONLY IN: $location/$filename"

    elif [[ "$line" == Files\ * ]]; then
      local f1=$(echo "$line" | sed 's/Files \(.*\) and \(.*\) differ/\1/')
      local f2=$(echo "$line" | sed 's/Files \(.*\) and \(.*\) differ/\2/')
      local t1=$(stat -f '%m' "$f1")
      local t2=$(stat -f '%m' "$f2")
      if [[ $t1 -gt $t2 ]]; then
        echo "NEWER: $f1"
      elif [[ $t2 -gt $t1 ]]; then
        echo "NEWER: $f2"
      else
        echo "SAME MTIME, DIFF CONTENT: $f1"
      fi
    fi
  done
}

compare_dirs /opt/projects/home/_includes     /opt/projects/gemc/home/_includes     --exclude=notes --exclude=gemc-logo.svg --exclude=github_milestone.html
compare_dirs /opt/projects/home/_layouts      /opt/projects/gemc/home/_layouts
compare_dirs /opt/projects/home/_plugins      /opt/projects/gemc/home/_plugins
compare_dirs /opt/projects/home/assets        /opt/projects/gemc/home/assets        --exclude=images --exclude=quotes.txt --exclude=asciinema-rec_script  --exclude=bio

exit $has_diff