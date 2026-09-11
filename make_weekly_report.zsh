#!/bin/zsh

# Compile the week's daily journal entries into a toned-down public weekly report on the homepage.
# The generator lives in the journal repo; this launcher is invoked by cron through
# run_with_lock_and_log.zsh (which handles locking, logging, and error email).

/opt/projects/casetta/journal/make_weekly.py
