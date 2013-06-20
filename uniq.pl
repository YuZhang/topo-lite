#!/usr/bin/perl

my %hash=();
while(<>) { $hash{$_}=1; }
foreach (sort keys %hash) { print "$_"; }
