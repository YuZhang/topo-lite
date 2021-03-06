#!/usr/local/bin/bash

_binpath=/lab/topology/topolite/scripts         # script path
_statspath=${_binpath}/stats
_rawbgppath="/lab/bgp/rv /lab/bgp/ripe /lab/bgp/abilene /lab/bgp/routeservers.pch"
_topopath=/lab/topology/topolite
_datapath=${_topopath}/dailycollector           # date-collector topology data path
_logpath=${_topopath}/log                       # log file path
_v4dailypath=${_topopath}/ipv4/daily  
_v6dailypath=${_topopath}/ipv6/daily   
_v4monthlypath=${_topopath}/ipv4/monthly
_v6monthlypath=${_topopath}/ipv6/monthly 
