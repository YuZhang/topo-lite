#!/usr/bin/perl

# get AS paths from 'bgpdump -mv' or 'show ip bgp'
#
# yzhang 20130524

use strict;
use warnings;

my $position=0;          # the start position of 'Path' in 'show ip bgp'

while(<>) {
  chomp;
  if ($position) {                       # have got the position
    my $s = substr $_, $position;        # path is from position to $
    $s =~ s/[^\d\}]*$//;                 # remove non-[ digit and } ] at the end
    print "$s\n";
  } elsif (/^(.*?\|){6}(.*?)\|/) {       # the output of 'bgpdump -mv'
    print "$2\n";
  } elsif (/Network.*Path/) {            # the header of 'show ip bgp'
    $position = index($_, "Path");       # remember the position of 'Path'
  }
}

