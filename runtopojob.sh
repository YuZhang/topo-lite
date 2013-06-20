#!/usr/local/bin/bash

source ${TOPOLITEPATH}/topolite.conf.sh

# 2013-06-19 10:48:00

lasttime=${1:?"missing the lasttime \"%Y-%m-%d %H:%M:%S\""};
while [ 1 ]; do
  thistime=${lasttime}
  lasttime=$(date +"%Y-%m-%d %H:%M:%S");
  echo "========== $lasttime ==========" &>> ${_logpath}/runtopojob.log
  sleep 60
  find -s ${_rawbgppath} -type d -maxdepth 4 -depth 4 -newerct  "${thistime}"  | xargs -n1 -P10 ${_binpath}/getlink.sh &>> ${_logpath}/runtopojob.log 
  sleep 7200
done
