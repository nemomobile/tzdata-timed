#!/usr/bin/perl -w -s

use strict ;

our ($zones, $signatures, $md5sum, $links, $zonetab) ;

print STDERR join(",", $zones, $signatures, $md5sum, $links, $zonetab), "\n" ;

# INPUT:

# $zones ( -zones=zone.list )
# $signatures ( -signatures=signatures )
# $md5sum ( -md5sum=md5sum )
# $links ( -links=zone.link )
# $zonetab ( -zonetab=zone.tab )

# INPUT EXAMPLES

# -zone=zone.list: Only 'main' zone names
#    Africa/Abidjan
#    Africa/Accra
#    Africa/Addis_Ababa

# -signatures=signatures: all zone names and aliases
#
#    Africa/Ceuta: w1ow1ow1....
#    Africa/Asmara: w3ow3ow3...

# -md5sum=md5sum: all zone names and aliases
#    ccfe2b1f133bde654d4645574fd71774  Africa/Ceuta
#    da4cb62e10f95e59eabfabaccb1c48ee  Africa/Asmara
#    ba893c91d39f3e8208c2d7a6e6ba267f  Africa/Lusaka

# -links=zone.link
#    Link	Antarctica/McMurdo	Antarctica/South_Pole
#    Link	Asia/Nicosia	Europe/Nicosia
#    Link	Europe/London	Europe/Jersey
#    Link	Europe/London	Europe/Guernsey
#    Link	Europe/London	Europe/Isle_of_Man
#    Link	Europe/Helsinki	Europe/Mariehamn
#    Link Europe/Belgrade Europe/Ljubljana	# Slovenia
#    Link Europe/Belgrade Europe/Podgorica	# Montenegro
#    Link Europe/Belgrade Europe/Sarajevo	# Bosnia and Herzegovina
#    Link Europe/Belgrade Europe/Skopje	# Macedonia
#    Link Europe/Belgrade Europe/Zagreb	# Croatia

# -zonetab=zone.tab
#    AD	+4230+00131	Europe/Andorra
#    AE	+2518+05518	Asia/Dubai
#    AF	+3431+06912	Asia/Kabul
#    AG	+1703-06148	America/Antigua
#    AI	+1812-06304	America/Anguilla

# OUTPUT: ( zone.alias )
# List of main names and aliases
# First entry in every line is a main name, other names in the same line are aliases
# If a place is an alias, but it listed in zone.tab, then
#   it has to be listed as a main name

# OUTPUT EXAMPLE
#    Asia/Ho_Chi_Minh Asia/Saigon
#    Asia/Hong_Kong Hongkong
#    Asia/Hovd
#    Asia/Irkutsk
#    Asia/Jerusalem Israel Asia/Tel_Aviv
#    Asia/Kabul
#    Asia/Kolkata Asia/Calcutta
#    Europe/Podgorica
#    Europe/Jersey

# HOW IT WORKS:

# 1. Reading -zones
#    Creating map: $table from zone name to list of aliases
#                  $table->{Asia/Kabul} = [ Asia/Kabul ]
#    This variable is representation of the output structure
#    This mapping is initialized with main zone names only
#    Later some aliases will be added as keys, because
#          some states (like former YU) have alised capitals (Zagreb etc)
my $table = { } ;

open ZONES, "<", "$zones" or die "can't read zones file '$zones'" ;
while (<ZONES>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  $table->{$_} = [$_] ;
}
close ZONES ;

# 2. Reading -md5sum
#    Creating map: $md5 mapping zone or alias name to their file's md5sum
#                  $md5->{Europe/Guernsey} = md5->{Europe/London} = 410c65079e...
my $md5 = { } ;
#    Creating map: $md5_to_table mapping md5sum back to main zone name
#                  $md5_to_table->{ba893c91d...} = Africa/Lusaka
#                  The mappping is well defined, as all main zones are distinct
my $md5_to_table = { } ;

open MD5, "<", "$md5sum" or die "can't read md5 sums file '$md5sum'" ;
while (<MD5>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  die "invalid md5 sum" unless /^([0-9a-f]{32})\s+(\S+)$/ ;
  my ($sum, $file) = ($1,$2) ;
  $md5->{$file} = $sum ;
  if (exists $table->{$file}) # This is a main zone name
  {
    print STDERR "WARNING: Same md5sum: '$file' and '".$md5_to_table->{$sum}."'\n" and next if exists $md5_to_table->{$sum} ;
    $md5_to_table->{$sum} = $file ;
  }
}
close MD5 ;

# 3. Reading -links like Link Europe/London GB
#    Creating map: $alias mapping alias name to main zone map
#                  $alias->{GB} = Europe/London
my $alias = { } ;

open LINK, "<", "$links" or die "can't read links file '$links'" ;
while (<LINK>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  die "invalid link directive: $_" unless /^\s*Link\s+(\S+)\s+(\S+)(\s|$)/ ;
  my ($main_name, $alias_name) = ($1,$2) ;
  if (exists $alias->{$alias_name})
  {
    die "contradictory Link directives for alias '$alias_name'" unless $alias->{$alias_name} eq $main_name ;
    next ;
  }
  $alias->{$alias_name} = $main_name ;
}
close LINK ;

# 4. Applying link directives
#    For every link like GB -> Europe/London:
#       If the link target exists as a key in $table map:
#          Check, they really are the same file (equal md5sum)
#          Add alias to the array of this entry: $table->{Europe/London} = [ ...., GB ]
#          Remove processed alias, save it $processed_alias
#       If not:
#          Just skip for the next step (whatever ...)

my $processed_alias = { } ;

foreach my $a (keys %$alias)
{
  my $zone = $alias->{$a} ;
  if (exists $table->{$zone})
  {
    die "files '$a' and '$zone' differ" unless exists $md5->{$a} and exists $md5->{$zone} and $md5->{$a} eq $md5->{$zone} ;
    push @{$table->{$zone}}, $a ;
    # print STDERR "processed link: $zone -> $a; table{$zone}=[", join(",",@{$table->{$zone}}), "]\n" ;
    $processed_alias->{$a} = $alias->{$a} ;
    delete $alias->{$a} ;
  }
}

# 4a. Using md5 sums to add some aliases
#     All the other files are put to $unsupported hash

my $unsupported = { } ;

foreach my $zone (keys %$md5)
{
  next if exists $processed_alias->{$zone} ;
  next if exists $table->{$zone} ;
  my $sum = $md5->{$zone} ;
  # print STDERR "WARNING: no main zone name for '$zone' found\n" and next unless exists $md5_to_table->{$sum} ;
  $unsupported->{$zone} = 1 and next unless exists $md5_to_table->{$sum} ;
  my $main = $md5_to_table->{$sum} ;
  next if grep { $_ eq $zone} @{$table->{$main}} ;
  push @{$table->{$main}}, $zone ;
  print STDERR "Added '$zone' as a new alias for '$main' based on md5sum\n" ;
}

# 5. Reading zone.tab and extracting aliases listed there
#      making them to main names
#      we expecting every name in zone tab be either a main zone or an alias
#      if it's an alias, it has to be processed in previous step

open ZONETAB, "<", "$zonetab" or die "can't read zone tab file '$zonetab'" ;
while (<ZONETAB>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  die "invalid zonetab entry" unless /^\s*(..)\s+([+-]\S+)\s+(\S+)(\s|$)/ ;
  my $zone = $3 ;
  next if exists $table->{$zone} ;
  die "the alias '$zone' isn't produced by a Link directive" unless exists $processed_alias->{$zone} ;
  my $main = $processed_alias->{$zone} ;
  die "list of aliases for zone '$main' doesn't contain '$zone'" unless grep { $_ eq $zone } @{$table->{$main}} ;
  my $grepped = [ grep { $_ ne $zone } @{$table->{$main}} ] ;
  $table->{$main} = $grepped ;
  $table->{$zone} = [ $zone ] ; # Creating a new zone
  print STDERR "Made '$zone' to a primary zone (not an alias for '$main') because it's listed in '$zonetab'\n" ;
}
close ZONETAB ;

# 6. Loading signatures just for a lame check during manual aliasing below

my $sign = { } ;

open SIGN, "<", "$signatures" or die "can't read zones file '$signatures'" ;
while (<SIGN>)
{
  chomp ;
  next if /^\s*(#|$)/ ;
  die "invalid signature: $_" unless /^\s*(\S+):\s+(\S+)\s*$/ ;
  $sign->{$1} = $2 ;
}
close SIGN ;

# 7. Adding some well know names for GMT etc

sub add_alias_manually
{
  my ($main, $zone) = (shift,shift) ;
  die "no such file: '$zone'" unless exists $md5->{$zone} ;
  die "unknown signature for '$main'" unless exists $sign->{$main} ;
  die "unknown signature for '$zone'" unless exists $sign->{$zone} ;
  die "signatures don't match for '$main' and '$zone'" unless $sign->{$zone} eq $sign->{$main} ;
  die "'$main' is not a main zone name" unless exists $table->{$main} ;
  die "'$zone' is already supported" unless exists $unsupported->{$zone} ;
  delete $unsupported->{$zone} ;
  die "'$zone' is already an alias for '$main'" if grep { $_ eq $zone } @{$table->{$main}} ;
  push @{$table->{$main}}, $zone ;
  print STDERR "added manually an alias '$zone' for the zone '$main'\n" ;
}

my $zulu = "Iso8601/+0000" ;
add_alias_manually($zulu, $_) for qw/UTC GMT UCT Universal Greenwich Zulu GMT+0 GMT-0 GMT0/ ;
add_alias_manually($zulu, "Etc/$_") for qw/UTC GMT UCT Universal Greenwich Zulu GMT+0 GMT-0 GMT0/ ;

foreach my $h (-14 .. 12)
{
  next unless $h ;
  my $iso = sprintf "Iso8601/%s%02d00", (-$h < 0 ? "-" : "+"), abs($h) ;
  my $posix = sprintf "Etc/GMT%s%d", ($h < 0 ? "" : "+"), $h ;
  add_alias_manually($iso, $posix) ;
}

print STDERR "WARNING: unsupported zones ", join(", ", sort keys %$unsupported), "\n" ;

# OUTPUT

for my $z (sort keys %$table)
{
  my $list = $table->{$z} ;
  my $str = join " ", @$list if @$list ;
  print "$str\n" ;
}

