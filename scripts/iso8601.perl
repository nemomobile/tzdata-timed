#!/usr/bin/perl -w

# Most comments in this file are copied from
# http://en.wikipedia.org/wiki/ISO_8601

use strict ;

main() ;

sub main
{
  my $N = 15 ;
  foreach my $h (0..$N)
  {
    for my $m (0,15,30,45)
    {
      next if $h==$N and $m > 0 ;
      zone("+", $h, $m) ;
      zone("-", $h, $m) if $h or $m ;
    }
  }
}

sub zone
{
  my ($sign, $hour, $min) = (shift,shift,shift) ;

  my $full  = sprintf("%s%02d%02d", $sign, $hour, $min) ;
  my $human = sprintf("%s%02d:%02d", $sign, $hour, $min) ;
  my $short = sprintf("%s%02d", $sign, $hour) ;

  # The offset from UTC is given in the format....

  # ... ±[hh][mm] ...
  print "Zone Iso8601/$full $human - UTC$human\n" ;

  # ... or ±[hh]:[mm] ...
  print "Link Iso8601/$full  Iso8601/$human\n" ;

  # ... or ±[hh]
  print "Link Iso8601/$full  Iso8601/$short\n" if $min==0 ;

  # If the time is in UTC, add a 'Z' directly after the time without a space.
  # 'Z' is the zone designator for the zero UTC offset
  print "Link Iso8601/$full  Iso8601/Z\n" if $hour==0 and $min==0 and $sign eq "+" ;

  # The offset can also be used in the case where the UTC time is known, but the
  # local offset is not. In this case the offset is "-00:00", which is
  # semantically different from "Z" or "+00:00", as these imply that UTC is the
  # preferred reference point for those times.
  print "Link Iso8601/$full  Iso8601/-0000\n" if $hour==0 and $min==0 and $sign eq "+" ;

  # Just add an empty line
  print "\n" ;
}




