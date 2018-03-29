#!/usr/bin/bash

set -e

assert_success () {
  if [ $? -eq 0 ]; then
    printf '.'
  else
    echo "ERROR $1 $2\n"
    exit 1
  fi
}

assert_match_count () {
  # we don't use `grep -c` because the workers could write on the same line
  cnt=$(grep -o -E "$1" $2 | wc -l)
  if [[ $cnt != "$3" ]]; then
    echo "ERROR: $2 matched '$1' $cnt times and not $3"
    exit 1
  fi
  printf '.'
}

rm -f tests/actual/*.in

# execute the query 10 times
R --slave --vanilla -e "library(rport); db(rep('db1', 10), 'select 1 as col')" > tests/actual/parallel
# assert cluster of size 4 was started
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' tests/actual/parallel 4
# assert query was run 10 times
assert_match_count 'Executing: select' tests/actual/parallel 10

echo "OK"
