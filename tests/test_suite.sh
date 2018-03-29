#!/usr/bin/bash

set -e

psql -qc 'drop database if exists db1'
psql -qc 'create database db1'
psql -qc 'drop database if exists db2'
psql -qc 'create database db2'

cd /build

R CMD INSTALL . > /dev/null 2>&1

export RPORT_CONFIG_PATH=/build/tests/database.yml

R --vanilla -e "library(testthat); test_file('tests/db.R')"
