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
test_that('db distributes SQL on a DB cluster', {
  received <- db(paste0('db', 1:2), "select 'abc'::text as col")
  expected <- data.table(col=rep('abc', 2))
  expect_equal(expected, received)
})
