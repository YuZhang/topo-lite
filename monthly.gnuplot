#!/usr/local/bin/gnuplot -persist
#	Version 4.2 patchlevel 4 
set border 31 front linetype -1 linewidth 1.000
set xdata time
set timefmt x "%Y%m"
set format x "%Y"
set format y "% g"
set grid
set key inside left top vertical Right noreverse enhanced autotitles box
set key noinvert samplen 6 spacing 1 width 0 height 0 
set style increment default
set size ratio 0.6
set ticslevel 0.5
set title "The Growth of Internet AS-level Topology" font ",16"
set xrange ["199901": * ] noreverse nowriteback
set terminal svg enhanced font 'Helvetica,10'
set style line 1 lt 1 lc rgb "#DC143C" lw 3
set style line 2 lt 1 lc rgb "#FF8C00" lw 3
set style line 3 lt 1 lc rgb "#4169E1" lw 3
set style line 4 lt 1 lc rgb "#9ACD32" lw 3
path="`echo "${TOPOLITEPATH}/stats"`"
svgpath=sprintf("\"%s/monthly.svg\"", path)
v4path=sprintf("\"%s/v4monthly.txt\"", path)
v6path=sprintf("\"%s/v6monthly.txt\"", path)
set macros
set output @svgpath
plot @v4path u 1:3 w l ls 1 t 'IPv4 links', \
     @v4path u 1:2 w l ls 2 t 'IPv4 nodes', \
     @v6path u 1:3 w l ls 3 t 'IPv6 links', \
     @v6path u 1:2 w l ls 4 t 'IPv6 nodes'
