#!/usr/bin/perl

# filter out bogus ASNs according to bogus-asn.txt
# http://www.iana.org/assignments/as-numbers/as-numbers.txt retrived on 2013-05-24
# 0                 Reserved  
# 23456             AS_TRANS 
# 62464-131071      Reserved
# 133120-196607     Unallocated
# 199680-262143     Unallocated
# 263168-327679     Unallocated
# 328704-393215     Unallocated
# 394240-4294967294 Unallocated
# 4294967295        Reserved

use strict;
use warnings;

my $BOGUS_ASN_FILE = "bogus-asn.txt";  # bogus ASN file name
my @BOGUS_ASN = ();                    # a list of bogus ASN ranges

sub is_bogus($);
sub load_bogus_asn($);

&load_bogus_asn($BOGUS_ASN_FILE);
while(<>) {
  chomp;
  next if ($_ !~ /^(\d+)\s+(\d+)$/ or is_bogus($1) or is_bogus($2));
  print "$_\n";
}

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
