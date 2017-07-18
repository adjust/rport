#!/usr/bin/bash

psql -U postgres -c 'drop database if exists rporttest' &&
psql -U postgres -c 'create database rporttest' &&
Rscript -e 'library(roxygen2); roxygenize(clean=TRUE)' &&
R CMD INSTALL . &&
Rscript tests/test_suite.R
