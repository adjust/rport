library(rport)

test_that('.read.db.config', {
  .read.db.config <- rport:::.read.db.config

  expected <- list(
    read=list(
      database='my_database',
      encoding='',
      username='my_user',
      password='',
      host='localhost',
      port=5432,
      application_name='my-app',
      query_cache_ttl=300
    ),
    write=list(
      database='my_database',
      encoding='',
      username='postgres',
      password='',
      host='localhost',
      port=5432,
      application_name='my-app',
      query_cache_ttl=300
    )
  )
  received <- .read.db.config(getwd, 'database.yml')

  expect_equal(expected, received)
})

test_that('.cache.eligible', {
  .cache.eligible <- rport:::.cache.eligible
  expect_equal(.cache.eligible(NULL, 1), FALSE)

  .stub.timestamp <- function(timestamp) function(x=0) { timestamp + x }

  # Only eligible for reading from cache if hit between 12345 and 12347
  cached <- list(timestamp=12345, ttl=10)
  expect_equal(.cache.eligible(cached, max.cache.age=5, new.ttl=10, .stub.timestamp(12346)), TRUE)
  expect_equal(.cache.eligible(cached, max.cache.age=5, new.ttl=10, .stub.timestamp(12351)), FALSE)

  # Only eligible if hit within cache TTL - cache with indefinite age
  cached <- list(timestamp=12345, ttl=10)
  expect_equal(.cache.eligible(cached, max.cache.age=-1, new.ttl=10, .stub.timestamp(12346)), TRUE)
  expect_equal(.cache.eligible(cached, max.cache.age=-1, new.ttl=10, .stub.timestamp(12356)), FALSE)

  # Only eligible if hit within cache TTL - cache with big age
  cached <- list(timestamp=12345, ttl=10)
  expect_equal(.cache.eligible(cached, max.cache.age=100, new.ttl=10, .stub.timestamp(12346)), TRUE)
  expect_equal(.cache.eligible(cached, max.cache.age=100, new.ttl=10, .stub.timestamp(12356)), FALSE)
})

test_that('db - single query', {
  config <- "read:\n  database: rporttest\n  username: postgres\n  password: ''\n  host: localhost\n  port: 5432\n  application_name: analytics-app"
  write(config, '.database.yml')
  Sys.setenv(RPORT_CONFIG_PATH='.database.yml')

  # should connect to the DB and run queries
  res <- db('read', 'select 1 as field')

  expect_equal(res, data.table(field=1))

  # should append the application_name to the connection stats
  expected <- data.table(application_name='analytics-app')
  res <- db('read', "select application_name from pg_stat_activity where datname = 'rporttest'")
  expect_equal(res, expected)

  # should cache the result
  store <- get('rport.store', envir=.RportRuntimeEnv)
  received <- store[['query.cache::981d881524e4b5b0177154bd58c193a29a658a6b']]$object
  expect_equal(expected, received)
  expect_equal(300, store[['query.cache::981d881524e4b5b0177154bd58c193a29a658a6b']]$ttl)

  # should cache the result according to given options
  res <- db('read', "select application_name from pg_stat_activity where datname = 'rporttest'", cache.ttl=299)
  store <- get('rport.store', envir=.RportRuntimeEnv)
  expect_equal(299, store[['query.cache::981d881524e4b5b0177154bd58c193a29a658a6b']]$ttl)
})

test_that('db - sharded setup', {
  config <- "shard1:\n  database: rporttest\n  username: postgres\n  password: ''\n  host: localhost\n  port: 5432\n  application_name: analytics-app
shard2:\n  database: rporttest\n  username: postgres\n  password: ''\n  host: localhost\n  port: 5432\n  application_name: analytics-app
shard3:\n  database: rporttest\n  username: postgres\n  password: ''\n  host: localhost\n  port: 5432\n  application_name: analytics-app
shard4:\n  database: rporttest\n  username: postgres\n  password: ''\n  host: localhost\n  port: 5432\n  application_name: analytics-app"
  write(config, '.database.yml')
  Sys.setenv(RPORT_CONFIG_PATH='.database.yml')

  # should connect to the DB and run queries
  received <- db(paste('shard', 1:4, sep=''), "select 'abc'::text as field")
  expected <- data.table(field=rep('abc', 4))
  expect_equal(expected, received)
})
