#!/bin/bash -e

# set -o xtrace

# This script has to be executed in the build directory

zic=bin/zic
yearistype=bin/yearistype
signature=bin/signature
leapseconds=leapseconds

output=zones
signatures=signatures
md5sum=md5sum

test -x $zic
test -x $yearistype
test -x $signature
test -r $leapseconds
rm -rf $output $signatures $md5sum && mkdir -p $output

input="africa antarctica asia australasia europe northamerica southamerica"
input="$input iso8601"
input="$input etcetera factory systemv backward"
input="$input solar87 solar88 solar89"

for i in $input ; do
  echo "Processing '$i'"
  $zic -d $output -L /dev/null -y $yearistype $i 2> stderr
  $zic -d $output/posix -L /dev/null -y $yearistype $i 2>> stderr
  $zic -d $output/right -L $leapseconds -y $yearistype $i 2>> stderr
  cat stderr | grep -v "time zone abbreviation differs from POSIX standard" >&2 || true
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
$signature `pwd`/$output $zones > $signatures


