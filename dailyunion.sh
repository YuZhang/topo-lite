#!/usr/local/bin/bash
# test on GNU bash, version 4.1.9(0)-release (amd64-portbld-freebsd7.4)
# yzhang 20130601

source ${TOPOLITEPATH}/topolite.conf.sh

# aggregate files from collectors to a union file in each day from ENDDATE - DAYS to ENDDATE
ENDDATE=${1:?"missing the ending date"}  # the ending date of period, e.g., 20130305
DAYS=${2:-0}                             # the length of period. 0 means only the ending date

for ((i=0; i <= ${DAYS}; i++)); do
  DATE=`date -j -v-${i}d +"%Y%m%d" ${ENDDATE}0000`
  linkdir="$_datapath/${DATE:0:4}.${DATE:4:2}/${DATE:6:2}"
  [ -d $linkdir ] || continue
  v4dailydir="${_v4dailypath}/${DATE:0:4}.${DATE:4:2}"
  v6dailydir="${_v6dailypath}/${DATE:0:4}.${DATE:4:2}"
  [ -d ${v4dailydir} ] || mkdir -p ${v4dailydir}
  [ -d ${v6dailydir} ] || mkdir -p ${v6dailydir}
  v4file="${v4dailydir}/${DATE}.link.v4.gz"
  v6file="${v6dailydir}/${DATE}.link.v6"
  linkfile="${linkdir}/${DATE}*.gz"
  gzip -dc $linkfile | ${_binpath}/uniqs.pl 2> ${v6file} | gzip -c > ${v4file}
  if [ -s ${v6file} ]; then
    gzip -f ${v6file}
  else
    unlink ${v6file}
  fi
done
