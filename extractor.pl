#!/usr/bin/perl

# extract 'YYYYMMDD ASN1 ASN2' from the output of 'bgpdump -mv'
# convention: ASN1 < ASN2 as undirected links
# with a bogus ASN filter
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
use warnings;

my $bogus_asn_file = "bogus-asn.txt";  #bogus ASN file name
my @bogus_asn;                         #a list of bogus ASN ranges
my %links;                             #AS links with timestamp YYYYMMDD

sub load_bogus_asn($); 
sub is_bogus($);
sub extract_from_bgpdump($);
sub dump_links();

# ========= MAIN ============================================
&load_bogus_asn($bogus_asn_file);
while(my $line = <>) {
  &extract_from_bgpdump($line);
}
&dump_links();
# ========= END =============================================

sub load_bogus_asn($) {
  my $fn = shift;
  open(my $fh, "<", $fn) or die "cannot open < $fn $!";
  while(<$fh>) {
    chomp;
    $_ =~ s/^\s+//;
    my @record = split /\s+/, $_ || "0";
    if ($record[0] and $record[0] =~ /^(\d+)-(\d+)$/) {
      push @bogus_asn, [$1, $2];
    } elsif ($record[0] =~ /^\d+$/) {
      push @bogus_asn, [$record[0], $record[0]];
    }
  } 
  close $fh;
}

sub is_bogus($) {
  my $asn  = shift;
  foreach my $range (@bogus_asn) {
    return 1 if ($asn >= $range->[0] and $asn <= $range->[1]);
  }
  return 0;
}

sub extract_from_bgpdump($) {
  my $line = shift;
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

sub dump_links () {
  foreach my $ts (sort keys %links) {
    foreach my $link (keys %{$links{$ts}}) {
      #filter out bogus ASNs
      next if ($link !~ /^(\d+)\t(\d+)$/ or &is_bogus($1) or &is_bogus($2));
      print "$ts\t$link\n";
    }
  }
}

