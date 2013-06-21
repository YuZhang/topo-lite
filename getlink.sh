#!/usr/local/bin/bash
# Extract AS link files from a given directory ($1)
# yzhang at hit.edu.cn 20130601

source ${TOPOLITEPATH}/topolite.conf.sh 

bgpdir=${1:?"missing BGP raw data path"}
[ -d $bgpdir ] || exit
# Get the collector name and date from the path,
# e.g., /A/.tmp/bgp/ripe/rrc00/RIBS/2013.06/01, 
# where the collector name is ripe.rrc00 and the date is 20130601.
# Also remove redundant string 'routeservers\.' from PCH's name
collector=`echo $bgpdir | perl -pe 's/^.*\/([^\/]+)\/([^\/]+)\/(UPDATES|RIBS).*$/$1.$2/; s/-//g; s/routeservers\.//g'` 
yearmonth=`echo $bgpdir | perl -pe 's/^.*(UPDATES|RIBS)\/([^\/]+)\/.*$/$2/;'` 
day=`echo $bgpdir | perl -pe 's/^.*(UPDATES|RIBS)\/[^\/]+\/([^\/]+).*$/$2/;'` 
date=`echo ${yearmonth}${day} | sed 's/\.//'` 
linkfile="${_datapath}/${yearmonth}/${day}/${date}-${collector}.gz"
[ -d $_datapath/$yearmonth/$day/ ] || mkdir -p $_datapath/$yearmonth/$day
#echo `date "+[%Y-%m-%d %H:%M:%S]"` $bgpdir
for bgpfile in `find -s $bgpdir -type f` 
do
  #echo `date "+[%Y-%m-%d %H:%M:%S]"` $bgpfile $linkfile
  ${_binpath}/extractor.pl $bgpfile | gzip -c >> $linkfile
done
gzip -dc $linkfile | ${_binpath}/uniq.pl | gzip -c > $linkfile.uniq 
mv -f $linkfile.uniq $linkfile
