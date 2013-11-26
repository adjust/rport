source('spec_helper.R', local=TRUE)

app <- 'my_app'
project <- 'my_project'

context('File structure of an app')

unlink(app, recursive=TRUE)

test_that('rport.app.new creates the expected file structure', {
  expect_that(rport.app.new(app), prints_text('Created file'))

  expect_that(list.files(app), is_identical_to(c(
    'README.md',
    'bin',
    'config',
    'doc',
    'lib',
    'log',
    'script',
    'spec'
  )))

  expect_that(list.files(app, recursive=TRUE), is_identical_to(c(
    'README.md',
    'config/database.yml',
    'config/settings.R',
    'spec/all'
  )))
})

context('File structure of a project')

test_that('rport.project.new adds the expected files', {
  expect_that(rport.project.new(project, root.dir=app),
              prints_text('Created file'))

  expect_that(file.exists(sprintf('%s/bin/%s.R', app, project)), is_true())
  expect_that(file.exists(sprintf('%s/lib/opts/%s.R', app, project)), is_true())
  expect_that(file.exists(sprintf('%s/lib/projects/%s/main.R', app, project)),
              is_true())
  expect_that(file.exists(sprintf('%s/spec/%s/main_spec.R', app, project)),
              is_true())
})
