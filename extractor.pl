#!/usr/bin/perl

use strict;
use warnings;

sub openfile($$);   # open [un]compressed file (and pipe to bgpdump if set 1)
sub filetype($);    # guess type: TXT (show ip bgp) or BIN (means MRT)
sub getpath($);     # get AS path (or its position)
sub getlink($);     # get AS links from AS path

my $POSITION=0;     # the start position of 'Path' in 'show ip bgp'
my %LINKS=();       # hashtable of links          
# MAIN ========================================================================
($ARGV[0]) or die "usage: inputfile";
$|=1;               # flush output
my $filename = shift;
(-f $filename) or die "can not find $filename";
my $fh = (&filetype($filename) eq "TXT") ? 
         &openfile($filename, 0) : &openfile($filename, 1);
while(<$fh>) {
  chomp;
  my $path = &getpath($_);
  next unless ($path);
  my @links = &getlink($path);
  next unless (@links);
  foreach (@links) {
    $LINKS{$_} = 1;
  }
}
close $fh;
foreach (keys %LINKS) {
  print "$_\n";
}
exit 0;
# =============================================================================

sub openfile($$) {
  my $file = shift;
  my $isbgpdump = shift;
  my $openstr = $isbgpdump ? "$file | bgpdump -mv -" : $file;
  my $fh;
  if ($file =~ /\.gz$/) {
    open($fh, '-|', "gzip -dc $openstr") or die "Can not open file $openstr: $!";
  } elsif ($file =~ /\.bz2?$/) {
    open($fh, '-|', "bzip2 -dc $openstr") or die "Can not open file $openstr: $!";
  } else {
    open($fh, '-|', "cat $openstr") or die "Can not open file $openstr: $!";
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

sub getpath($) {
  my $l = shift;
  if ($POSITION) {                       # have got the position
    my $s = substr $l, $POSITION;        # path is from position to $
    $s =~ s/[^\d\}]*$//;                 # remove non-[ digit and } ] at the end
    return $s;
  } elsif ($l =~ /^(.*?\|){6}(.*?)\|/) { # the output of 'bgpdump -mv'
    return $2;
  } elsif ($l =~ /Network.*Path/) {      # the header of 'show ip bgp'
    $POSITION = index($l, "Path");       # remember the position of 'Path'
  }
  return;
}

sub getlink($) {
  my $line = shift;
  $line =~ s/\{.*?\}/0/g;                   # replace all AS-SETs with token '0'  
  return unless ($line =~ /^[\d\s\.]+$/);   # weird! discard it! 
  my @ases = split /\s+/, $line;
  my $last_as = 0;                          # token '0'
  my %detect_loop = ();                     # for loop detecting  
  my @link = ();                            # store links
  foreach my $as (@ases) {
    if ($as =~ /^(\d+)\.(\d+)$/) {          # convert asdot to asplain
      $as = ($1 << 16) + $2;
    } elsif ($as !~ /^(\d+)$/) {            # if not an ASN, 
      return;                               # then discard it! 
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

