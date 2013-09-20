context('Unit test')

test_that('rport.root gives the correct working dir', {
  d <- rport.root()
  expect_that(d, equals('ivan'))

  d <- rport.root('pesho')
  expect_that(d, equals('ivan/pesho'))
})

