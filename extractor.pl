#!/usr/bin/perl
#
# Extractor -- extract AS links from BGP raw data
# =============================================================================
# USAGE: ./extractor.pl bgp_data_file
# OUTPUT: {AS1}    {AS2}     ["6"] (with convention AS1 < AS2, \t as separator)
#         appending "6" if it is observed in IPv6 networks.
# NOTE:
#   - Expected file types include [un]compressed MRT or 'show ip bgp' in 
#     plain, .bz[2], or .[g]z format. Also support plain text from STDIN.
#   - see getlink() for AS-SET, loop path, or other weird cases.
#   - Bogus ASN list is, SUBJECT TO STALENESS, retrieved on 2013-05-24 from 
#     http://www.iana.org/assignments/as-numbers/as-numbers.txt
#
# TODO:
#   - to improve performance, especially on regex and string funcs.
#
# yuzhang at hit.edu.cn 20130523

use strict;
use warnings;

sub openfile($$);   # open [un]compressed file (and pipe to bgpdump if set 1)
sub filetype($);    # guess type: TXT (show ip bgp) or BIN (means MRT)
sub getpath($);     # get AS path (or its position)
sub getlink($);     # get AS links from AS path
sub isbogus($);     # whether ASN is bogus

# HARD-CODING:
#   - the header of 'show ip bgp'
#   - remember the position of 'Path'
#
my $OPT6 = 1;                  # whether "6" is appended to links in IPv6
my $IPV6 = 0;                          # whether this is an IPv6 record
my $BGPDUMP = "bgpdump -mv -";         # bgpdump command
#my $BGPDUMP = "bgpparser2";           # bgpparser2 command
my $NETWORK = 0;    # the start position of 'Network' in 'show ip bgp'
my $ASPATH = 0;     # the start position of 'Path' in 'show ip bgp'
my %LINKS = ();                        # hashtable of links
my @BOGUSASN = (                       # bogus ASN ranges SORTED
#  [0    , 0              ],           # Reserved
   [23456 , 23456         ],           # AS_TRANS
   [62464 , 131071        ],           # Reserved
   [133120, 196607        ],           # Unallocated
   [199680, 262143        ],           # Unallocated
   [263168, 327679        ],           # Unallocated
   [328704, 393215        ],           # Unallocated
   [394240, 4294967294    ],           # Unallocated
   [4294967295, 4294967295]            # Reserved
   );

# MAIN =========================================================================
my $filename = $ARGV[0] ? $ARGV[0] : "-";
# if "-", expect plain text from STDIN; if BIN, open with BGPDUMP
my $fh = ($filename eq "-") ? \*STDIN : (&filetype($filename) eq "BIN") ?
         &openfile($filename, 1) : &openfile($filename, 0);
while(<$fh>) {
  chomp;
  map {$LINKS{$_} = 1} (&getlink(&getpath($_)));
}
close $fh;
map {print "$_\n"} grep {! &isbogus($_)} sort keys %LINKS;
exit 0;

# SUBROUTINES ==================================================================
sub openfile($$) {         # just open, remember to close later 
  my $file = shift;
  my $isbgpdump = shift;
  my $openstr = $isbgpdump ? "$file | $BGPDUMP" : $file;
  my $fh;
  if ($file =~ /\.g?z$/) {         # .gz or .z
    open($fh, '-|', "gzip -dc $openstr") or die "Can not open file $openstr: $!";
  } elsif ($file =~ /\.bz2?$/) {   # .bz2 or .bz
    open($fh, '-|', "bzip2 -dc $openstr") or die "Can not open file $openstr: $!";
  } else {                         # expect it is uncompressed 
    open($fh, '-|', "cat $openstr") or die "Can not open file $openstr: $!";
  } 
  return $fh;
}

sub filetype($) {     # guess the file type according to the % of printable ...
  my $file = shift;   # or whitespace chars. If > 90%, it is TXT, otherwise BIN.
  my $fh = &openfile($file, 0);   # just open file without bgpdump
  my $string="";
  my $num_read = read($fh, $string, 1000);
  close $fh;
  return "TXT" unless ($num_read);       # if nothing, guess "TXT" 
  my $num_print = $string =~ s/[[:print:]]|\s//g;
  return ($num_print/$num_read > 0.9 ? "TXT" : "BIN");
}

sub getpath($) {                 # read a line, return a path (or get ASPATH)
  my $line = shift;
  return unless ($line);
  if ($ASPATH) {                          # have got the position
    return if (length($line) < $ASPATH+2);# too short 
# If there is any ':' in first 5 chars of Network field, it is IPv6
    $IPV6 = rindex(substr($line, $NETWORK, 5), ':') == -1 ? 0 : 1; 
    my $path = substr $line, $ASPATH, -2; # path w/o ORIGIN code at the end
    return $path;
  } elsif ($line =~ /^([^\|]*\|){5}([^\|]*)\|([^\|]*)\|/) { # the output of 'bgpdump -mv'
# If there is any ':' in Network field, it is IPv6
    $IPV6 = index($2, ':') == -1 ? 0 : 1; 
    return $3;
  } elsif ($line =~ /Network.*Path/) {     # the header of 'show ip bgp'
    $NETWORK = index($line, "Network");    # remember the position of 'Network'
    $ASPATH = index($line, "Path");        # remember the position of 'Path'
  }
  return;
}

sub getlink($) {                 # read a path, return an array of links
  my $path = shift;
  return unless ($path);
  $path =~ s/\{[^\}]*\}/0/g;                # replace all AS-SETs with token '0'
  my @ases = split /\s+/, $path;
  my $last_as = 0;                          # token '0'
  my %detect_loop = ();                     # for loop detecting
  my @link = ();                            # store links
  foreach my $as (@ases) {
    if ($as !~ /^\d+$/) {                   # not asplain
      return if ($as !~ /^(\d+)\.(\d+)$/);  # neither asdot, then discard it!
      $as = ($1 << 16) + $2;                # if asdot, convert it to asplain
    }
    next if ($last_as eq $as);              # skip prepending ASes 
    return if (exists $detect_loop{$as});   # loop! Discard it!
    $detect_loop{$as}=1 unless ($as==0);    # otherwise remember it, except token '0'
# add a link with convention: AS1 < AS2; if OPT6 == 1 and IPV6 == 1, append "\t6".
    my $newlink = ($as < $last_as ?  "$as\t$last_as" : "$last_as\t$as");
    $newlink .= ($IPV6? "\t6" : "") if ($OPT6);
    push @link, $newlink if ($as and $last_as); # if two ASes is not '0'
    $last_as = $as;
  }
  return @link;
}

sub isbogus($) {
  my @asn = split "\t", $_[0];
  foreach my $range (@BOGUSASN) {           # @BOGUSASN must be sorted
    return 0 if ($asn[1] <  $range->[0]);   # ASN0 < ASN1 < lower bound
    next     if ($asn[0] >  $range->[1]);   # upper bound < ASN0 < ASN1 
    return 1 if ($asn[1] <= $range->[1] or $asn[0] >= $range->[0]);
  }
  return 0;
}
# END MARK
