#!/bin/zsh

# temp file to be executed on ifarm until web
# software is installed properly on gemc.jlab.org

days='14'
algo='aging_interleaved'
half_life_days='0.25'
history_half_life_days='4'
queue_penalty='0.5'
user_bust='5'

cd /group/clas/www/gemc/html/web_interface/data

python3 /group/clas/www/gemc/html/simGrid/db_io/priority_submissions.py \
 -c ~/msql_conn.txt \
 -d $days \
 --priority-algorithm $algo \
  --half-life-days $half_life_days \
  --history-half-life-days $history_half_life_days \
  --queue-penalty-exponent $queue_penalty \
  --burst-per-user $user_bust


