#!/usr/bin/perl

use strict;
use warnings;

sub openfile($$);             # open [un]compressed file (and pipe to bgpdump if set 1)
sub filetype($);              # guess the type of file: TXT (show ip bgp) or BIN (means MRT)

($ARGV[0]) or die "usage: inputfile";
$|=1;                         # flush output
my $filename = shift;
(-f $filename) or die "can not find $filename";
my $fh = (&filetype($filename) eq "TXT") ? &openfile($filename, 0) :  &openfile($filename, 1);
while(<$fh>) {print;}
close $fh;

sub openfile($$) {
  my $file = shift;
  my $isbgpdump = shift;
  my $openstring = $isbgpdump ? "$file | bgpdump -mv -" : $file;
  my $fh;
  if ($file =~ /\.gz$/) {
    open($fh, '-|', "gzip -dc $openstring") or die "Can not open file $openstring: $!";
  } elsif ($file =~ /\.bz2?$/) {
    open($fh, '-|', "bzip2 -dc $openstring") or die "Can not open file $openstring: $!";
  } else {
    open($fh, '-|', "cat $openstring") or die "Can not open file $openstring: $!";
  } 
  return $fh;
}

# guess the file type by counting the % of printable chars 
sub filetype($) {
  my $file = shift;
  my $fh = &openfile($file, 0);
  my $onebyte;
  my $num_print = 0;
  for (1 .. 500) {
    read($fh, $onebyte, 1);
    $num_print ++ if ($onebyte =~ /[[:print:]]/ );
  }
  close $fh;
  return ($num_print > 400? "TXT" : "BIN");
}
