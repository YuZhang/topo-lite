#!/usr/local/bin/bash
# plot the topology evolution graph 
# test on GNU bash, version 4.1.9(0)-release (amd64-portbld-freebsd7.4)
# yzhang 20130601

source ${TOPOLITEPATH}/topolite.conf.sh

function countnumber () {
  filename=$1
  [ -f $filename ] ||  return 1
  f_date=${filename##*/}
  f_date=${f_date%%.*}
  nr_edge=$(gzip -dc ${filename} | wc -l)
  nr_node=$(gzip -dc ${filename} | cut -f1,2 | perl -pe 's/\t/\n/' | ${_binpath}/uniq.pl | wc -l)
  echo $f_date $nr_node $nr_edge
  return 0
}

function processdir () {
  for file in `find -s $1 -type f`; do
    countnumber $file
  done
}


processdir ${_v4monthlypath} > ${_statspath}/v4monthly.txt
processdir ${_v6monthlypath} > ${_statspath}/v6monthly.txt

gnuplot ${_binpath}/monthly.gnuplot

[ -f ${_statspath}/monthly.svg ] && cp -f ${_statspath}/monthly.svg ${_topopath}/monthly.svg

