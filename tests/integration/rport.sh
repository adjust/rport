#!/usr/bin/bash

set -e

OUTPUT_DIR=tests/integration/actual
mkdir -p $OUTPUT_DIR
rm -f $OUTPUT_DIR/*.in

source tests/integration/helpers.sh

# Execute the query 10 times on the default cores
query "db(rep('db1', 10), 'select 1 as col')" > $OUTPUT_DIR/parallel
# Assert cluster of size 4 was started
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' $OUTPUT_DIR/parallel 4
# Assert query was run 10 times
assert_match_count 'select' $OUTPUT_DIR/parallel 10

# Execute the query 10 times on 5 cores
query "db(rep('db1', 10), 'select 1 as col', cores=5)" > $OUTPUT_DIR/parallel
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' $OUTPUT_DIR/parallel 5
assert_match_count 'select' $OUTPUT_DIR/parallel 10

# Execute multiple queries on single connection
query "db(rep('db1', 10), rep('select 1 as col', 10))" > $OUTPUT_DIR/parallel
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' $OUTPUT_DIR/parallel 4
assert_match_count 'select' $OUTPUT_DIR/parallel 10

# Execute multiple queries on multiple connections
query "db('db1', rep('select 1 as col', 10))" > $OUTPUT_DIR/parallel
assert_match_count 'starting worker pid=[0-9]+ on localhost:[0-9]+ at ([0-9]|:|\.)+' $OUTPUT_DIR/parallel 4
assert_match_count 'select' $OUTPUT_DIR/parallel 10

# Reconnects if it hits the max driver connections limit
query "options('rport-max-db-driver-connections'=1); db('db1', 'select 1'); db('db2', 'select 1')" > $OUTPUT_DIR/max_con
assert_match_count 'select 1' $OUTPUT_DIR/max_con 2
assert_match_count 'Max DB connections limit by the R driver hit, reconnecting. ' $OUTPUT_DIR/max_con 1
assert_match_count 'Connection closed successfully.' $OUTPUT_DIR/max_con 1
assert_match_count 'Done: db1' $OUTPUT_DIR/max_con 1
assert_match_count 'Done: db2' $OUTPUT_DIR/max_con 1

# Doesn't reconnect if the same connection is used
query "options('rport-max-db-driver-connections'=1); db('db1', 'select 1'); db('db1', 'select 1')" > $OUTPUT_DIR/max_con
assert_match_count 'select 1' $OUTPUT_DIR/max_con 2
assert_match_count 'Max DB connections limit by the R driver hit, reconnecting. ' $OUTPUT_DIR/max_con 0
assert_match_count 'Connection closed successfully.' $OUTPUT_DIR/max_con 0
assert_match_count 'Done: db1' $OUTPUT_DIR/max_con 2

echo "OK"
