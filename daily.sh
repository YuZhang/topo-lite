#!/usr/local/bin/bash
export PATH=${PATH}:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/lab/topology/topolite/scripts
export TOPOLITEPATH=/lab/topology/topolite/scripts
source ${TOPOLITEPATH}/topolite.conf.sh
echo `date -j -v -2d +"# start daily job %Y%m%d"` &>> ${_logpath}/daily.log
${_binpath}/dailyextract.sh `date -j -v -2d +"%Y%m%d"` 0 &>> ${_logpath}/daily.log
