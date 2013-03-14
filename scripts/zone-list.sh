#!/bin/bash -e

function usage() {
    echo "Usage ${0##*/} [TZDATA DIR] [BUILD DIR]
Builds the tz database from sources in [TZDATA DIR]
without links to directory [BUILD DIR]/zones-without-links
and prints out all time zones in the resulting database.
See man zic for more information about time zone links.
This script expects that the directory [BUILD DIR] contains
the files

  iso8601    Custom ISO 8016 time zones in the same format
             as the time zone files in [TZDATA DIR]
  yearistype Executable to check year type, see man zic

Options:
  -h         Print this message"
}

if [ "$1" == "-h" ]; then
    usage
    exit
fi

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

src_dir=$1
build_dir=$2

zic=/usr/sbin/zic
yearistype=$build_dir/yearistype
output=$build_dir/zones-without-links

if [ ! -x $zic ]; then
    echo "${0##*/}: $zic does not exist or is not executable"
    exit 1
fi

if [ ! -x $yearistype ]; then
    echo "${0##*/}: $yearistype does not exist or is not executable"
    exit 1
fi

rm -rf $output && mkdir -p $output

zic_cmd="$zic -L /dev/null -y $yearistype "

input="$src_dir/africa $src_dir/antarctica $src_dir/asia $src_dir/australasia $src_dir/europe $src_dir/northamerica $src_dir/southamerica"
input="$input $build_dir/iso8601"

for continent in $input ; do
  test -f $continent
done

cat $input | pcregrep -v '^\s*Link\s+' | tee $build_dir/aaaa | $zic_cmd -d $output 2> $build_dir/stderr -
cat $build_dir/stderr | grep -v "time zone abbreviation differs from POSIX standard" >&2 || true

{
  for f in $(cd $output ; echo *) ; do
    if test -d $output/$f ; then
      ( cd $output && find $f -type f )
    elif test -f $output/$f ; then
      echo $f
    fi
  done
} | sort | uniq
