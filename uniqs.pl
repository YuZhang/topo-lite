#!/usr/bin/perl
# seperate IPv4 and IPv6 links
my %hash4=();
my %hash6=();
while(<>) { 
  chomp;
  if (/^(\d+\t\d+)\t6$/) { $hash6{$1}=1;
  } elsif (/^\d+\t\d+$/) { $hash4{$_}=1;
  }
}
foreach (sort keys %hash4) { print "$_\n"; }
foreach (sort keys %hash6) { print STDERR "$_\n"; }
