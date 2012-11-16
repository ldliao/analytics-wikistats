#!/usr/bin/perl

  use lib "/home/ezachte/lib" ;
  use EzLib ;
  $trace_on_exit = $true ;

  use CGI::Carp qw(fatalsToBrowser);
  use Time::Local ;
  use Net::Domain qw (hostname);

  $categoryroot = "Museum in Nderland" ; # read from input
  $wikipedia = "nl.wikipedia.org" ;       # read from input
  $month_out = "March 2010" ;
  $month = "201003" ;
  $language  = "nl" ;
  $daysinmonth = 31 ;
  $unicodetoascii = $true ;

  $file_csv_pagecounts = "pagecounts-$month-$language\_fdt" ;

  $dir_in  = "." ;
  $dir_out = "." ;
  if ($hostname eq "bayes")
  {
    $dir_in  = "/a/dammit.lt/pagecounts/" . substr ($month,0,4) . "-" . substr ($month,4,2) ;
    $dir_out = "/home/ezachte/wikistats/viewspercat" ;
  }
  else
  {
    $dir_in  = "W:/! Perl/Page Views Per Article Per Category" ;
    $dir_out = "W:/! Perl/Page Views Per Article Per Category" ;
    $file_csv_pagecounts .= ".txt" ;
  }

  $timestart = time ;
  $file_log  = "WikiCountsPageViewsByArticleTitle.log" ;

# &FilterCounts ;
  &CountArticles ;
  close FILE_LOG ;
  exit ;

sub FilterCounts
{
  print "FilterCounts\n" ;
  open OUT, '>', "$dir_out/$file_csv_pagecounts" ;
  print "Filter view counts for $language to $dir_out/$file_csv_pagecounts\n\n" ;
  for ($day = 1 ; $day <= 31 ; $day++)
  {
    $file_pagecounts = "$dir_in/pagecounts-$month" . sprintf ("%02d", $day) . "_fdt" ;
    if ($hostname eq "bayes")
    { $file_pagecounts .= ".7z" ; }

    if (! -e $file_pagecounts)
    { print "Not found: $file_pagecounts\n" ; next ; }

    print "Read $file_pagecounts\n" ;

    if ($hostname eq "bayes")
    { open IN, "-|", "./7za e -so \"$file_pagecounts\"" || die ("Input file '" . $file_pagecounts . "' could not be opened.") ; }
    else
    { open IN,  '<', $file_pagecounts ; }
    while ($line = <IN>)
    {
      if ($line !~ /^$language\.z /) { next ; }
      ($project, $title, $counts) = split (' ', $line) ;
      $counts =~ s/^(\d+).*$/$1/ ;
      print OUT "$counts $title\n" ;
    }
    close IN ;
  }
  close OUT ;
}

sub CountArticles
{
  print "CountArticles\n" ;
  if (! -e "$dir_in/$file_csv_pagecounts")
  { print "File not found: $dir_in/$file_csv_pagecounts\n" ; exit ; }

  open IN,  '<', "$dir_in/$file_csv_pagecounts" ;
  while ($line = <IN>)
  {
    chomp ($line) ;

    ($count,$title) = split (' ', $line,2) ;
# if ($title !~ /Depardieu/) { next ; }
    $title =~ s/%([0-9A-F]{2})/chr(hex($1))/ge ;
    if ($unicodetoascii)
    { $title =~ s/([\x80-\xFF]{2,})/&UnicodeToAscii($1)/ge ; }
    $title =~ s/(\&\#\d+\;)/&HtmlToAscii($1)/ge ;
    $title =~ s/\&quot;/'/g ;
    $title =~ s/\&amp;/&/g ;
    $title = lc ($title) ;
# print "X $count $title\n" ;
    $titles {$title} += $count ;
  }
  close IN ;

  open OUT, '>', "$dir_out/WikiStatsPageViewsPerArticleSortByTitle.txt" ;
  open IN,  '<', "$dir_out/WikiStatsArticles.csv" ;
  while ($line = <IN>)
  {
    chomp ($line) ;
    ($title,$category) = split (',',$line) ;

#    next if $category !~ /politicus/ ;
#    next if $category =~ /Nederlands/ ;
#    $category =~ s/-politicus// ;

# if ($title !~ /Depardieu/) { next ; }
    $title =~ s/\%2C/,/g ;
    $category =~ s/\%2C/,/g ;
    $title =~ s/\s/_/g ;
    $title =~ s/(\&\#\d+\;)/&HtmlToAscii($1)/ge ;
    $title =~ s/\&quot;/'/g ;
    $title =~ s/\&amp;/&/g ;
    $title_lc = lc ($title) ;
    $count = ($titles {$title_lc}+0) ; # force numeric
# print "Y $count $title_lc\n" ;
    print OUT sprintf ("%5d",$count) . " " . $title . "\n" ;
    if ($title ne $title_prev)
    { $articles   {$title} += $count ; }
    $title_prev = $title ;
    $categories {$category} += $count ;
    $titlecat {$title} = $category ;
  }
  close IN ;
  close OUT ;

  open OUT, '>', "$dir_out/WikiStatsPageViewsPerArticleSortByTitle.txt" ;
  print OUT "Wikipedia '$wikipedia', Category: '$categoryroot', Month: '$month_out'\n" ;
  foreach $article (sort keys %articles)
# { print OUT sprintf ("%5d",$articles {$article}) . " " . $article . "\n" ; }
  { &Print ($articles {$article}, $article) ; }
  close OUT ;

  open OUT, '>', "$dir_out/WikiStatsPageViewsPerArticleSortByViews.txt" ;
  print OUT "Wikipedia '$wikipedia', Category: '$categoryroot', Month: '$month_out'\n" ;
  foreach $article (sort {$articles {$b} <=> $articles {$a}} keys %articles)
# { print OUT sprintf ("%5d",$articles {$article}) . " " . $article . "\n" ; }
  { &Print ($articles {$article}, $article) ; }
  close OUT ;

  open OUT, '>', "$dir_out/WikiStatsPageViewsPerCategorySortByTitle.txt" ;
  print OUT "Wikipedia '$wikipedia', Category: '$categoryroot', Month: '$month_out'\n" ;
  foreach $category (sort keys %categories)
# { print OUT sprintf ("%5d",$categories {$category}) . " " . $category . "\n" ; }
  { &Print ($categories {$category}, $category) ; }
  close OUT ;

  open OUT, '>', "$dir_out/WikiStatsPageViewsPerCategorySortByViews.txt" ;
  print OUT "Wikipedia '$wikipedia', Category: '$categoryroot', Month: '$month_out'\n" ;
  foreach $category (sort {$categories {$b} <=> $categories {$a}} keys %categories)
# { print OUT sprintf ("%5d",$categories {$category}) . " " . $category . "\n" ; }
  { &Print ($categories {$category}, $category) ; }
  close OUT ;

#  open OUT, '>', "$dir_out/WikiStatsPageViewsPerPerArticleSortByViewsPvdA.csv" ;
#  print OUT "politicus,partij,hits,kleur\n" ;
#  foreach $article (sort {$articles {$b} <=> $articles {$a}} keys %articles)
#  {
#    last if $articles {$article} == 0 ;
#    next if $titlecat {$article} !~ /pvda/i ;
#    $color = int(rand(255)) ;
#    print OUT "$article,${titlecat {$article}},${articles {$article}},$color\n" ;
#  }
#  close OUT ;

}

sub Print
{
  my $count = shift ;
  my $text = shift ;
  print OUT sprintf ("%5d",$count) . " p/m = " . sprintf ("%4.0f",$count/$daysinmonth) . " p/d : $text\n" ;
}

# translates one unicode character into plain ascii
sub UnicodeToAscii {
  my $unicode = shift ;

  my $char = substr ($unicode,0,1) ;
  my $ord = ord ($char) ;
  my ($c, $value, $html) ;

  if ($ord < 128)         # plain ascii character
  { return ($unicode) ; } # (will not occur in this script)
  else
  {
    if    ($ord >= 252) { $value = $ord - 252 ; }
    elsif ($ord >= 248) { $value = $ord - 248 ; }
    elsif ($ord >= 240) { $value = $ord - 240 ; }
    elsif ($ord >= 224) { $value = $ord - 224 ; }
    else                { $value = $ord - 192 ; }

    for ($c = 1 ; $c < length ($unicode) ; $c++)
    { $value = $value * 64 + ord (substr ($unicode, $c,1)) - 128 ; }

    if ($value < 256)
    { return (chr ($value)) ; }

    # $unicode =~ s/([\x80-\xFF])/("%".sprintf("%02X",$1))/gie ;
    return ($unicode) ;
  }
}

sub HtmlToAscii {
  my $html = shift ;
  my $html2 = $html ;
  $html2 =~ s/[^\d]//g ;
  if ($html2 <= 255)
  { return (chr ($html2)) ; }
  else
  { return ($html) ; }
}

sub Log
{
  $msg = shift ;
  print $msg ;
  print FILE_LOG $msg ;
}

sub Log2
{
  $msg = shift ;
  print FILE_LOG $msg ;
}

sub Abort
{
  $msg = shift ;
  print "Abort script\nError: $msg\n" ;
  print LOG "Abort script\nError: $msg\n" ;
  exit ;
}



