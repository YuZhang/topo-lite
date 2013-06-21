#!/usr/local/bin/bash
export PATH=${PATH}:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/lab/topology/topolite/scripts
export TOPOLITEPATH=/lab/topology/topolite/scripts
source ${TOPOLITEPATH}/topolite.conf.sh
echo `date -j -v -1m +"# start monthly job %Y%m"` &>>  ${_logpath}/monthly.log
${_binpath}/monthlyunion.sh `date -j -v -1m +"%Y%m"` &>> ${_logpath}/monthly.log
