topo-lite
=========

Extract AS topology from 4 BGP data collection projects

- Configuration
  - all scripts read `${TOPOLITEPATH}/topolite.conf.sh`, so ${TOPOLITEPATH} should be exported.
  - `topolite.conf.sh` :  declare paths to scripts, BGP raw data, topology data, log ...
  - the following commands need to be found in $PATH:
      `bgpdump`, `gzip`, `bzip2`, `cat`, `find`, `perl`, `grep`, `sed`, `date`

- topo-lite runs via crontab:
```
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/lab/topology/topolite/scripts
TOPOLITEPATH="/lab/topology/topolite/scripts"
0 1 * * * /lab/topology/topo-lite/scripts/dailyextract.sh `date -j -v -3d +"%Y%m%d"` 0 
0 23 * * 5 /lab/topology/topo-lite/scripts/monthlyunion.sh `date -j -v -1m +"%Y%m"`
```

- Scripts:
  - `bgpdump`          :  [A modified version of bgpdump](https://github.com/YuZhang/bgpdump-zy).
  - `extractor.pl`     :  extract AS-AS links from a BGP raw data file (with `bgpdump` for MRT format data)
  - `getlink.sh`       :  extract links from a directory of raw data with `extractor.pl`
  - `runtopojob.sh`    :  run `getlink.sh` to process NEWLY downloaded raw data 
  - `dailyextract.sh`  :  run `getlink.sh` to process raw data on given days
  - `dailyunion.sh`    :  aggregate links from individual collectors into a daily union file
  - `monthlyunion.sh`  :  aggregate links from individual daily files into a monthly union file
  - `uniq.pl`          :  a `uniq` tool by utilizing perl's hash
  - `uniqs.pl`         :  a `uniq` tool seperating IPv4 and IPv6 topology data
  - `uniqc.pl`         :  a `uniq -c` tool 

- Repositories of BGP data collection projects:
  - [University of Oregon Route Views](http://archive.routeviews.org)
  - [RIPE RIS Raw Data](http://data.ris.ripe.net)
  - [PCH Route-Server RIB Dumps](https://www.pch.net/resources/data.php)
  - [Internet2 NOC BGP RIB Dumps](http://ndb7.net.internet2.edu/bgp)
  - [The list of collectors](collectors.txt).

