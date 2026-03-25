#!/bin/zsh

# Require at least one argument: the directory where the json is written
if [ "$#" -lt 1 ]; then
	echo "Usage: $0 /full/path/to/portal/data" >&2
	exit 2
fi

path="$1"

days='25'
algo='aging_interleaved'
half_life_days='2.0'
history_half_life_days='5'
queue_penalty='2.0'
user_bust='2'

cd $path

if [[ ! -f $HOME/simGrid/db_io/priority_submissions.py ]]; then
	echo "simGrid is not installed or not in $HOME. Exiting."
	exit 1
fi

/usr/bin/python3 $HOME/simGrid/db_io/priority_submissions.py \
	-c ~/msql_conn.txt \
	-d $days \
	--priority-algorithm $algo \
	--half-life-days $half_life_days \
	--history-half-life-days $history_half_life_days \
	--queue-penalty-exponent $queue_penalty \
	--burst-per-user $user_bust \
	--write-to-db
