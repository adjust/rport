source('spec_helper.R', local=TRUE)

app.name <- 'my_app'

unlink(app.name, recursive=TRUE)

rport.app.new(app.name)

file.copy('test_datatabase.yml', sprintf('%s/config/database.yml', app.name),
          overwrite=TRUE)

old.wd <- getwd()
setwd(app.name)

context('Testing performing DB requests')

test_that('rport.db.connection retrieves database connection', {
  rport('development')

  conn <- rport.db.connection('write')

  expect_that(inherits(conn, 'DBIConnection'), is_true())
})

setwd(old.wd)

unlink(app.name, recursive=TRUE)
