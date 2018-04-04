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

query () {
  R --slave --vanilla -e "library(rport, quietly=TRUE); $1"
}

rm -f tests/actual/*.in

# Execute the query 10 times on the default cores
query "db(rep('db1', 10), 'select 1 as col')" > tests/actual/parallel
# Assert cluster of size 4 was started
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' tests/actual/parallel 4
# Assert query was run 10 times
assert_match_count 'select' tests/actual/parallel 10

# Execute the query 10 times on 5 cores
query "db(rep('db1', 10), 'select 1 as col', cores=5)" > tests/actual/parallel
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' tests/actual/parallel 5
assert_match_count 'select' tests/actual/parallel 10

# Execute multiple queries on single connection
query "db(rep('db1', 10), rep('select 1 as col', 10))" > tests/actual/parallel
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' tests/actual/parallel 4
assert_match_count 'select' tests/actual/parallel 10

# Execute multiple queries on multiple connections
query "db('db1', rep('select 1 as col', 10))" > tests/actual/parallel
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' tests/actual/parallel 4
assert_match_count 'select' tests/actual/parallel 10

# Reconnects if it hits the max driver connections limit
RPORT_MAX_CON=1 query "db('db1', 'select 1'); db('db2', 'select 1')" > tests/actual/max_con
assert_match_count 'select 1' tests/actual/max_con 2
assert_match_count 'Max DB connections limit by the R driver hit, reconnecting. ' tests/actual/max_con 1
assert_match_count 'Connection closed successfully.' tests/actual/max_con 1
assert_match_count 'Done: db1' tests/actual/max_con 1
assert_match_count 'Done: db2' tests/actual/max_con 1

echo "OK"
