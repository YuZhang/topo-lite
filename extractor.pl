#!/usr/bin/perl

# Extract AS links in format 'YYYYMMDD ASN1 ASN2' from 'bgpdump -mv' MRT
# also discard AS-SETs, filter out bogus ASNs, and skip loop paths. 
#
# Input: TABLE_DUMP|1027381055|B|193.203.0.1|1853|3.0.0.0/8|1853 1239 80|IGP|193.203.0.1|0|0||NAG||
# Output: 'YYYYMMDD ASN1 ASN2' (convention: ASN1 < ASN2 as undirected links, \t as field seperator)
#
# Note:
# - Don't warry about 32bit ASN. bgpdump and perl can handle it.
# 
# yzhang 20130524

use strict;
use warnings;

my $BOGUS_ASN_FILE = "bogus-asn.txt";  # bogus ASN file name
my @BOGUS_ASN = ();                    # a list of bogus ASN ranges
my %LINKS = ();                        # AS links with timestamp YYYYMMDD

sub load_bogus_asn($); 
sub is_bogus($);
sub extract_from_mrt($);
sub dump_links($);

# ========= MAIN ============================================
&load_bogus_asn($BOGUS_ASN_FILE);
while(my $line = <>) {
  my @result = &extract_from_mrt($line);
  next unless (@result);
  my $ts = shift @result;
  $LINKS{$ts} = {} unless (exists $LINKS{$ts});
  foreach (@result) {
    $LINKS{$ts}{$_}=1;
  }
}
&dump_links(\%LINKS);
# ========= END =============================================

sub load_bogus_asn($) {
  my $fn = shift;
  open(my $fh, "<", $fn) or die "cannot open < $fn $!";
  while(<$fh>) {
    chomp;
    $_ =~ s/^\s+//;
    my @record = split /\s+/, $_ || "0";
    if ($record[0] =~ /^(\d+)-(\d+)$/) {
      push @BOGUS_ASN, [$1, $2];
    } elsif ($record[0] =~ /^\d+$/) {
      push @BOGUS_ASN, [$record[0], $record[0]];
    }
  } 
  close $fh;
}

sub is_bogus($) {
  my $asn  = shift;
  foreach my $range (@BOGUS_ASN) {
    return 1 if ($asn >= $range->[0] and $asn <= $range->[1]);
  }
  return 0;
}

# return timestamp, link1, link2 ...
sub extract_from_mrt($) {
  my @result = ();
  my $line = shift;
  chomp $line;
  my @record = split /\|/, $line;
  return unless (defined $record[7]);       # not a valid record  
  return unless ($record[1] =~ /^\d+$/);    # not a valid timestamp
  my @time = localtime($record[1]);         # convert UNIX timestamp to YYYYMMDD
  my $ts = ($time[5]+1900) . (sprintf "%02d" , ($time[4]+1)) . $time[3];
  push @result, $ts;
  
  my @ases = split /\s+/, $record[6];
  my $last_as = $ases[0];
  my %detect_loop = ($last_as => 1);        # for loop detecting  
  foreach my $as (@ases) {
    next if ($last_as eq $as);              # skip appending AS
    return if (exists $detect_loop{$as});   # loop! skip the whole path
    $detect_loop{$as}=1;                    # otherwise, remember it
# make sure it is a valid link, dsicard AS-SET, and filter out bogus ASNs
# then add a link to the result with convention: AS1 < AS2
    if ("$as\t$last_as" =~ /^(\d+)\t(\d+)$/ and not &is_bogus($1) and not &is_bogus($2)) {
      push @result, ($as < $last_as ?  "$as\t$last_as" : "$last_as\t$as");
    }
    $last_as = $as;
  }
  return @result;
}

sub dump_links ($) {
  my $link = shift;
  foreach my $ts (sort keys %$link) {
    foreach my $lk (keys %{$link->{$ts}}) {
      print "$ts\t$lk\n";
    }
  }
}

