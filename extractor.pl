#!/usr/bin/perl
#
# Extractor -- extract AS links from BGP raw data
# =============================================================================
# USAGE: ./extractor.pl bgp_data_file
# OUTPUT: {AS1}\t{AS2}\n  (with convention: AS1 < AS2)
# NOTE:
#   - expected file types inlucding [un]compressed MRT or 'show ip bgp' in 
#     plain, .bz[2], or .[g]z format. Also support plain text from STDIN.
#   - see getlink() for AS-SET, loop path, or other wierd cases.
#   - bogus ASN list from 
#     http://www.iana.org/assignments/as-numbers/as-numbers.txt
#     retrived on 2013-05-24
#
# TODO:
#   - speed up getlink(), especially on regexp

use strict;
use warnings;

sub openfile($$);   # open [un]compressed file (and pipe to bgpdump if set 1)
sub filetype($);    # guess type: TXT (show ip bgp) or BIN (means MRT)
sub getpath($);     # get AS path (or its position)
sub getlink($);     # get AS links from AS path
sub is_bogus($);    # whether ASN is bogus
sub load_bogus($);  # load BOGUS_ASN_FILE

# HARDCODE:
#   - the header of 'show ip bgp' 
#   - remember the position of 'Path'   
#
my $BGPDUMP = "bgpdump -mv -";         # bgpdump commond
my $BOGUS_ASN_FILE = "bogus-asn.txt";  # bogus ASN file name
my $POSITION = 0;   # the start position of 'Path' in 'show ip bgp'
my %LINKS = ();                        # hashtable of links          
my @BOGUS_ASN = ();                    # a list of bogus ASN ranges

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
&load_bogus_asn($BOGUS_ASN_FILE);
foreach (keys %LINKS) {    # dump links with a bogus filter
  next if ($_ !~ /^(\d+)\s+(\d+)$/ or is_bogus($1) or is_bogus($2));
  print "$_\n";
}
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

sub getpath($) {                 # read a line, return a path (or POSITION)
  my $line = shift;
  return unless ($line);
  if ($POSITION) {                          # have got the position
    return if (length($line) < $POSITION);  # too short 
    my $path = substr $line, $POSITION;     # path is from position to $
    $path =~ s/[^\d\}]*$//;                 # remove non-[ digit or } ] at the end
    return $path;
  } elsif ($line =~ /^(.*?\|){6}(.*?)\|/) { # the output of 'bgpdump -mv'
    return $2;
  } elsif ($line =~ /Next Hop.*Path/) {     # the header of 'show ip bgp'
    $POSITION = index($line, "Path");       # remember the position of 'Path'
  }
  return;
}

sub getlink($) {                 # read a path, return an array of links
  my $path = shift;
  return unless ($path);
  $path =~ s/\{.*?\}/0/g;                   # replace all AS-SETs with token '0'  
  my @ases = split /\s+/, $path;            
  my $last_as = 0;                          # token '0'
  my %detect_loop = ();                     # for loop detecting  
  my @link = ();                            # store links
  foreach my $as (@ases) {                  
    if ($as !~ /^\d+$/) {                   # not a number 
      return if ($as !~ /^(\d+)\.(\d+)$/);  # neither asdot, then discard it! 
      $as = ($1 << 16) + $2;                # if asdot, convert it to asplain
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

sub load_bogus_asn($) {
  my $fn = shift;
  open(my $fh, "<", $fn) or die "cannot open < $fn $!";
  while(<$fh>) {
    chomp;
    $_ =~ s/^\s+//;
    my @record = split /\s+/, $_ || "0";
    if ($record[0] =~ /^(\d+)-(\d+)$/) {   # a range ASN1-ASN2
      push @BOGUS_ASN, [$1, $2];
    } elsif ($record[0] =~ /^\d+$/) {      # a single ASN
      push @BOGUS_ASN, [$record[0], $record[0]];
    }
  } 
  close $fh;
}

sub is_bogus($) {
  my $asn  = shift;
  foreach my $range (@BOGUS_ASN) {
    return 1 if ($asn >= $range->[0] and $asn <= $range->[1]);
  }
  return 0;
}

# END MARK
