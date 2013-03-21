#!/bin/bash

function usage() {
    echo "Usage: ${0##*/} [FILE]
Read English wiki page about mobile country codes in edit mode:
http://en.wikipedia.org/w/index.php?title=Mobile_country_code&action=edit
and print out a mapping between MCC & MNC codes and countries.
The output format is

  <MCC> <MNC> <ISO3166 country code> <Name of Country>

For example

  123 45 AA Kingdom of Anonymous Aardwarks
  123 46 AA Kingdom of Anonymous Aardwarks
  456 78 RB Republic of Banana

Options:
  -h         Print this message"
}

if [ $# != 1 ]; then
    echo "${0##*/}: wrong number of arguments"
    usage
    exit 1
fi

if [ "$1" == "-h" ]; then
    usage
    exit
fi

if [ ! -f $1 ]; then
    echo "${0##*/}: the file $1 does not exist"
    usage
    exit 1
fi

TMPFILE1=`mktemp`
TMPFILE2=`mktemp`

# Fetch all lines that begin with either | or |====,
# remove MCC codes 001 (test network) & 901 (international networks)
grep -e "^|\|^====" $1 | grep -v "^|-\||}" \
    | grep -v "^|[[:space:]]*001\|^|[[:space:]]*901" > $TMPFILE1

# Remove wiki table controls, |, ||, [[, ]], ====, Replace " - " with ,
cat $TMPFILE1 | sed 's/^|[[:space:]]*//' | sed 's/[[:space:]]*||[[:space:]]*/,/g' \
    | sed 's/^=*[[:space:]]*\[\[//' | sed 's/]*[[:space:]]*-[[:space:]]*/,/' \
    | sed 's/[[:space:]]=*$//' | sed 's/\[\[//g' | sed 's/\]\]//g' > $TMPFILE2

# Replace &amp with &
cat $TMPFILE2 | sed 's/&amp;/&/' > $TMPFILE1

# Remove everyting starting with a &lt; (links)
cat $TMPFILE1 | sed 's/&lt;.*//' > $TMPFILE2

# Transform input
#
#   Kingdom of Anonymous Aardwarks,AA
#   123,45,Operator A,..
#   123,46,Operator B,..
#   Republic of Banana,RB
#   543,??,Not operational,...
#   456,78,Operator C,....
#
# where lines have either a name of a country and ISO3166 country code,
# or MCC, MNC, operator name, and stuff to
#
#  123 45 AA Kingdom of Anonymous Aardwarks
#  123 46 AA Kingdom of Anonymous Aardwarks
#  456 78 RB Republic of Banana
#
grep -v "?" $TMPFILE2 | awk '\
BEGIN { \
   country=""; iso="" \
} { \
   n=split($0, a, ","); \
   if (n==2) { \
      country=a[1]; iso=a[2]; \
  } else { \
      if (length(a[1]) == 3 && length(a[2]) > 0) \
         print a[1]" "a[2]" "iso" "country; \
  } \
} END {}' | sort | uniq

rm -f $TMPFILE1 $TMPFILE2
exit