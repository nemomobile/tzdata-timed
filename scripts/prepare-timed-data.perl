#!/usr/bin/perl -w
use strict ;

my $DEFAULT_ZONE_TAB = "/usr/share/zoneinfo/zone.tab" ;
# my $DEFAULT_ZONE_DIR = "/usr/share/zoneinfo" ;

usage(), exit 1 unless @ARGV ;

main() ;

sub main
{
  # 0. Read the mcc list from file given in --mcc-main=.....
  my $MCC = read_mcc_list_by_parameter("mcc-main") ;

  # 1. Find all the wiki page on the command line and take the latest one
  #    Returned data: $wiki->{$mcc} = { mcc=>$1, xy=>$2, comment=>$3 } ;
  my $wiki = read_wiki() ;

  # 2. Find and open zone.tab file on the command line: --olson=.......
  #    Returned data:
  #      *) { xy=>[ {tz=>"olson/zone", comment=>"comment"}, ... ] }
  #      *) [ { tz=>"olson/zone", comment=>"other comment" }, ... ]
  my ($olson_tab, $full_list) = read_zonetab_by_parameter("zonetab", "$DEFAULT_ZONE_TAB") ;
  #    signature = { "olson/name" => "alsjdajdnaksjdnaksjdn" }
  my $signature = read_signatures($full_list, "signatures") ;
  # ... and --single
  my ($single_tab) = read_zonetab_by_parameter("single") ;
  # ... and --distinct
  my ($distinct_tab) = read_zonetab_by_parameter("distinct") ;

  # 3. Process tiny countries
  my $single1 = find_countries(1, $MCC, $wiki, $olson_tab) ;
  my $single2 = find_countries(1, $MCC, $wiki, $single_tab) ;
  my @single = (sort { $a->{tz} cmp $b->{tz} } @$single1, @$single2) ;
  check_single_are_really_single($single_tab, $olson_tab, $signature) ;

  # 4. Process countries with clear defined timezones (not like US): --distinct=...
  my $distinct = find_countries(0, $MCC, $wiki, $distinct_tab) ;
  # same format for major and minor: { xy => [ "olson/name", ... ] }
  my ($major, $minor) = find_major_and_minor_zones($olson_tab, $distinct_tab, $signature) ;

  # $1. Output tables
  output_single(\@single, "single-output") ;
  output_distinct($distinct, "distinct-output") ;
  output_full($full_list, "full-output") ;
  output_country_by_mcc($wiki, "country-by-mcc-output") ; # TODO: reduce this list, remove single country stuff
  output_zones_by_country($major, $minor, "zones-by-country-output") ;

  # $$. Check unused flags
  usage() and die "Invalid command line parameters: " . join(", ", @ARGV) . "\n" if @ARGV ;

  # $$. Check unhandled codes
  my @uhoh = grep { not defined $MCC->{$_} } keys %$MCC ;
  die "Unhandled codes: " . join(", ", sort @uhoh) . ".\n"  if @uhoh ;

  exit 0 ;
}

# 0
sub read_mcc_list_by_parameter
{
  my $flag = shift ;
  my $file = extract_single_parameter($flag) ;
  print "Reading mcc codes from $file... " ;
  open FILE, "<", $file or die "can't read '$file': $!" ;
  my $list = { } ;
  while(<FILE>)
  {
    chomp ;
    next if /^\s*($|#)/ ;
    die "mcc file '$file' is corrupted" unless /^\d{3}$/ ;
    die "mcc file '$file' contains duplicate value $_" if exists $list->{$_} ;
    $list->{$_} = undef ;
  }
  print scalar keys %$list, " codes\n" ;
  return $list ;
}

# 1
sub read_wiki
{
  my $re = qr/^mcc-wikipedia-\d{4}-\d{2}-\d{2}(-*)?\.html$/ ;
  my @wiki_list = sort grep { /$re/ } @ARGV ;
  die "not a single wikipage given on command line" unless @wiki_list ;
  my $wiki_file = $wiki_list[-1] ;
  @ARGV = grep { ! /$re/ } @ARGV ;
  print "Using wikipedia file $wiki_file\n" ;
  open WIKI, "<", "$wiki_file" or die "$wiki_file: @!" ;
  my $wiki = { } ;
  while(<WIKI>)
  {
    chomp ;
    #| 412 || AF || [[Afghanistan]]
    next unless /^\|\s+(\d{3})\s+\|\|\s+([A-Z]{2})\s+\|\|\s*(.*)$/ ;
    my ($mcc, $xy, $comment) = ($1,$2,$3) ;
    print STDERR "Warning: duplicate mcc=$mcc (country=$xy) ignored\n" and next if exists $wiki->{$mcc} ;
    $wiki->{$mcc} = { mcc=>$1, xy=>$2, comment=>$3 } ;
  }
  my $size = scalar keys %$wiki ;
  print "$size mappings mcc=>country in the wiki file\n" ;
  return $wiki ;
}

# 2
sub read_zonetab_by_parameter
{
  my ($flag, $default) = (shift,shift) ;
  my $zone_tab_file = extract_single_parameter($flag, $default) ;
  $zone_tab_file = $default unless $zone_tab_file ;
  print "Reading zone table from $zone_tab_file... " ;
  open ZONES, "<", "$zone_tab_file" or die "$zone_tab_file: $!" ;
  my $zones = { } ;
  my $full = [] ;
  while(<ZONES>)
  {
    chomp ;
    next if /^\s*(#|$)/ ; # comment or empty line
    my @xxx = split(/\s+/, $_, 4) ;
    print STDERR "Warning: invalid line (splitted in ", scalar @xxx, "): $_\n" and next if @xxx < 3 ;
    # xxx = [ "XY", "-45.2343,+23.3049", "Omerigo/Metropolis", "blah blah" ]
    my ($xy, $comment, $tz, $comm2) = @xxx ;
    $comment .= " " . $comm2 if $comm2 ;
    $zones->{$xy} = [ ] unless exists $zones->{$xy} ;
    my $z_xy = $zones->{$xy} ;
    push @$z_xy, { tz=>$tz, comment=>$comment } ;
    push @$full, { tz=>$tz, comment=>"($xy) $comment" } ;
  }
  my $size = scalar keys %$zones ;
  print "$size time zones\n" ;
  return ($zones, $full) ;
}

# 3
sub find_countries
{
  my ($tiny, $MCC, $wiki, $zonetab) = (shift,shift,shift,shift) ;
  my $res = [ ] ;
  foreach my $mcc (sort keys %$MCC)
  {
    next unless exists $wiki->{$mcc} ; # Unknown geographical location
    my $xy = $wiki->{$mcc}->{xy} ;
    next unless exists $zonetab->{$xy} ; # No country in the table
    my $wiki_comment = $wiki->{$mcc}->{comment} ;
    my $zones = $zonetab->{$xy} ;
    if(@$zones == 1 and $tiny==1) # A single timezone
    {
      my $zone = $zones->[0] ;
      my $tz = $zone->{tz} ;
      my $olson_comment = $zone->{comment} ;
      my $full_comment = "($xy) $olson_comment $wiki_comment" ;
      my $entry = { mcc=>$mcc, tz=>$tz, comment=>$full_comment } ;
      push @$res, $entry ;
      die "Fatal: MCC=$mcc alreasy processed!\n" if defined $MCC->{$mcc} ;
      $MCC->{$mcc} = "single" ;
    }
    elsif($tiny==0) # Many distinct timzones
    {
      print STDERR "WARNING: a single timezone in a large country: MCC=$mcc ($xy)\n" if @$zones == 1 ;
      print STDERR "Warning: MCC=$mcc alreasy processed!\n" and next if defined $MCC->{$mcc} ;
      my $array = [] ;
      push @$array, $_->{tz} foreach (@$zones) ;
      my $full_comment = $xy . " " . $wiki_comment ;
      my $entry = { mcc=>$mcc, xy=>$xy, tz=>$array, comment=>$full_comment } ;
      push @$res, $entry ;
      $MCC->{$mcc} = "distinct" ;
    }
  }
  my $size = scalar @$res ;
  print "$size mcc codes processed " ;
  print $tiny ? "(single timezone)" : "(distinct timezones)", "\n" ;
  return $res ;
}

# $1

# XXX The list is huge, maybe it's better to print just two arrays
#     That whould be less readable for humans,
#     but much more faster to read for stupid computer. Let's see...
sub output_single
{
  my ($map, $flag) = (shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  return unless $file ;
  open FILE, ">", "$file" or die "can't write to $file: $!" ;
  print FILE "# NEVER TOUCH THIS GENERATED FILE\n" ;
  print FILE "list = [\n" ;
  my $q = '"' ;
  for my $i (@$map)
  {
    my $comma = "," ;
    $comma = "" if $i eq $map->[-1] ;
    print FILE "  { mcc = ", sprintf("%3d", $i->{mcc}), ", tz = $q", $i->{tz}, "$q }$comma // ", $i->{comment}, "\n" ;
  }
  print FILE "] .\n" ;
  close FILE or die "can't write to $file: $!" ;
  print "List of single zone countries (", scalar @$map, " mcc) is written to '$file'\n" ;
}

# XXX: replace all the "simple" words by "distinct"
sub output_distinct
{
  my ($map, $flag) = (shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  return unless $file ;
  open FILE, ">", "$file" or die "can't write to $file: $!" ;

  my $q = '"' ;
  my $txt = join (",\n",
    map {
      "  # " .  $_->{comment} . "\n" .
      "  { mcc = " . sprintf("%3d", $_->{mcc}) . ", " .
      "tz = [" .  join(", ", map { "$q$_$q" } @{$_->{tz}}) . "] }"
    } @$map
  ) ;

  print FILE "# NEVER TOUCH THIS GENERATED FILE\n" ;
  print FILE "list = [\n$txt\n] .\n" ;
  close FILE or die "can't write to $file: $!" ;
  print "List of countries with distinct zones (", scalar @$map, " mcc) is written to '$file'\n" ;
}

sub output_full
{
  my ($list, $flag) = (shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  return unless $file ;
  open FILE, ">", "$file" or die "can't write to $file: $!" ;
  my $q = '"' ;

  my $txt = join ("\n+$q,$q+ ",
    map {
      "$q" . $_->{tz} . "$q" .
      "  # " .  $_->{comment}
    } sort {$a->{tz} cmp $b->{tz}} @$list
  ) ;
  print FILE "# NEVER TOUCH THIS GENERATED FILE\n" ;
  print FILE "list =\n      $txt\n.\n" ;
  close FILE or die "can't write to $file: $!" ;
  print "Full list of geographical Olson names (", scalar @$list, " zones) is written to '$file'\n" ;
}

sub output_country_by_mcc
{
  my ($wiki, $flag) = (shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  return unless $file ;
  open FILE, ">", "$file" or die "can't write to $file: $!" ;
  my $q = '"' ;

  my $txt = join (",\n  ",
    map {
      "{ mcc=$_, country=" . $q . $wiki->{$_}->{xy} . "$q" . "}"
    } sort keys %$wiki
  ) ;
  print FILE "# NEVER TOUCH THIS GENERATED FILE\n" ;
  print FILE "mcc_to_xy =\n[\n  $txt\n] .\n" ;
  close FILE or die "can't write to $file: $!" ;
  print "Country by mcc mapping (", scalar keys %$wiki, " entries) is written to '$file'\n" ;
}

sub output_zones_by_country
{
  my ($major, $minor, $flag) = (shift,shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  return unless $file ;
  open FILE, ">", "$file" or die "can't write to $file: $!" ;
  my $q = '"' ;

  my @countries ;
  for my $xy (sort keys %$major)
  {
    my $maj_txt = join (", ", map { "$q$_$q" } @{$major->{$xy}}) ;
    my $min_txt = join (", ", map { "$q$_$q" } @{$minor->{$xy}}) ;
    push @countries, "  { xy=$q$xy$q, major=[$maj_txt], minor=[$min_txt] }" ;
  }
  my $txt = join (",\n  ", @countries) ;
  print FILE "# NEVER TOUCH THIS GENERATED FILE\n" ;
  print FILE "xy_to_tz =\n[\n  $txt\n] .\n" ;
  close FILE or die "can't write to $file: $!" ;
  print "Major and minor time zones are written to '$file'\n" ;
}

sub extract_single_parameter
{
  my ($flag, $optional) = (shift, shift) ;
  my $re = qr/^--$flag=(.+)$/ ;
  my @args = grep { m/$re/ } @ARGV ;
  return if $optional and not @args ;
  die "no or more than one --$flag=... given on command line\n" unless @args==1 ;
  die unless $args[0] =~ m/$re/ ;
  my $value = $1 ;
  @ARGV = grep { ! m/$re/ } @ARGV ;
  return $value ;
}

sub read_signatures
{
  my ($olson, $flag) = (shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  open SIGNATURES, "<", "$file" or die "can't read signatures file '$file'" ;
  my $sign = {} ;
  print "Reading time zone signatures from file '$file'... " ;
  while (<SIGNATURES>)
  {
    chomp ;
    next if /^\s*(#|$)/ ;
    die "inlavid signature" unless /^(\S+):\s*(\S+)$/ ;
    $sign->{$1} = $2 ;
  }
  print scalar(keys %$sign), " signatures read\n" ;

  print "Calculating time zone signatures ... " ;
  my %signatures ;
  for my $zone (@$olson)
  {
    my $tz = $zone->{tz} ;
    die "no signature of zone '$tz' found" unless exists $sign->{$tz} ;
    $signatures{$tz} = $sign->{$tz} ;
  }
  return \%signatures ;
}

sub check_single_are_really_single
{
  my ($single, $olson, $signatures) = (shift,shift,shift) ;
  for my $xy (keys %$single)
  {
    print "checking $xy ... " ;
    my $zones = $olson->{$xy} ;
    print " only one zone\n" if scalar(@$zones) == 1 ;
    next if scalar @$zones == 1 ;
    print scalar(@$zones), " zones ... " ;
    my $tz0 = $zones->[0]->{tz} ;
    for my $tz_i (@$zones)
    {
      my $tzi = $tz_i->{tz} ;
      die "$tz0 and $tzi differ" unless $signatures->{$tz0} eq $signatures->{$tzi} ;
    }
    print "ok\n" ;
  }
}

sub find_major_and_minor_zones
{
  my ($olson_tab, $distinct_tab, $signatures) = (shift,shift,shift) ;
  my ($major, $minor) = ({}, {}) ;
  for my $xy (keys %$distinct_tab)
  {
    my $major_xy = [] ;
    my $minor_xy = [] ;
    $major->{$xy} = $major_xy ;
    $minor->{$xy} = $minor_xy ;
    print "processing multy zone country $xy ... " ;
    my $known_sig = {} ;
    my $processed = {} ;
    # first ckeck, that major zones differ
    my $list1 = $distinct_tab->{$xy} ;
    for my $z (@$list1)
    {
      my $tz = $z->{tz} ;
      my $sig = $signatures->{$tz} ;
      die "$tz is the same as ".$known_sig->{$sig} if exists $known_sig->{$sig} ;
      $known_sig->{$sig} = $tz ;
      $processed->{$tz} = 1 ;
      push @$major_xy, $tz ;
    }
    # now go throw the full Olson list and filter out duplicates
    my $list2 = $olson_tab->{$xy} ;
    my $dupl_count = 0 ;
    for my $z (@$list2)
    {
      my $tz = $z->{tz} ;
      my $sig = $signatures->{$tz} ;
      ++$dupl_count if exists $known_sig->{$sig} and not exists $processed->{$tz} ;
      next if exists $known_sig->{$sig} ;
      $known_sig->{$sig} = $tz ;
      $processed->{$tz} = 1 ;
      push @$minor_xy, $tz ;
    }
    print scalar(@$major_xy), " majors: [", join(",", @$major_xy), "], " ;
    print scalar(@$minor_xy), " minors: [", join(",", @$minor_xy), "], " if @$minor_xy ;
    print "$dupl_count skipped" if $dupl_count > 0 ;
    print "\n" ;
  }
  return ($major, $minor) ;
}



# Usage
sub usage
{
  print STDERR
    "Usage: $0 \\\n" .
    "       --zonetab=ZONETAB --signatures=SIGNATURES \\\n" .
    "       --mcc-main=MCC --distinct=DISTINCT --single=SINGLE \\\n" .
    "       --single-output=path --distinct-output=path --full-output=path \\\n" .
    "       WIKI_FILES\n" .
    "where\n" .
    "       ZONETAB: alternative zone.tab file (by default $DEFAULT_ZONE_TAB)\n" .
    "       SIGNATURES: time zone signatures\n" .
    "       MCC: file containing mcc list\n" .
    "       DISTINCT: file containing major zones of countries with simple zone structure\n" .
    "       SINGLE: file containing contries, which became single zone\n" .
    "       WIKI_FILES: list of files from wikipedia, only the last one is used\n" .
    "output:\n" .
    "       --single...: list of all single zone countries\n" .
    "       --distinct...: information about simple structure counries\n" .
    "       --full...: all Olson names\n" .
    "Any output is optional.\n" .
    "Example:\n" .
    "       ./prepare-timed-data.perl --mcc-main=MCC --distinct=distinct.tab --single=single.tab mcc-wiki*.html\n" .
    "Wiki files have to be downloaded from:\n" .
    "       http://en.wikipedia.org/w/index.php?title=List_of_mobile_country_codes&action=edit&section=1"
    .
    "\n" ;
}

__END__


sub output_multizones
{
  use DateTime ;
  use DateTime::TimeZone ;
  my ($tab, $flag) = (shift,shift) ;
  my $file = extract_single_parameter($flag, 1) ;
  # return unless $file ;

  for my $xy (sort keys %$tab)
  {
    my @list = @{$tab->{$xy}} ;
    { use Data::Dumper ;
    print scalar @list, Dumper(@list)  ; }
    next unless scalar @list > 1 ;
    for my $z (@list)
    {
      my $tz = $z->{tz} ;
      my $zz = DateTime::TimeZone->new(name=>$tz) ;
      print "$xy $tz ", $zz->offset_for_datetime(DateTime::now()), "\n" ;
    }
  }
}
