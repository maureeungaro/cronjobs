#!/bin/zsh
set -euo pipefail

# Publish the recipe source and its photographs to the personal homepage.
# Run before comparisons, which may exit with status 1 when differences exist.
script_dir=${0:A:h}
projects_dir=${script_dir:h}
recipe_source="$projects_dir/casetta/food/recipes"
recipe_target="$projects_dir/home/recipes"
if [[ ! -d "$recipe_source" ]]; then
  print -u2 "Recipe source missing: $recipe_source"
  exit 2
fi
mkdir -p "$recipe_target"
rsync -a --exclude=.idea --exclude=.DS_Store "$recipe_source/" "$recipe_target/"
cp "$recipe_source/basic_ingredients.yml" "$projects_dir/home/_data/basic_ingredients.yml"
print "Recipes copied to $recipe_target"

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

compare_dirs /opt/projects/home/_includes /opt/projects/gemc/home/_includes  --exclude=notes   --exclude=gemc-logo.svg --exclude=github_milestone.html
compare_dirs /opt/projects/home/_layouts  /opt/projects/gemc/home/_layouts   --exclude=recipe.html
compare_dirs /opt/projects/home/_plugins  /opt/projects/gemc/home/_plugins
compare_dirs /opt/projects/home/assets    /opt/projects/gemc/home/assets     --exclude=scaling --exclude=images --exclude=quotes.txt --exclude=asciinema-rec_script --exclude=bio --exclude=assets.md --exclude=wfd.js --exclude=wfd.css

exit $has_diff