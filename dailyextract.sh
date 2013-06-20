#!/usr/local/bin/bash
# Extract links from collectors' raw data on given days 
# test on GNU bash, version 4.1.9(0)-release (amd64-portbld-freebsd7.4)
# yzhang 20130601

source ${TOPOLITEPATH}/topolite.conf.sh 

PARA=10  # the number of parallel processes in xargs
ENDDATE=${1:?"missing the ending date"}  # the ending date of period, e.g., 20130305
DAYS=${2:-0}                             # the length of period. 0 means only the ending date
for ((i=0; i <= ${DAYS}; i++)); do
  DATE=`date -j -v-${i}d +"%Y.%m/%d" ${ENDDATE}0000`
  DATE2=`date -j -v-${i}d +"%Y%m%d" ${ENDDATE}0000`
  # in case of overwriting into the same file, process UPDATES and RIBS separately and sequentially
  find -s ${_rawbgppath} -maxdepth 2 -depth 2 -name "UPDATES" -print | sed "s:\$:/${DATE}:" | xargs -n1 -P${PARA} ${_binpath}/getlink.sh &>> ${_logpath}/dailyextract.log
  find -s ${_rawbgppath} -maxdepth 2 -depth 2 -name "RIBS" -print | sed "s:\$:/${DATE}:" | xargs -n1 -P${PARA} ${_binpath}/getlink.sh &>> ${_logpath}/dailyextract.log
  ${_binpath}/dailyunion.sh ${DATE2} 0 &>> ${_logpath}/dailyextract.log
done
