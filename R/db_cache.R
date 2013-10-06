#' Look up for an entry in the .Rportcache file and load the respective file with
#' .Rportcache extension to the global environment.
#'
#' @param query sql query string
#' @param conn string connection name
#' @return nil if nothing found or results data.table with the loaded cache
#'
rport.db.cache.get <- function(query, conn) {
  file.name <- rport.db.cache.file.name(paste(query, conn))

  if (! file.exists(file.name))
    return(NULL)

  rport.log('Reading results for', query, 'from cache')

  tmp.env <- new.env()
  dat.name <- load(file.name, envir=tmp.env)
  dat <- get(dat.name, envir=tmp.env)
  tmp.env <- NULL

  rport.log('Done reading results for', query, 'from cache')

  dat
}

#' Upsert an entry in the .Rportcache file with a hash(query)
#'
#' @param query sql query string
#' @param conn string connection name
#' @param dat data.table with the results to save.
#'
rport.db.cache.save <- function(query, conn, dat) {
  file.name <- rport.db.cache.file.name(paste(query, conn))

  if (file.exists(file.name))
    file.remove(file.name)

  rport.log('Writing results from', query, 'to cache')

  save(dat, file=file.name)

  rport.log('Done writing to cache')
}

#' Remove all cache files from tmp/cache folder that have names not found in the
#' .Rportcache file
#'
rport.db.cache.clean <- function() {
  cache     <- list.files(rport.db.cache.dir(), pattern='\\.Rportcache$')
  to.delete <- file.path(rport.db.cache.dir(), cache)

  file.remove(to.delete)
}

#' TODO: for now hardcode this, but we could export this as a setting in
#' config/settings.R. The folder that will contain db cache files.
rport.db.cache.dir <- function() {
  d <- file.path(rport.root(), 'tmp', 'cache')

  if (! file.exists(d))
    dir.create(d, recursive=TRUE)

  d
}

#' Generate the file name of a cache file given query
#'
#' @param string file name of the cache file
#' @return string file name of the cache file
#'
rport.db.cache.file.name <- function(query) {
  file.path(rport.db.cache.dir(), sprintf('%s.Rportcache', digest(query)))
}
