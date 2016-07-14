#!/usr/bin/perl

# Download BGP raw data from collectors in $CollectorFile 
#
# yuzhang at hit.edu.cn 

use warnings;
use strict;

use File::Path qw(make_path); # make the whole path
use Time::Local qw(timegm); # invert of gmtime

select((select(STDOUT), $| = 1)[0]);
select((select(STDERR), $| = 1)[0]);

my $HELP = '
Usage: ./puller.pl [options]

  -b seconds    break time after a round    [120]
  -c file       collector list file         [collectors.txt]
  -e time       end time, e.g. 20141231     [20700101]
  -f regex      regular expression to filter collectors [/./]
  -h            print this help message
  -k            skip one day after retrying for 3 days  
  -l path       local directory             [~/BGP] 
  -L            list the latest file
  -p pattern    the pattern of local directory [<COLLECOTOR>/<YYYY>.<MM>/<DD>]
  -q seconds    the interval of downloading RIB file [86400] 
  -r            dryrun without real downloading
  -s time       start time, e.g. 20141201   [Latest]
  -t path       temp directory              [$localpath/tmp/$PID-$TIME]
  -v            verbose output
';


sub date2ts {return unless shift =~ /(\d{4})(\d\d)(\d\d)/;
             return timegm(0, 0, 0, $3, $2-1, $1-1900);}
sub ts2date {return &setTime("<YYYY><MM><DD>-<HH>:<mm>", shift);}

use Getopt::Std;
my %options;
Getopt::Std::getopts("b:c:e:f:hkl:Lp:q:rs:t:v", \%options);
defined $options{h} && die $HELP;

my $Break = $options{b} || 120;   # break time after a round
my $DryRun = $options{r} || 0;    # Test flag. Unset it if really want to download
my $CollectorFile = $options{c} || "collectors.txt";   # collecotr list file
my $CollectorFilter = $options{f} || ".";             # RegEx to select collectors
my $LocalDir = $options{l} || "BGP"; # to store data
my $LocalPattern = $options{p} || "<COLLECTOR>/<YYYY>.<MM>/<DD>"; # to store data
my $TmpDir = $options{t} || ("$LocalDir/tmp/$$-" . time); # CAUTION!
(-d $TmpDir) or make_path($TmpDir) or die "can not make path $TmpDir: $?"; 
my $StartTS = &date2ts($options{s} || "") || "Latest"; # when to start
my $EndTS = exists $options{e} ? (&date2ts($options{e})+86399) : 86400*365*100; # when to end 2070
my $Interval = $options{q} || 86400;
my $Verbose = $options{v} || 0;
my $Skip = $options{k} || 0;
my $LsLatest = $options{L} || 0;

if ($Verbose) {
  print "Puller will run under the following settings:
  Dryrun           = $DryRun
  Collector File   = $CollectorFile
  Collector Filter = $CollectorFilter
  Local Dir        = $LocalDir
  Local Pattern    = $LocalPattern
  Tmp Dir          = $TmpDir
  Start Time       = $StartTS 
  End Time         = $EndTS 
  Interval of RIBs = $Interval
  Verbose          = $Verbose
  Skip             = $Skip
";
}

my $CollectorPATH; # collector local path
my $CollectorURL; # collector remote url
my %LastCheckTS; # last successful check timestamp

while (1) { # infinite loop 
  open(my $fh, "<", $CollectorFile) or die "Can not open file $CollectorFile: $!";
  my %Collectors = (map {chomp; split /\s+/, $_;} grep {/$CollectorFilter/ and /^[^#]/} <$fh>);
  close($fh);

  foreach my $collector (sort keys %Collectors) {
    $CollectorPATH = $collector;
    $CollectorURL = $Collectors{$collector};

    print "Pulling from $CollectorPATH\n$CollectorURL\n" if ($Verbose);
    
    if ($LsLatest) { # list the latest file
      my $file = &latestFile("$LocalDir/$LocalPattern" 
                             =~ s/^(.*)<COLLECTOR>.*$/$1$CollectorPATH/r);
      my $ts = &ts2date(&getTime($file));
      print "$ts\t$collector\t$file\n";
      delete $Collectors{$collector};
      next;
    }

    $LastCheckTS{$collector} ||= 0;
    # get the next time point when to start downloading
    my $nextts = &nextTS(&getLatestTS()); 
    if ($nextts > $EndTS) { # reach the end date
      print "$collector is finished!\n" if ($Verbose);
      delete $Collectors{$collector};
      next;
    }
    next if (time < $nextts); # it's in future
    next if (time < $LastCheckTS{$collector} + $Break); # in an interval of 20 min 

    # download. If fail, try again; otherwise update LastCheckTS to now
    my $ret = &download($nextts);
    next if ($ret =~ /^Fail/ and $ret ne "Fail on 404"); # failure except 404
    $LastCheckTS{$collector} = time;
  }
  exit 0 unless (%Collectors); # all collectors are deleted
  sleep(15); # take a break
}

sub getLatestTS {
  if ($StartTS eq "Latest") { # get latest filename and extract timestamp 
    my $lts =  &getTime( &latestFile("$LocalDir/$LocalPattern" 
                         =~ s/^(.*)<COLLECTOR>.*$/$1$CollectorPATH/r));
    return $lts || (time - time % 86400); # return today for empty dir
  }
  # download since the start date
  # find the day without any file and return the last minite of yesterday
  for (my $ts = $StartTS;  1; $ts += 86400) { # day by day
    my $path = &setTime("$LocalDir/$LocalPattern" =~ s/<COLLECTOR>/$CollectorPATH/r , $ts);  
    my @file = <$path/*>;
    next if ((-d $path) and @file);
    return $ts-60; 
  }
}

sub nextTS { # step into the time of next file
  my $ts = shift;
  return $StartTS if ($StartTS ne "Latest" and $ts < $StartTS);
  return $ts - $ts % $Interval + $Interval if ($DryRun);

  if ($CollectorPATH =~ /\/ribs$/) { # one rib per day
    return $ts - $ts % $Interval + $Interval;
  } else { # all updates
    return $ts + 60; 
  } 
}

sub download {
  my $ts = shift;
  print "Downloading time " . &ts2date($ts)  . "\n" if ($Verbose); 
  my @links = &getLinks($ts);
  return $links[0] if ($links[0] =~ /^Fail/);
  @links = grep {&getTime($_) >= $ts} @links;

  # if there is no new file, and if now is next day, 
  # and if next day is in another page, check next day
  if ($#links+1==0 
      and time() > ($ts - $ts%86400 + 86400)
      and &nextDayInNextPage($ts)) {
    @links = &getLinks($ts - $ts%86400 + 86400);
    return $links[0] if ($links[0] =~ /^Fail/);
  }
  
  # download files
  foreach my $link (@links) {
    next if (&getTime($link) < $ts or &getTime($link) > $EndTS);
    # once fail to download a file, try again later
    return "Fail on getFile" if (&getFile($link) ne "Success");
    # successfully downloaded a file, update latest TS
    $ts = &nextTS(&getTime($link)); 
  }
  return "Success";
}

sub nextDayInNextPage {
  my $ts = shift;
  my @ntime = gmtime($ts + 86400);
  return 1 if ($CollectorURL =~ /<DD>.*\//); # next day in another page
  return 1 if ($CollectorURL =~ /<MM>.*\//
               and $ntime[3] == 1);          # next day is 1st day in next month
  return 1 if ($CollectorURL =~ /<YYYY>.*\//
               and $ntime[3] == 1
               and $ntime[4] == 0);          # next day is Jan. 1 in next year
  return 0;
}

sub setTime { # fill time in a given pattern and return a string
  my ($string, $time) = @_;

  my ($min,$hour,$mday,$mon,$year) = 
    map {sprintf "%02s", $_ } (gmtime($time))[1 .. 5];
  $year += 1900;
  $mon = sprintf "%02s", $mon+1;

  my %replace = (
    "<YYYY>" => $year, "<MM>" => $mon, "<DD>" => $mday,
    "<HH>" => $hour, "<mm>" => $min );
  foreach (keys %replace) {
    $string =~ s/($_)/$replace{$_}/g;
  }

  return $string; 
}

sub getTime { # extract timestamp from filename 
  my ($file) = @_;
  return 0 unless (defined $file);

  my ($pattern) = $CollectorURL =~ /^.*\/(.*)$/; # get file part 
  $pattern =~ s/(<.+?>)/ "(" . "\\d" x (length($1)-2) . ")" /eg; # sub <??> to (\d\d)

  my ($year, $mon, $mday, $hour, $min) = $file =~ /^.*\/$pattern/;
  $hour ||= 0;
  $min ||= 0;

  return timegm(0, $min, $hour, $mday, $mon-1, $year-1900);
}

sub getLinks { # get links at given time 
  my $time = shift;
  my $urlPattern = $CollectorURL =~ s/(<.+?>)+/\\d+/gr;
  
  my ($base, $file) = $CollectorURL =~ /^(.*)\/(.*)$/; 

  $base = &setTime($base, $time);  
  #$baseString = $base =~ s/[^a-zA-Z0-9]+/-/gr;
  my $ret = &wget("$base/", "$TmpDir/index.html");
  return ($ret) if ($ret =~ /^Fail/);

  open(my $fh, "<", "$TmpDir/index.html") or
    (warn "can not open file $base index.html: $!" and return ("Fail on open index"));
  my @links = sort {$a cmp $b}
              grep {/$urlPattern/}
              map {$_ = "$base/$_" unless (/^$base/i)} 
              map {m/href ?= ?"(.*?)"/gi} <$fh>;
  close($fh);
  unlink "$TmpDir/index.html";
  if ($#links+1 == 0) {
    warn "no link in $base";
    return ("Fail on empty index");
  }
  return @links;
}

sub wget { # a wrapper of Wget
  my ($url, $file) = @_; 
  my ($path, $name) = $file =~ /(.*)\/(.*)/;  
  
  my $Wget = "wget -o $TmpDir/wget.log --no-check-certificate -4 -nd -O $TmpDir/$name $url";
  if ($file !~ /index/ and $DryRun) { # test, use --spider to check whether the link exists
    $Wget = "wget --spider -o $TmpDir/wget.log --no-check-certificate -4 -nd -O $TmpDir/$name $url";
  }
  print "$Wget\n" if ($Verbose);
  my $ret = system($Wget);
  open(my $fh, "<", "$TmpDir/wget.log") or return "Fail on open $TmpDir/wget.log";    
  my $log = join " ", <$fh>;
  close $fh;
 
  # successfully download
  if ($ret == 0 and ($log =~ /saved/ or $log =~ /file exists/)) { 
    if ($file !~ /index/ and $DryRun) { # test, create a fake data file
      system("touch $TmpDir/$name");
    }
    return "Success" if ($file =~ /index.html$/); # don't need to move 
    (-d $path) or make_path($path) or die "can not make path $path: $?"; 
    if (system("mv -f $TmpDir/$name $file") == 0) {
      return "Success";
    } else {
      warn "Can not move $TmpDir/$name $file: $?";
      return "Fail on move";
    }
  }
  
  unlink "$TmpDir/$name" if (-f "$TmpDir/$name"); # remove the incomplete file

  # Figure out the reason for failure
  return "Fail on 404" if ($log =~ /ERROR 404/);
  warn "Fail to get $url: $?\n" . "Log: $log\n";
  return "Fail on something";
}

sub getFile { # download a file at given URL
  my $url = shift;

  my $path = &setTime("$LocalDir/$LocalPattern" =~ s/<COLLECTOR>/$CollectorPATH/r,
                      &getTime($url));  
  my ($base, $file) = $url =~ /^(.*)\/(.*)$/; 
  return "Success" if (-e -f "$path/$file");

  return &wget($url, "$path/$file");
}

sub latestFile { # find the latest file in a given path
  my $path = shift;
  (-d $path) or return undef;
  my @list = sort {$b cmp $a} grep { $_ !~ /^\.\.?$/ } glob("$path/*");
  foreach my $i ( @list ) {
    if (-f $i) { return $i; } 
    if (-d $i) {
      my $j = &latestFile($i);
      return $j if (defined $j and -f $j);
    }
  }
  return undef;
}

