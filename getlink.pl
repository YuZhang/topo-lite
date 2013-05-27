#!/usr/bin/perl

# Extract AS links from AS paths 
# also convert asdot to asplain, skip AS-SETs and discard loop or other weird paths. 
#
# Output: 'ASN1 ASN2' (convention: ASN1 < ASN2 as undirected links, \t as field seperator)
# 
# yzhang 20130524

use strict;
use warnings;

sub parse($);

while(<>) {
  chomp;
  my @links = &parse($_);
  next unless (@links);
  foreach (@links) {
    print "$_\n";
  }
}

sub parse($) {
  my $line = shift;
  $line =~ s/\{.*?\}/0/g;                   # replace all AS-SETs with token '0'  
  return unless ($line =~ /^[\d\s\.]+$/);   # weird! discard it! 
  my @ases = split /\s+/, $line;
  my $last_as = 0;                          # token '0'
  my %detect_loop = ();                     # for loop detecting  
  my @link = ();                            # store links
  foreach my $as (@ases) {
    if ($as =~ /^(\d+)\.(\d+)$/) {          # convert asdot to asplain
      $as = ($1 << 16) + $2;
    } elsif ($as !~ /^(\d+)$/) {            # if not an ASN, 
      return;                               # then discard it! 
    }
    next if ($last_as eq $as);              # skip appending AS
    return if (exists $detect_loop{$as});   # loop! discard it! 
    $detect_loop{$as}=1 unless ($as==0);    # otherwise remember it, except token '0'
# add a link with convention: AS1 < AS2, both LAST_AS and AS should not be token '0'
    push @link, ($as < $last_as ?  "$as\t$last_as" : "$last_as\t$as") if ($last_as and $as);
    $last_as = $as;
  }
  return @link;
}

