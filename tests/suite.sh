#!/usr/bin/bash

set -e

psql -qc 'drop database if exists db1'
psql -qc 'create database db1'
psql -qc 'drop database if exists db2'
psql -qc 'create database db2'

# we need schema only for the pg.copy test
psql -q db1 -c 'create table pg_copy_test (ts timestamp, id int, bl bool)'

cd /build

R CMD INSTALL . > /dev/null

export RPORT_DB_CONFIG=/build/tests/database.yml

# I. Unit testing using testthat
R --slave --vanilla -e "library(testthat); test_file('tests/testthat/test_db.R')"
R --slave --vanilla -e "library(testthat); test_file('tests/testthat/test_db_connections.R')"
R --slave --vanilla -e "library(testthat); test_file('tests/testthat/test_pg_copy.R')"

# II. Integration testing. This test suite tests things like parallism and output, which are easier to
# test by comparing diffs, rather than by using a test framework.
source tests/integration/rport.sh
