#!/usr/bin/perl -Wall

# extract 'YYYYMMDD ASN1 ASN2' from the output of 'bgpdump -mv'
# convention: ASN1 < ASN2 in undirected link
#
# input example:
# TABLE_DUMP|1027381055|B|193.203.0.1|1853|3.0.0.0/8|1853 1239 80|IGP|193.203.0.1|0|0||NAG||
# output example:
# 1027381055	1853	20965
#
# Don't warry about 32bit ASN. bgpdump and perl can handle it.
# 
# yzhang 20130524

use strict;
$\=''; #reset the end of line

my %links;

while(my $line = <>) {
  chomp $line;
  my @record = split /\|/, $line;
  next unless ($record[6]);  
  my @time = localtime($record[1]);
  my $ts = ($time[5]+1900) . (sprintf "%02d" , ($time[4]+1)) . $time[3];
  $links{$ts} = {} unless (defined $links{$ts});
  
  my @ases = split / /, $record[6];
  my $last_as = $ases[0];

  foreach my $as (@ases) {
    # make sure it looks like a link
    if ($last_as =~ /^\d+$/ and $as =~ /^\d+$/ and $last_as != $as) {
      my $newlink = ($as < $last_as) ?  "$as\t$last_as" : "$last_as\t$as";
      $links{$ts}{$newlink}=1;
    }
    $last_as = $as;
  }
}

foreach my $ts (sort keys %links) {
  foreach my $link (keys %{$links{$ts}}) {
    print "$ts\t$link\n";
  }
}
