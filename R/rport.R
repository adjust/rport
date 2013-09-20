#' Bootstraps your Rport project using the `env` configuration. Should be
#' placed at the beginning of each project. This is done automatically if you
#' use the project generators.
#'
#' @param env string specifying configuration settings to use.
#'
rport <- function(env='development') {
  config.path <- rport.root('config/database.yml')

  if (file.exists(config.path)) {
    config <- yaml.load_file(config.path)
    rport.db.connect(config[[env]])
  } else {
    rport.log('No configuration found here:', config.path)
  }
}

### Private methods

#' Establishes database connections for given configuration.
#' @param connections list like
#'
#' cons <- list (
#'   read = list(db=my_slave, user=my_slave_user)
#' )
#'
rport.db.connect <- function(connections) {
  # TODO: make caching work in this function
  template <- '
    rport.{{name}} <- function(query, key=NULL, cache=FALSE) {
      if (exists({{name}}, envir=.RportDbEnv)) {
        rport.log(\'Executing:\', query, \'on {{name}}\')

        res <- data.table(dbGetQuery(get({{name}}, envir=.RportDbEnv), query))

        if (cache) {
          cached <- rport.db.cache.get(query)

          if (!is.null(cached)) {
            rport.log(\'Retruning cached result.\')
            return(cached)
          }
        }

        if (! is.null(key) && ! is.null(res[[key]]))
          setkeyv(res, key)

        rport.log(\'Done:\', query, \'on {{name}}\')

        if (cache)
          rport.db.cache.save(query, res)

        res
      }
    }
  '

  for (key in names(connections)) {
    func.def <- whisker.render(template, list(name=key))

    # dynamically define a helper method for queries to this connection
    if (! exists(sprintf('rport.%s', key), envir=.GlobalEnv))
      eval(parse(text=func.def), envir=.GlobalEnv)

    assign(key, dbConnect('PostgreSQL', dbname=connections[[key]]$database,
           user=connections[[key]]$user, host=connections[[key]]$host),
           envir=.RportDbEnv)
  }
}

#' TODO: make it so
#'
#' The root directory of the current project
#'
rport.root <- function(subdir=NULL) {
  tmp <- getwd()

  if (! is.null(subdir))
    tmp <- sprintf('%s/%s', tmp, subdir)

  tmp
}

#' Creates the file sceleton and codebase for a new Rport project. Use it to
#' start a new report, repeatable task, etc.
#'
#' @param env string specifying configuration settings to use.
#'
rport.new <- function(name) {
  cmd <- '
    mkdir -p
  '
}

#' Formats logging output.
rport.log <- function(...) {
  cat(Sys.time(), '--', Sys.getpid(), ..., "\n")
}

#' Look for an entry in the .Rportcache file and load the respective file with
#' .Rportcache extension to the global environment.
#'
#' @param query sql query string
#' @return nil if nothing found or results data.table with the loaded cache
#'
rport.db.cache.get <- function(query) {
}

#' Upsert an entry in the .Rportcache file with a hash(query)
#'
#' @param query sql query string
#' @param dat data.table with the results to save.
#'
rport.db.cache.save <- function(query, dat) {
}

#' Remove all cache files from tmp/cache folder that have names not found in the
#' .Rportcache file
#'
rport.db.cache.clean <- function() {
  cached <- list.files(rport.db.cache.dir(), pattern='\\.Rport$')
  cached <- gsub('\\.Rportcache$', '', cached)

  recorded <- read.csv('.Rportcache', header=FALSE)

  to.delete <- cached[!cached %in% recorded]
  to.delete <- sprintf('%s/%s', rport.db.cache.dir(), to.delete)

  file.remove(to.delete)
}

#' TODO: for now hardcode this. The folder that will contain db cache files.
rport.db.cache.dir <- function() {
  sprintf('%s/tmp/cache', rport.root())
}
