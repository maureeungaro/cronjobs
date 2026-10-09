#!/bin/zsh
set -euo pipefail

# Translate repository docs into the configured languages, using the shared tool in
# ~/myenv/bin/translate. Safe to run manually or from cron (idempotent + hash-skipped); the daily
# crontab entry runs this exact script through run_with_lock_and_log.zsh.
#
#   update_translations.zsh                 # all repos in to_translate.yaml
#   update_translations.zsh gemc/home       # only the named repo(s)
#   update_translations.zsh --force         # ignore hashes; re-translate everything
#   update_translations.zsh --no-validate   # skip the codex validation pass
#
# Translations are written into each repo's working tree; publishing (git) is left to you, matching
# the other cron jobs (e.g. update_ghome.sh).

tool="$HOME/myenv/bin/translate/translate.py"
config="/opt/projects/cronjobs/to_translate.yaml"

# claude + codex live in Homebrew's bin; make sure they're found under cron's minimal PATH.
export PATH="/opt/homebrew/bin:$PATH"

# pyyaml comes from this venv (same one the other jobs use).
source "$HOME/venv/yaml/bin/activate"

python3 "$tool" --config "$config" "$@"
