#!/usr/bin/perl
#
# Extractor -- extract AS links, IP prefix orgins, and monitors from BGP raw data
# =============================================================================
# USAGE: see Usage below (./extractor.pl -h) 
# INPUT: a batch of BGP data file names from STDIN or @ARGV
# OUTPUT: \t as separator
#         appending "4/6" if it is observed in IPv4/IPv6 networks
#         {#monitors} The number of monitors that observed a particular link/prefix.
#         {#prefixes} The number of prefixes which are observed by the monitor.
#         {message No.} The message No. which inludes a particular link/prefix/monitor.
#
#         .links file: AS links 
#         Format: {AS1}    {AS2}     4/6     {#monitors}     {message No.}
#         with convention AS1 le AS2
#
#         .origins file: prefix orgins
#         Format: {IP Prefix}     {Origin ASN}     4/6     {#monitors}     {message No.}
#
#         .monitors file: Monitor list
#         Format: {Next hop}   {First ASN}   {Peer}    {Peer ASN}   4/6    {#prefixes}     {message No.} 
#         {Peer ASN} and {Peer} are only provided by MRT and are 0 for 'show ip bgp' output
#
#         .messages file: rib/update messages
#         Format: {message No.}   {message}
#         raw data file name is included in a format: #\t{filename}
# NOTE:
#   - Expected file types include [un]compressed MRT or 'show ip bgp' in 
#     plain, .bz[2], or .[g]z format. Also support plain text from STDIN.
#   - see getlink() for AS-SET, loop path, or other weird cases.
#   - The origin of an IP prefix is the last AS/AS-SET at the end of path.
#
# TODO:
#   - to improve performance, especially on regex and string funcs.
#
# AUTHORS:
#   - yuzhang at hit.edu.cn 2013-2014
#
# CHANGE LOG:
# - 2013.05 - Beta. extract AS links
# - 2014.12 - Add. Extract origins, monitors and messages
#             Add. Batch process on mulitple files
#             Mod. Do lazy validation check just before outputing
#             Del. Not filter out Bogus ASNs nor AS-SETs  
#
# Examples of input
# Example of 'show ip bgp' 
#
#   Network          Next Hop            Metric LocPrf Weight Path
#*> 1.0.0.0/24       198.32.146.46            0             0 15169 i
#*> 1.0.4.0/24       198.32.146.50            0             0 6939 7545 56203 i
#
# Example of MRT table dump
#TABLE_DUMP|1027381055|B|193.203.0.1|1853|12.1.245.0/24|1853 1239 1 11521|IGP|193.203.0.1|0|0||NAG||
#TABLE_DUMP|1027381055|B|193.203.0.1|1853|12.2.41.0/24|1853 1239 7018 13606|IGP|193.203.0.1|0|0||AG|13606 12.2.41.25|
#
# Example of MRT update 
#BGP4MP|1279829702|A|193.203.0.21|8447|117.41.0.0/19|8447 6939 10026 4809|IGP|193.203.0.21|0|0|1120:1 no-export|AG|4809 59.43.5.90|
#BGP4MP|1279829711|W|193.203.0.21|8447|214.6.167.0/24
#

use strict;
use warnings;

my $HELP = '
  Usage: extractor.pl [OPTIONS] [files]

  When [files] is empty, read file names from STDIN
  OPTIONS:
  -    read txt-format BGP data from STDIN
  -a   append outputs
  -h   print this help message
  -p   the prefix of output file names
  -z   output with gzip
';

sub getoption();      # get options and open output files
sub process($);       # process BGP file 
sub openfile($$);     # open [un]compressed file (and pipe to bgpdump if set 1)
sub filetype($);      # guess type: TXT (show ip bgp) or BIN (means MRT)
sub getpath();        # get AS path (or its position)
sub getlink($);       # get AS links from AS path
sub output_link($);   # whether a link is valid
sub output_origin($); # whether a prefix is valid
sub output_mointor($);# whether a moinitor is valid

# HARD-CODING:
#   - the header of 'show ip bgp'
#   - remember the position of 'Path'
#

my $IPV6 = 0;     # whether this is an IPv6 record
my $BGPDUMP = "bgpdump -mv -t change -";  # bgpdump command
my $VERBOSE = 0;  # verbose output flag
my $FILENAME;     # BGP data file name
my $MESSAGE;      # current message
my $PATH;         # current AS path
my $NET_POS = 0;  # the start position of 'Network' in 'show ip bgp'
my $PATH_POS = 0;   # the start position of 'Path' in 'show ip bgp'
my $NEXTHOP_POS = 0;  # the start position of 'Next Hop' in 'show ip bgp'
my $IP_PREFIX;    # IP prefix
my $MONITOR;      # monitor (peer) 's IP addr 
my $MONITOR_AS;   # monitor (peer) 's ASN 
my $NEXTHOP;      # next_hop IP addr
my %ORIGINS;      # IP prefix origin table
my %LINKS;        # AS link table
my %MONITORS;     # monitor set
my $MONITOR_ID=1; # monitor id
my $MESSAGE_ID=1; # message number

# MAIN =========================================================================
# GET OPTIONS AND OPEN OUTPUT FILES
my ($topo_fh, $origin_fh, $monitor_fh, $message_fh, %options);
&getoption();

# PROCESSING FILES
unless (@ARGV) { while (<STDIN>) { chomp; &process($_); } }
foreach (@ARGV) { &process($_); }

# OUTPUT AND CLOSE FILES
print $topo_fh join("\n", grep { defined } map{&output_link($_)} sort keys %LINKS) . "\n";
print $origin_fh join("\n", grep { defined } map{&output_origin($_)} sort keys %ORIGINS) . "\n";
print $monitor_fh join("\n", grep { defined } map{&output_monitor($_)} sort keys %MONITORS) . "\n";
close($topo_fh);
close($origin_fh);
close($monitor_fh);
close($message_fh);
exit 0;

# SUBROUTINES ==================================================================

sub getoption() {
  use Getopt::Std;
  Getopt::Std::getopts("ahp:vz", \%options);
  defined $options{h} && die $HELP;
  my $out_cmd = ((defined $options{z}) ? "| gzip -c " : " ") .
                ((defined $options{a}) ? ">> " : "> ") ;
  my $out_sfx = (defined $options{z}) ? ".gz" : "" ;
  $options{p} ||= "bgp";
  open($topo_fh, "$out_cmd $options{p}.links$out_sfx") || die "Can not open links file: $!";
  open($origin_fh, "$out_cmd $options{p}.origins$out_sfx") || die "Can not open orgins file: $!";
  open($monitor_fh, "$out_cmd $options{p}.monitors$out_sfx") || die "Can not open monitors file: $!";
  open($message_fh, "$out_cmd $options{p}.messages$out_sfx") || die "Can not open messages file: $!";
}

sub process($) {           # process a BGP file
  my $filename = shift;
  unless (-f $filename or $filename eq '-') {
    warn "Warning: File `$filename' doesn't exist!";
    return;
  }
  $FILENAME = $filename;
  print $message_fh "F\t$filename\n";
  my $fh =  ($filename eq '-')? \*STDIN : &openfile($filename, &filetype($filename));
  $PATH_POS = 0; # reset $PATH_POS
  while (<$fh>) { chomp($MESSAGE = $_); &getlink(&getpath()); }
  close $fh;
}

sub openfile($$) {         # just open, remember to close later 
  my ($filename, $filetype) = @_;
  my $openstr = $filetype eq "BIN" ? "$filename | $BGPDUMP" : $filename;
  my $fh;
  if ($filename =~ /\.g?z$/) {         # .gz or .z
    $openstr = "gzip -dc $openstr";
  } elsif ($filename =~ /\.bz2?$/) {   # .bz2 or .bz
    $openstr = "bzip2 -dc $openstr";
  } else {                         # expect it is uncompressed 
    $openstr = "cat $openstr";
  } 
  open($fh, '-|', $openstr) or die "Can not open file $openstr: $!";
  return $fh;
}

sub filetype($) {     # guess the file type according to the % of printable ...
  my $file = shift;   # or whitespace chars. If > 90%, it is TXT, otherwise BIN.
  my $fh = &openfile($file, "TXT");   # just open file without bgpdump
  my $string="";
  my $num_read = read($fh, $string, 1000);
  close $fh;
  return "TXT" unless ($num_read);       # if nothing, guess "TXT" 
  my $num_print = $string =~ s/[[:print:]]|\s//g;
  return ($num_print/$num_read > 0.9 ? "TXT" : "BIN");
}

sub getpath() {                 # read a line, return a path (or get ASPATH)
  return unless ($MESSAGE);
  $PATH = "";
  if ($PATH_POS) {  # it's the output of 'show ip bgp', and we have got the positions
    return if (length($MESSAGE) < $PATH_POS+2);# too short 
# If there is any ':' in first 5 chars of Network field, it is IPv6
    $IPV6 = rindex(substr($MESSAGE, $NET_POS, 5), ':') == -1 ? 0 : 1; 
    ($IP_PREFIX) = substr($MESSAGE, $NET_POS) =~ /(\S+)/;
    return if ($IP_PREFIX =~ /[^\d\.:\/]/);
    ($NEXTHOP) = substr($MESSAGE, $NEXTHOP_POS) =~ /(\S+)/;
    return if ($MONITOR =~ /[^\d\.:]/);
    $MONITOR_AS = 0;
    $MONITOR = 0;
    $PATH = substr $MESSAGE, $PATH_POS, -2; # path w/o ORIGIN code at the end

  } elsif ($MESSAGE =~ /\|/) { # the output of 'bgpdump -mv'
    my @f = split /\|/, $MESSAGE;
    return unless ($#f >= 8 and $f[2] =~ /^[AB]$/);  # next if not RIB or Announcement
    return if ($f[3] =~ /[^\d\.:]/);
    $MONITOR = $f[3];
    $MONITOR_AS = $f[4];
    return if ($f[5] =~ /[^\d\.:\/]/);
    $IP_PREFIX = $f[5];
# If there is any ':' in Network field, it is IPv6
    $IPV6 = index($IP_PREFIX, ':') == -1 ? 0 : 1; 
    $PATH = $f[6];
    $NEXTHOP = $f[8];
    return;
  } elsif ($MESSAGE =~ /Network.*Path/) {     # the header of 'show ip bgp'
    $NET_POS = index($MESSAGE, "Network");    # remember the position of 'Network'
    $PATH_POS = index($MESSAGE, "Path");      # remember the position of 'Path'
    $NEXTHOP_POS = index($MESSAGE, "Next");   # remember the position of 'Next Hop'
    return;

  } elsif ($MESSAGE =~ /Destination.*Path/) { # another kind of header of 'show ip bgp'
    $NET_POS = index($MESSAGE, "Destination");# remember the position of 'Destination'
    $PATH_POS = index($MESSAGE, "Path");      # remember the position of 'Path'
    $NEXTHOP_POS = index($MESSAGE, "Next");   # remember the position of 'Next Hop'
    return;
  }
}

sub getlink($) {                 # read a path, return an array of links
  return unless ($PATH);
  return if ($PATH =~ /[^\d\s\.,\{\}]/);      # check possible chars  
  my $has_new = 0;                            # whether there is something new
  my @links;
  my @ases = split /\s+/, $PATH;
  my $last_as = shift @ases;
  my $first_as = $last_as;
  my %detect_loop = ($last_as => 1);          # for loop detecting
  foreach my $as (@ases) {
    next if ($last_as eq $as);                # skip prepending ASes 
    return if (exists $detect_loop{$as});   # loop! Discard it!
    $detect_loop{$as}=1;                    # otherwise remember it
# add a link with convention: AS1 < AS2; if OPT6 == 1 and IPV6 == 1, append "\t6".
    my $link = ($as le $last_as ?  "$as\t$last_as\t" : "$last_as\t$as\t") . ($IPV6? "6" : "4");
    push @links, $link;
    $last_as = $as;
  }

# the first AS or AS-SET is considered the AS where the monitor is sited.
  my $monitor = "$NEXTHOP\t$first_as\t$MONITOR\t$MONITOR_AS\t" . ($IPV6? "6" : "4");
  unless (exists $MONITORS{$monitor}) {
    $MONITORS{$monitor}={"M" => $MESSAGE_ID, "N" => 0, "I" => $MONITOR_ID};
    $has_new = 1;
    $MONITOR_ID++;
  }
  my $monitor_id = $MONITORS{$monitor}{"I"};
  foreach my $link (@links) {
    unless (exists $LINKS{$link}) {
      $LINKS{$link}= {"M" => $MESSAGE_ID};
      $has_new = 1;
    }
    $LINKS{$link}{$monitor_id} = 1;
  }

# the last AS or AS-SET is considered the origin AS.
  my $pfx = "$IP_PREFIX\t$last_as\t" . ($IPV6? "6" : "4");
  unless (exists $ORIGINS{$pfx}) {
    $ORIGINS{$pfx}={"M" => $MESSAGE_ID};
    $has_new = 1;
  }
  $MONITORS{$monitor}{"N"}++ unless (exists $ORIGINS{$pfx}{$monitor_id});
  $ORIGINS{$pfx}{$monitor_id}=1;
  if ($has_new) {
    print $message_fh "$MESSAGE_ID\t$MESSAGE\n";
    $MESSAGE_ID++;
  }
  return;
}

sub output_link($) {
  my $link = shift;
  my @asn = split "\t", $link;
  $asn[0] =~ s/(\d+)\.(\d+)/($1 << 16) + $2/ge; # convert asdot to asplain 
  $asn[1] =~ s/(\d+)\.(\d+)/($1 << 16) + $2/ge; # convert asdot to asplain 
  return join("\t", @asn) . "\t" . (scalar(keys %{$LINKS{$link}}) - 1) . "\t$LINKS{$link}{'M'}";
}

sub output_origin($) {
  my $origin = shift;
  my @f = split "\t";
  return undef unless ($f[0] =~ /^[\d\.:]+\/\d+$/);
  $f[1] =~ s/(\d+)\.(\d+)/($1 << 16) + $2/ge; # convert asdot to asplain 
  return join("\t", @f) . "\t" . (scalar(keys %{$ORIGINS{$origin}}) - 1) . "\t$ORIGINS{$origin}{'M'}";
}

sub output_monitor($) {
  my $monitor = shift;
  my @f = split "\t", $monitor;
  return undef unless ($f[0] =~ /^[\d\.:]+$/);
  $f[1] =~ s/(\d+)\.(\d+)/($1 << 16) + $2/ge; # convert asdot to asplain 
  $f[3] =~ s/(\d+)\.(\d+)/($1 << 16) + $2/ge; # convert asdot to asplain 
  return join("\t", @f) . "\t$MONITORS{$monitor}{'N'}\t$MONITORS{$monitor}{'M'}";
}

# END MARK
