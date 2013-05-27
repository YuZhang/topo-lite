#!/usr/bin/perl

# sort & uniq unsorted lines
# yzhang 20130524

use strict;
use warnings;

my %hash;

while(<>) {
  $hash{$_}=1;
}

foreach (keys %hash) {
  print "$_";
}
