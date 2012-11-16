#!/usr/bin/perl

  use Time::Local ;

  $| = 1; # Flush output
  $verbose = 0 ;

  $file_newest_dumps = "/a/wikistats/csv/csv_wp/StatisticsNewestDumps.csv" ;
# $file_newest_dumps = "/a/wikistats/csv/csv_wx/StatisticsNewestDumps.csv" ;
  open CSV_IN, '<', $file_newest_dumps ;
  binmode CSV_IN ;
  @dumplist = <CSV_IN> ;
  close CSV_IN ;

  open CSV_IN, '<', "/a/wikistats/csv/csv_wp/BotsAll.csv" ;
# open CSV_IN, '<', "/a/wikistats/csv/csv_wx/BotsAll.csv" ;
  binmode CSV_IN ;
  @botsall = <CSV_IN> ;
  close CSV_IN ;

#  foreach $line (@dumplist)
#  {
#    chomp $line ;
#    ($type,$project,$wiki,$path) = split (',', $line) ;

#    next if $type ne 'stub' ;

#    if (-e $path)
#    { &ProcessDump ($project, $wiki, $path) ; }
#  }
  &ProcessDump ("wp", "enwiki", "/mnt/data/xmldatadumps/public/enwiki/20110620/enwiki-20110620-stub-meta-history.xml.gz") ;

  print "\nReady\n" ;
  exit ;

sub ProcessDump
{
  my ($project,$wiki,$path) = @_ ;

  ($wp = $wiki) =~ s/wiki//g ;

  my ($ss,$mm,$hh) = (localtime (time))[0,1,2] ;
  my $time = sprintf ("%02d:%02d:%02d", $hh, $mm, $ss) ;
  my $titles = 0 ;

  print "$time Process project $project, wiki $wiki: " ;
  $timestart = time ;

  my $bots = '' ;
  my @bots ;
  my %bots ;

  foreach $line (@botsall)
  {
    if ($line =~ /$wp,/)
    { $bots = $line ; last ; }
  }

  if ($bots eq '')
  { print "No line found for $wiki in BotsAll.csv\n" ; }
  else
  {
    chomp $bots ;
    ($lang,$bots) = split (",", $bots,2) ;
    @bots = split ('\|', $bots) ;
    foreach $bot (@bots)
    {
      $bot =~ s/\&comma;/,/g ;
      $bots {$bot} ++ ;
    }
  }

  if ($path =~ /\.gz$/)
  {
    open XML, "-|", "gzip -dc \"$path\"" || die ("Input file could not be opened: $path") ;
    binmode XML ;
  }
  else
  {  print "Unexpected extension: $path\n" ; exit ; }

  open CSV_OUT, '>', "/a/wikistats/csv/csv_wp/EditsTimestampsOldest" . uc ($wp) . ".csv" ;
# open CSV_OUT, '>', "/a/wikistats/csv/csv_wp/EditsTimestamps" . uc ($wp) . ".csv" ;
# open CSV_OUT, '>', "/a/wikistats/csv/csv_wx/EditsTimestamps" . uc ($wp) . ".csv" ;
  binmode CSV_OUT ;
  print CSV_OUT "# n=namespace, t=title, e=edit, R=registered user, B=bot. A=anonymous\n" ;

  while ($line = <XML>)
  {
    if ($line =~ /\s*\<timestamp\>/) # Q&D: no check on right xml level (below <page>)
    {
      chomp $line ;
      $line =~ s/^\s*// ;
      $line =~ s/\s*$// ;
      ($timestamp = $line) =~ s/<[^>]+>//g ;
      # print "e $timestamp\n" ;
      # print CSV_OUT "e,$timestamp\n" ;
    }

    if ($line =~ /\s*\<username\>/) # Q&D: no check on right xml level (below <revision>)
    {
      chomp $line ;
      $line =~ s/^\s*// ;
      $line =~ s/\s*$// ;
      ($user = $line) =~ s/<[^>]+>//g ;
      $user =~ s/,/&comma;/g ;
      if ($bots {$user} > 0)
      { $usertype = 'R' ; }
      else
      { $usertype = 'B' ; }
      print "e $usertype $timestamp $user\n" if $verbose ;
      print CSV_OUT "e,$usertype,$timestamp,$user\n" ;
    }

    if ($line =~ /\s*\<ip\>/) # Q&D: no check on right xml level (below <revision>)
    {
      chomp $line ;
      $line =~ s/^\s*// ;
      $line =~ s/\s*$// ;
      ($user = $line) =~ s/<[^>]+>//g ;
      $user =~ s/,/&comma;/g ;
      print "e A $timestamp $user\n" if $verbose ;
      print CSV_OUT "e,A,$timestamp,$user\n" ;
    }

    if ($line =~ /\s*\<title\>/) # Q&D: no check on right xml level (below <page>)
    {
      $titles++ ;
      if ($titles % 10000 == 0)
      { print "." ; }
      if ($titles % 100000 == 0)
      { print "\n$titles " ; }
      chomp $line ;
      $line =~ s/^\s*// ;
      $line =~ s/\s*$// ;
      ($title = $line) =~ s/<[^>]+>//g ;
      print "t $title\n" if $verbose ;
      $title =~ s/,/\&comma\;/g ;
      print CSV_OUT "t,$title\n" ;
    }

    if ($line =~ /\s*\<namespace key/) # Q&D: no check on right xml level (below <namespaces>)
    {
      chomp $line ;
      $line =~ s/^\s*// ;
      $line =~ s/\s*$// ;
      ($key = $line) =~ s/^.*?key\="(\-?\d+)".*$/$1/g ;
      ($namespace = $line) =~ s/<[^>]+>//g ;

      print "n $key $namespace\n" if $verbose ;
      $namespace =~ s/,/\&comma\;/g ;
      print CSV_OUT "n,$key,$namespace\n" ;
    }

  }
  close CSV_OUT ;

  print ("$titles titles, " . &ddhhmmss (time - $timestart). "\n") ;

}

sub ddhhmmss
{
  my $seconds = shift ;
  my $format  = shift ;

  $days = int ($seconds / (24*3600)) ;
  $seconds -= $days * 24*3600 ;
  $hrs = int ($seconds / 3600) ;
  $seconds -= $hrs * 3600 ;
  $min = int ($seconds / 60) ;
  $sec = $seconds % 60 ;

  if ($format eq '')
  {
    $days = ($days > 0) ? (($days > 1) ? "$days days, " : "$days day, ") : "" ;
    $hrs  = (($days + $hrs > 0) ? (($hrs > 1) ? "$hrs hrs" : "$hrs hrs") : "") . ($days + $hrs > 0 ? ", " : ""); # 2 hrs/1 hr ?
    $min  = ($days + $hrs + $min > 0) ? "$min min, " : "" ;
    $sec  = "$sec sec" ;
    return ("$days$hrs$min$sec") ;
  }
  else
  {
    return sprintf ($format,$days,$hrs,$min,$sec) if $format =~ /%.*%.*%.*%/ ;
    return sprintf ($format,      $hrs,$min,$sec) if $format =~ /%.*%.*%/ ;
    return sprintf ($format,           $min,$sec) if $format =~ /%.*%/ ;
    return sprintf ($format,                $sec) ;
  }
}


