#!/bin/bash -e

# set -o xtrace

# This script has to be executed in the build directory

zic=bin/zic
yearistype=bin/yearistype
output=zones-listing

test -x $zic
test -x $yearistype
rm -rf $output && mkdir -p $output

zic_cmd="$zic -L /dev/null -y $yearistype "

input="africa antarctica asia australasia europe northamerica southamerica iso8601"

for continent in $input ; do
  test -f $continent
done

cat $input | pcregrep -v '^\s*Link\s+' | tee aaaa | $zic_cmd -d $output 2> stderr -
cat stderr | grep -v "time zone abbreviation differs from POSIX standard" >&2 || true

{
  for f in $(cd $output ; echo *) ; do
    if test -d $output/$f ; then
      ( cd $output && find $f -type f )
    elif test -f $output/$f ; then
      echo $f
    fi
  done

#  ( cat zone.tab | pcregrep -v '^\s*#' | awk '{print $3}' )

} | sort | uniq
