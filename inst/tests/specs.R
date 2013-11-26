source('spec_helper.R', local=TRUE)

app <- 'my_app'

context('rport.specs.all Running an app\'s specs')

unlink(app, recursive=TRUE)

# startup an empty project
rport.app.new(app)

test_that('loads and runs all specs', {

  # create some true specs
  write("test_that('',{expect_that(TRUE, is_true())})",
        sprintf('%s/spec/test_spec1.R', app))

  write("test_that('',{expect_that(TRUE, is_true())})",
        sprintf('%s/spec/test_spec2.R', app))

  # expect that the specs pass
  expect_output(rport.specs.all(app), '\\.\\n\\.')
})

test_that('should capture failures', {

  # create some false specs
  write("test_that('',{expect_that(FALSE, is_true())})",
        sprintf('%s/spec/test_spec3.R', app))

  # expect that the specs wont pass
  expect_output(rport.specs.all(app), 'Failure\\(@test_spec3\\.R')
})

test_that('shows appropriate message if no specs found', {
  file.remove(list.files(sprintf('%s/spec/', app), pattern='*.R',
                         full.names=TRUE))

  expect_output(rport.specs.all(), 'No tests found')
})

unlink(app, recursive=TRUE)
