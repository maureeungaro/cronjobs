#!/bin/zsh

days='25'
algo='aging_interleaved'
half_life_days='1.5'
history_half_life_days='5'
queue_penalty='0.5'
user_bust='2'

cd /group/clas/www/gemc/html/web_interface/data

python3 /home/ungaro/simGrid/db_io/priority_submissions.py \
 -c ~/msql_conn.txt \
 -d $days \
 --priority-algorithm $algo \
  --half-life-days $half_life_days \
  --history-half-life-days $history_half_life_days \
  --queue-penalty-exponent $queue_penalty \
  --burst-per-user $user_bust \
  --write-to-db


