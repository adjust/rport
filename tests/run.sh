#!/usr/bin/bash

set -e

psql -qc 'drop database if exists db1'
psql -qc 'create database db1'
psql -qc 'drop database if exists db2'
psql -qc 'create database db2'

cd /build

R CMD INSTALL . > /dev/null

export RPORT_DB_CONFIG=/build/tests/database.yml

# Run the testthat test suite.
R --slave --vanilla -e "library(testthat); test_file('tests/rport.R')"

# This test suite tests things like parallism and output, which are easier to
# test by comparing diffs, rather than by using a test framework.
source tests/test_suite.sh
