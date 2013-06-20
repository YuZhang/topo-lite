#!/usr/bin/perl
# uniq input records and print records with frequencies
# just like "sort | uniq -c" 

my %hash = ();
while(<>) {
  chomp;
  $hash{$_}=0 unless (exists $hash{$_});
  $hash{$_}++;
}
foreach (sort keys %hash) { print "$_\t$hash{$_}\n"; }
