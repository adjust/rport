library(rport)

context('PG copy')

test_that('copies various data types', {
  dat <- data.table(ts=as.POSIXct('2013-01-01 00:00:10'), id=1:10, bl=TRUE)
  con <- db.connection('db1')
  tbl.name <- 'pg_copy_test'

  pg.copy(con, tbl.name, dat)

  expect_equal(db('db1', 'table pg_copy_test'), dat)

  bad.dat <- data.table(ls=factor('dobrich'))
  msg <- 'Allowed data types arenumeric,character,integer,POSIXt,POSIXct,logical,Date'
  expect_error(pg.copy(con, tbl.name, bad.dat), msg)
})
