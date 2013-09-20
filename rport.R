rport <- function() {

}

rport.sql <- function(query, key=NULL, cache=FALSE) {
  if (exists('read.con', envir=.RportConnEnv)) {
    runr.cat('Reading:', query)

    res <- data.table(dbGetQuery(get('read.con', envir=.RportConnEnv), query))

    if (! is.null(key) && ! is.null(res[[key]]))
      setkeyv(res, key)

    res
  }
}





runr.cat <- function(...) cat(Sys.time(), '--', Sys.getpid(), ..., "\n")

# if an error occurs from a script, provide better error report
# TODO differentiate between interactive and non-interactive sessions error
# handling. Eg. for non-interactive sessions add `q()`
options(error = quote({ recover(); debugger(); q() }))

runr.start <- function(envir='apptrace') {
  runr.cat()
  runr.cat('Hello')

  if (envir == 'apptrace')
  {
    assign('read.con',
           dbConnect('PostgreSQL', dbname=read.db, user=read.usr, host=read.host),
           envir=.GlobalEnv)

    assign('write.con',
           dbConnect('PostgreSQL', dbname=write.db, user=write.usr, host=write.host),
           envir=.GlobalEnv)

    runr.cat('Reading from', read.host, read.db, ';', 'Writing to', write.host,
             write.db)
  }
  else if (envir == 'adjust')
  {
    assign('read.con', dbConnect('PostgreSQL',
      dbname = read.db.adjust,
      user   = read.usr.adjust,
      host   = read.host.adjust
      ), envir=.GlobalEnv)

    assign('write.con',
           dbConnect('PostgreSQL', dbname=write.db, user=write.usr, host=write.host),
           envir=.GlobalEnv)

    runr.cat('Reading from', read.host, read.db, ';', 'Writing to', write.host,
             write.db)
  }
}

runr.shutdown <- function() {
    connections <-
      c('read.con', 'write.con', 'read.con.adjust', 'write.con.adjust')

  for (v in connections)
    if (exists(v, envir=.GlobalEnv))
      dbDisconnect(get(v, envir=.GlobalEnv))

  runr.cat('Goodbye')
}

runr.run <- function(script) {
  if (file.exists(script))
    source(script)
  else
    print(paste('Script not found:', script))
}

# wraper around dbGetQuery
# TODO refactor this using S3 classes
# TODO get rid of the sprintf thing here
runr.get <- function(query, key=NULL)
{
}

# wraper around dbSendQuery
runr.write <- function(query, ...)
{
  if (exists('write.con', envir=.GlobalEnv)) {
    query <- sprintf(query, ...)
    runr.cat('Writing:', query)
    dbSendQuery(get('write.con', envir=.GlobalEnv), query)
  }
  else
    print('O-oo. Do a `runr.start` first, bitte')
}

runr.write.get <- function(query, ...)
{
  if (exists('write.con', envir=.GlobalEnv)) {
    query <- sprintf(query, ...)
    runr.cat('Reading from Write Connection:', query)
    dbGetQuery(get('write.con', envir=.GlobalEnv), query)
  }
  else
    print('O-oo. Do a `runr.start` first, bitte')
}

runr.dbWriteTable <- function(table_name, object, ...)
{
  if (exists('write.con', envir=.GlobalEnv)) {
    runr.cat('Writing to:', table_name)
    dbWriteTable(write.con, table_name, object, ...)
  }
  else
    print('O-oo. Do a `runr.start` first, bitte')
}

runr.app <- function(app_id)
  runr.get('select * from applications where id=%s', app_id)

runr.in <- function(field, collection)
{
  if ( class(collection) == 'character' )
    sprintf("%s in ('%s')", field, paste(collection, collapse="','"))
  else
    sprintf('%s in (%s)', field, paste(collection, collapse=','))
}

# this converts today to an apptrace db-friendly integer - eg. 1st June 2012 =
# 151. `adjustment` will add days to today and `as.range`=TRUE would return it
# as an ordered array
runr.today <- function(adjustment=0, as.range=FALSE)
{
  today <-
    as.integer(difftime(Sys.time(), ISOdate(2012,01,01,00), units='days')) + 1

  if (as.range == TRUE)
    sort(today:(today+adjustment))
  else
    today+adjustment
}

runr.yesterday <- function(adjustment=0, as.range=FALSE)
{
  yesterday <- runr.today(-1)

  if (as.range == TRUE)
    sort(yesterday:(yesterday+adjustment))
  else
    yesterday+adjustment
}

# convert an integer to day relative to 1.1.2012
# or
# convert a string to integer relative to 1.1.2012
# Example:
# runr.date(-10) # '2011-12-22'
# runr.date('2011-12-22') # -10

runr.date <- function(arg)
{
  if (is.numeric(arg))
    as.Date('2012-01-01') + arg
  else
    as.integer(difftime(as.Date(arg), ISOdate(2012,01,01,00), units='days'))
}

# returns data.table with the global ranks for some days back
runr.global.rank <- function(days = 2)
{
  data.table(runr.get('
    select created_at as day, application_id as app, title, rank
    from application_ranks inner join applications on application_id =
    applications.id where %s order by day, rank',
    runr.in('created_at', runr.yesterday(- days + 1, as.range=TRUE))))
}

# function to load settings for specific task - e.g. send mails
runr.bootstrap <- function(arg)
{
  # todo refactor that with generic function and S3 classes
  if (arg == 'mail')
  {
    library(sendmailR)
  }
}
