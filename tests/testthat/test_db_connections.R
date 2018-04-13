library(rport)

pg_stat_activity <- function(db) {
  psql <- sprintf("
    psql -c \"
      select * from pg_stat_activity where datname='%s' and application_name = 'rport'
    \"
  ", db)
  paste(system(psql, intern=TRUE), collapse='\n')
}

context('opening and disconnecting DB connections')

test_that('db.disconnect()', {
  expect_true(grepl('(0 rows)', pg_stat_activity('db1')))
  expect_true(grepl('(0 rows)', pg_stat_activity('db2')))

  db('db1', 'select 1')
  expect_true(grepl('(1 row)', pg_stat_activity('db1')))
  expect_true(grepl('(0 rows)', pg_stat_activity('db2')))

  db.disconnect()
  expect_true(grepl('(0 rows)', pg_stat_activity('db1')))
  expect_true(grepl('(0 rows)', pg_stat_activity('db2')))

  db('db1', 'select 1')
  expect_true(grepl('(1 row)', pg_stat_activity('db1')))
  expect_true(grepl('(0 rows)', pg_stat_activity('db2')))

  expect_error(db.disconnect('db2'), 'No DBI connection by name: db2 has been open')
  db.disconnect('db1')
  expect_true(grepl('(0 rows)', pg_stat_activity('db1')))
  expect_true(grepl('(0 rows)', pg_stat_activity('db2')))
})

test_that('list.connections and closing all connections', {
  expect_equal(list.connections(), list())
  db('db1', 'select 1')
  expect_equal(list.connections(), list('db.connections::db1'=db.connection('db1')))
  db.disconnect()
  expect_equal(list.connections(), list())
})

test_that('list.connections and closing one connection', {
  db.disconnect()
  expect_equal(list.connections(), list())
  db('db1', 'select 1')
  expect_equal(list.connections(), list('db.connections::db1'=db.connection('db1')))
  db.disconnect('db1')
  expect_equal(list.connections(), list())
})

test_that('can add new connection settings', {
  err.msg <- 'Database connection name IVANISNOTADB not defined in database.yml'
  expect_error(db('IVANISNOTADB', 'select 1 as col'), err.msg)

  expect_equal(db('db1', 'select 1 as col'), data.table(col=1))

  register.connections(list(IVANISNOTADB=list(database='db1')))

  expect_equal(db('IVANISNOTADB', 'select 1 as col'), data.table(col=1))
  expect_equal(db('db1', 'select 1 as col'), data.table(col=1))
})

test_that('existing connections are overwritten using strict=FALSE', {
  new.settings <- list(db1=list(database='db1'))
  err.msg <- 'Some of the provided connection settings are already defined.'
  expect_error(register.connections(new.settings), err.msg)
  expect_error(register.connections(new.settings, strict=FALSE), NA)
})

test_that('we cannot pass duplicated connection definitions', {
  new.settings <- list(newdb=list(database='db1'), newdb=list(database='db2'))
  expect_error(register.connections(new.settings), 'Duplicated connection definitions')
})

test_that('Error is thrown for non-existing database config', {
  expect_error(db('db1', 'select 1 as col'), NA)
  expect_error(reload.db.config(), NA)
  Sys.setenv(RPORT_DB_CONFIG='nonexist.yml')
  expect_error(reload.db.config(), 'No configuration found here:nonexist.yml')
})

test_that('connections can be loaded, dynamically setup, reloaded', {
  expect_error(db('db1', 'select 1'), NA)
  expect_error(db('db2', 'select 1'), NA)
  expect_error(db('db3', 'select 1'), 'Database connection name db3 not defined in database.yml')
  register.connections(list(db3=list(database='db2')))
  expect_error(db('db3', 'select 1'), NA)
})
