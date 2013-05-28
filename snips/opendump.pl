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

sub filetype($) {     # guess the file type by counting the % of printable ...
  my $file = shift;   # or whitespace chars. If > 80%, it is TXT, otherwise BIN.
  my $fh = &openfile($file, 0);
  my $string="";
  my $num_read = read($fh, $string, 1000);
  close $fh;
  return "TXT" unless ($num_read);       # if nothing, guess "TXT" 
  my $num_print = $string =~ s/[[:print:]]|\s//g;
  return ($num_print/$num_read > 0.8 ? "TXT" : "BIN");
}

