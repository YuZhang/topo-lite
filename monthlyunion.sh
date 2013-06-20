#!/usr/local/bin/bash
# aggregate daily files in last month into a single file 
# uniqc.pl will insert the number of appearance of link at the last field
# test on GNU bash, version 4.1.9(0)-release (amd64-portbld-freebsd7.4)
# yzhang 20130601

source ${TOPOLITEPATH}/topolite.conf.sh
# get the last day of last month
#ENDDATE=`date -j -v -1d +"%Y%m%d" \`date +"%Y%m010000"\``
[ -z $1 ] && exit 1
ENDDATE=`date -j -v +1m -v -1d +"%Y%m%d" ${1}010000`
DAYS=${ENDDATE:6:2}   # the number of last day is the length of last month 
filelistv4=""
filelistv6=""
echo "${ENDDATE:0:6}"
# get the list of daily link files
for ((i=0; i < ${DAYS}; i++)); do
  DATE=`date -j -v-${i}d +"%Y%m%d" ${ENDDATE}0000`
  v4linkdir="$_v4dailypath/${DATE:0:4}.${DATE:4:2}"
  v6linkdir="$_v6dailypath/${DATE:0:4}.${DATE:4:2}"
  [ -d $v4linkdir ] || continue
  linkfilev4="$v4linkdir/${DATE}.link.v4.gz"
  linkfilev6="$v6linkdir/${DATE}.link.v6.gz"
  [ -f $linkfilev4 ] && filelistv4="${filelistv4} ${linkfilev4}" 
  [ -f $linkfilev6 ] && filelistv6="${filelistv6} ${linkfilev6}" 
done
# monthly link file
echo $filelistv4
filev4="${_v4monthlypath}/${DATE:0:6}.link.v4.gz"
filev6="${_v6monthlypath}/${DATE:0:6}.link.v6.gz"
[ -n "$filelistv4" ] && { gzip -dc ${filelistv4} | ${_binpath}/uniqc.pl | gzip -c > ${filev4};}
[ -n "$filelistv6" ] && { gzip -dc ${filelistv6} | ${_binpath}/uniqc.pl | gzip -c > ${filev6};}

${_binpath}/plot.sh

