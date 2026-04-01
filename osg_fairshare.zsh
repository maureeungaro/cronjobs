#!/bin/zsh

# Require at least one argument: the directory where the json is written
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 /full/path/to/portal/data" >&2
	exit 2
fi

path="$1"
# in /home until gemc is the only one running - then can remove simlink
priority_submissions=$HOME/html/main/simGrid/db_io/priority_submissions.py
priority_submissions=$HOME/simGrid/db_io/priority_submissions.py

days='60'
algo='aging_interleaved'
half_life_days='3.0'
history_half_life_days='5'
queue_penalty='2.0'
user_bust='2'

cd $path

if [[ ! -f $priority_submissions ]]; then
	echo "simGrid is not installed or not in $HOME. Exiting."
	exit 1
fi

/usr/bin/python3 $priority_submissions \
	-c ~/msql_conn.txt \
	-d $days \
	--priority-algorithm $algo \
	--half-life-days $half_life_days \
	--history-half-life-days $history_half_life_days \
	--queue-penalty-exponent $queue_penalty \
	--burst-per-user $user_bust \
	--write-to-db
