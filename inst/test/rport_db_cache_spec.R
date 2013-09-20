source(sprintf('%s/../../R/rport.R', getwd()))

context('Testing caching of DB requests')

# create function stubs:
rport.db.cache.dir <- rport.root <- getwd

# TODO - delete files that are created from the tests in an after block

test_that('rport.db.cache.clean removes cache that isnt in .Rportcache', {
  write("doncho\nivan", '.Rport')
  file.create(sprintf('%s/dimitar.Rport', rport.db.cache.dir()))
  file.create(sprintf('%s/doncho.Rport', rport.db.cache.dir()))
  file.create(sprintf('%s/ivan.Rport', rport.db.cache.dir()))

  rport.db.cache.clean()

  expect_true(file.exists('doncho.Rport'))
  expect_true(file.exists('ivan.Rport'))
  expect_false(file.exists('dimitar.Rport'))
})

test_that('rport.db.cache.save creates R cache correctly', {
  obj <- data.table(ivan=3)
  sql <- 'select me from you'

  rport.db.cache.save(sql, obj)
  expect_true(file.exists('hashed_version.Rport'))

  load('hashed_version.Rport', envir=.MyTestEnv)
  obj.loaded <- get('obj', envir=.MyTestEnv)
  expect_that(obj, equals(obj.loaded))
})

test_that('rport.db.cache.get reads R cache correctly', {
  obj <- data.table(ivan=3)
  sql <- 'select me from you'

  rport.db.cache.save(sql, obj)

  expect_that(rport.db.cache.get(sql), equals(obj))
  expect_null(rport.db.cache.get('i am not cached'))
})
