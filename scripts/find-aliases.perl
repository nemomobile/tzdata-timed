#!/usr/bin/perl -w -s

use strict ;

our ($zones, $signatures, $md5sum) ;
print STDERR join ",", $zones, $signatures, $md5sum, "\n" ;

my $known = {} ;
my $signs = {} ;
my $md5 = {} ;
my $md5toz = {} ;

open ZONES, "<", "$zones" or die "can't read zones file '$zones'" ;
while (<ZONES>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  $known->{$_} = [] ;
}

open SIGNATURES, "<", "$signatures" or die "can't read signatures file '$signatures'" ;
while (<SIGNATURES>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  die "inlavid signature" unless /^(\S+):\s*(\S+)$/ ;
  $signs->{$1} = $2 ;
}

open MD5, "<", "$md5sum" or die "can't read md5 sums file '$md5sum'" ;
while (<MD5>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  die "inlavid signature" unless /^([0-9a-f]{32})\s+(\S+)$/ ;
  $md5->{$2} = $1 ;
  $md5toz->{$1} = [] unless exists $md5toz->{$1} ;
  push @{$md5toz->{$1}}, $2 ;
}

foreach my $z (keys %$md5)
{
  next if exists $known->{$z} ; # it's a zone by itself
  my $m = $md5->{$z} ;
  my $zz = $md5toz->{$m} ;
  my $res ;
  foreach my $r (@$zz)
  {
    $res = $r if $md5->{$r} eq $md5->{$z} and exists $known->{$r} ;
  }
  next unless $res ;
# print "$z $res\n" ;
  push @{$known->{$res}}, $z ;
}

for my $z (sort keys %$known)
{
  my $str = $z ;
  my $list = $known->{$z} ;
  $str .= " " . join " ", @$list if @$list ;
  print "$str\n" ;
}

