#!/bin/bash

 
sday=`date +"%Y%m%d" -d "-3 days"`;
#SDATE=${1:?"missing starting date"}  # the ending date of period, e.g., 20130305
SDATE=${1:-$sday}  # the ending date of period, e.g., 20130305
DAYS=${2:-0}      # the length of period. 0 means only the ending date
LDIR="/home/hitnslab"

for ((i=0; i <= ${DAYS}; i++)); do
  DATE=`date +"%Y%m%d" -d "${SDATE} $i days" `
  DATE2=`date +"%Y.%m/%d" -d "${SDATE} $i days"`
  find ${LDIR}/BGP/ -type f -wholename "*${DATE2}*" | sort -r | ${LDIR}/beep/extractor.pl -z -p ${LDIR}/beep/dailyresults/${DATE} &> ${LDIR}/beep/dailyresults/${DATE}.log
done
