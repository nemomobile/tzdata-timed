#!/bin/bash -e

function usage() {
    echo "Usage ${0##*/} [TZDATA DIR] [BUILD DIR]
Build the complete tz database with links from sources
in [TZDATA DIR], with custom ISO 8601 zones from file
[BUILD DIR]/iso8601, to directory [BUILD DIR]/zones. Output
a list of time zones that are links to [BUILD DIR]/zone.link.
Calculate md5 sums for the time zones, store in file
[BUILD DIR]/md5sums. Calculate custom signatures for the
time zones with the [BUILD DIR]/signature binary, output
signatures to file [BUILD DIR]/signatures.

This script expects that the directory [BUILD DIR] contains
the files

  iso8601    Custom ISO 8601 time zones in the same format
             as the time zone files in [TZDATA DIR]
  yearistype Executable to check year type, see man zic
  signatures Executable to calculate custom digital
             signatures for time zones in the compiled tz
             database

Options:
  -h         Print this message"
}

if [ $# != 2 ]; then
    echo "${0##*/}: wrong number of arguments"
    usage
    exit 1
fi

if [ ! -d $1 ]; then
    echo "${0##*/}: the directory $1 does not exist"
    usage
    exit 1
fi

if [ ! -d $2 ]; then
    echo "${0##*/}: the directory $2 does not exist"
    usage
    exit 1
fi

source_dir=$1
build_dir=$2

zic=/usr/sbin/zic

# Input
yearistype=$build_dir/yearistype
signature=$build_dir/signature
leapseconds=$source_dir/leapseconds
iso8601=$build_dir/iso8601

# Output
output=$build_dir/zones
signatures=$build_dir/signatures
md5sum=$build_dir/md5sum
links=$build_dir/zone.link

if [ ! -x $zic ]; then
    echo "${0##*/}: $zic does not exist or is not executable"
    exit 1
fi

if [ ! -x $yearistype ]; then
    echo "${0##*/}: $yearistype does not exist or is not executable"
    exit 1
fi

if [ ! -x $signature ]; then
    echo "${0##*/}: $yearistype does not exist or is not executable"
    exit 1
fi

if [ ! -r $leapseconds ]; then
    echo "${0##*/}: $leapseconds does not exist or is not readable"
    exit 1
fi

rm -rf $output $signatures $md5sum && mkdir -p $output

input="$source_dir/africa $source_dir/antarctica $source_dir/asia $source_dir/australasia $source_dir/europe $source_dir/northamerica $source_dir/southamerica"
input="$input $iso8601"
input="$input $source_dir/etcetera $source_dir/factory $source_dir/systemv $source_dir/backward"
input="$input $source_dir/solar87 $source_dir/solar88 $source_dir/solar89"

for i in $input ; do
  echo "Processing '$i'"
  $zic -d $output -L /dev/null -y $yearistype $i 2> $build_dir/stderr
  $zic -d $output/posix -L /dev/null -y $yearistype $i 2>> $build_dir/stderr
  $zic -d $output/right -L $leapseconds -y $yearistype $i 2>> $build_dir/stderr
  cat $build_dir/stderr | grep -v "time zone abbreviation differs from POSIX standard" >&2 || true
done
$zic -d $output -p America/New_York

zones=$(
  for f in $(cd $output ; echo *) ; do
    if [ "$f" = "posix" ] || [ "$f" = "right" ] ; then
      true # skip posix/* right/*
    elif test -d $output/$f ; then
      ( cd $output && find $f -type f )
    elif test -f $output/$f ; then
      echo $f
    fi
  done
)

( cd $output && md5sum $zones ) > $md5sum
$signature $output $zones > $signatures
cat $input | pcregrep '^\s*Link\s+' > $links

