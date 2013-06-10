#!/usr/local/bin/bash
# Check the raw BGP data files in local storage from StartDate to ENDDate
# If file is missing, output URLs pointing to the BGP Collectors' Repo,
# as well as the local path.
# test on GNU bash, version 4.1.9(0)-release (amd64-portbld-freebsd7.4)
# yzhang 20130601

# Parameters example:
# PathTemp="/lab/bgp/rv/oreg/RIBS/<YYYY>.<MM>/<DD>"
# URLTemp="http://archive.routeviews.org/bgpdata/<YYYY>.<MM>/RIBS/rib.<YYYY><MM><DD>.<HH><mm>.bz2"
# StartDate=20130605  # the starting date of period, e.g., 20130305
# EndDate=20130605  # the ending date of period, e.g., 20130305

echoerr() { echo "---> $@" 1>&2; }

main () {
  if [ $# -ne 4 ]; then
    echo "Usage: ${0##*/} LocalPathTemplate URLTemplate EndDate Days"
    exit 1
  fi
  BeginDate=$3
  EndDate=$4
  let Days=( `date -j +%s ${EndDate}0000` - `date -j +%s ${BeginDate}0000` )/86400
  for ((i=0; i <= ${Days}; i++)); do
    Date=$(date -j -v-${i}d +"%Y%m%d" ${EndDate}0000)
    rawpath=$(echo "$1" | \
         perl -pe "s/\<YYYY\>/${Date:0:4}/g; s/\<MM\>/${Date:4:2}/g; s/\<DD\>/${Date:6:2}/g")
    rawurl=$(echo "$2" | \
          perl -pe "s/\<YYYY\>/${Date:0:4}/g; s/\<MM\>/${Date:4:2}/g; s/\<DD\>/${Date:6:2}/g")
    file_exist "$rawpath" || get_list "${rawpath}" "${rawurl}"
  done
  exit 0
}

file_exist () {
  if [ ! -d $1 ]; then
     echoerr "$1 not found" 
     return 1
  fi
  if [ "$(ls -A $1)" ]; then
     echoerr "$1 is not empty"
     return 0
  else
     echoerr "$1 is empty"
     return 2
  fi
}

get_list () {
  rawpath=$1
  rawurl=$2
  if [[ $rawurl =~ \<.*\> ]] ; then
    urlpath=${rawurl%/*}
    urlfile=${rawurl##*/}
    urlfilepattern=$( echo ${urlfile} | perl -pe 's/\./\\./g; s/<.*?>/.+?/g')
    echoerr "URL TBD: ${urlpath}/${urlfilepattern}"
    filelist=($(curl -sSL ${urlpath}/ | \
             perl -ne  "while (/<a\\s*href\\s*=\\s*\"(${urlfilepattern})\">.*?<\\/a>/igs) { \
                        print \"\$1\\n\";}")) 
    if [  ${#filelist[@]} = 0  ]; then
      echoerr "No link matches the pattern"
    else
      echoerr "Find links matching the pattern"
      for j in "${filelist[@]}"; do
        echo "${rawpath} ${urlpath}/$j"
      done
    fi
  else
    echoerr "Fetch files directly"
    echo "${rawpath} ${rawurl}"
  fi  
}

main $@

