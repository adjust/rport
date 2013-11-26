source('spec_helper.R', local=TRUE)

app <- 'my_app'

unlink(app, recursive=TRUE)

rport.app.new(app)

file.copy('test_datatabase.yml', sprintf('%s/config/database.yml', app),
          overwrite=TRUE)

old.wd <- getwd()
setwd(app)

rport('development')

context('Testing performing DB requests')

test_that('rport.db.cache.clean removes cache that isnt in .Rportcache', {
  rport.db.query('write', 'select 1')
})

setwd(old.wd)
rport
