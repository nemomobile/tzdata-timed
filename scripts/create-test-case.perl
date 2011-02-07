#!/usr/bin/perl -w

use strict ;

while(<>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  my @words = split ;
  my $main = $words[0] ;
  my $q = '"' ;
  print "{ $q$main$q,  $q$_$q },\n" foreach @words ;
}

