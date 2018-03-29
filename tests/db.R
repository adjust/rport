library(rport)

context('Single Connection Setup')
test_that('db ignores non-read queries', {
  expect_error(db('db1', 'INSERT INTO tbl(id) (VALUES (1))'))
  expect_error(db('db1', 'update tbl SET id=1'))
  expect_error(db('db1', 'DELETE FROM tbl'))
  expect_error(db('db1', 'TRUNCATE TABLE tbl'))
})

test_that('db performs read queries', {
  expect_equal(db('db1', 'SELECT 1 AS col'), data.table(col=1))
  expect_equal(db('db1', 'select 1 AS col'), data.table(col=1))
  expect_equal(db('db1', 'with q as (select 1 as col) select * from q'), data.table(col=1))
})

context('Sharded Setup')
test_that('db sharded setup', {
  received <- db(paste0('db', 1:2), "select 'abc'::text as col")
  expected <- data.table(col=rep('abc', 2))
  expect_equal(expected, received)
})
