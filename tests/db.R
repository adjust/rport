library(rport)

context('Single Connection Setup')
test_that('db performs read queries', {
  expect_equal(db('db1', 'SELECT 1 AS col'), data.table(col=1))
  expect_equal(db('db1', 'select 1 AS col'), data.table(col=1))
  expect_equal(db('db1', 'with q as (select 1 as col) select * from q'), data.table(col=1))
})

test_that('db takes query params', {
  expect_equal(db('db1', 'SELECT 1 AS col WHERE 1 = $1', 1), data.table(col=1))
  expect_equal(db('db1', 'SELECT 1 AS col WHERE 1 = $1', 2), data.table())
})

context('Sharded Setup')
test_that('db - single SQL on multiple DB connections', {
  received <- db(paste0('db', 1:2), "select 'abc'::text as col")
  expected <- data.table(col=rep('abc', 2))
  expect_equal(expected, received)

  # Also binds the params properly for multiple connections
  received <- db(paste0('db', 1:2), "select 'abc'::text as col WHERE 1 = $1", 1)
  expected <- data.table(col=rep('abc', 2))
  expect_equal(expected, received)
})

test_that('db - multiple SQL queries on single DB connection', {
  received <- db('db1', c("select 'abc'::text as col", "select 'xyz'::text as col"))
  expected <- data.table(col=c('abc', 'xyz'))
  expect_equal(expected, received)
})

test_that('db - multiple SQL queries on multiple DB connections', {
  # 3 queries on 2 connections - error
  connections <- c('db1', 'db2')
  sql <- c("select 'abc'::text as col", "select 'nop'::text as col", "select 'xyz'::text as col")
  expect_error(db(connections, sql))

  # 2 queries on 2 connections - success
  connections <- c('db1', 'db2')
  sql <- c("select 'abc'::text as col", "select 'nop'::text as col")

  received <- db(connections, sql)
  expected <- data.table(col=c('abc', 'nop'))

  expect_equal(expected, received)
})
