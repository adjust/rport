#!/usr/bin/bash

set -e

psql -qc 'drop database if exists db1'
psql -qc 'create database db1'
psql -qc 'drop database if exists db2'
psql -qc 'create database db2'

cd /build

R CMD INSTALL . > /dev/null

export RPORT_DB_CONFIG=/build/tests/database.yml

# I. Unit testing using testthat
R --slave --vanilla -e "library(testthat); test_file('tests/testthat/test_db.R')"
R --slave --vanilla -e "library(testthat); test_file('tests/testthat/test_db_connections.R')"

# II. Integration testing. This test suite tests things like parallism and output, which are easier to
# test by comparing diffs, rather than by using a test framework.
source tests/integration/rport.sh
