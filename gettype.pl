#!/usr/bin/perl

use strict;
use warnings;

($#ARGV + 1 == 1) or die "Usage: ribtype filename";

my $file = $ARGV[0];
my $fh;

if ($file =~ /\.gz$/) {
  open($fh, '<', "gzip -dc | $file") or die "Can not open file $file: $!";
} elsif ($file =~ /\.bz2/) {
  open($fh, '<', "bzip2 -dc | $file") or die "Can not open file $file: $!";
} 

