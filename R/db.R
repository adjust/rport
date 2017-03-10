#' Establishes all database connections in given configuration. Connections are
#' defined in config/database.yml. Also creates helper methods for accessing
#' these connections that are stored in .GlobalEnv.
#'
#' @param connections list like
#'
#' cons <- list (
#'   read = list(db=my_slave, user=my_slave_user)
#' )
#'
rport.db.connect <- function(connections) {
  for (key in names(connections)) {
    func.def <- rport.db.helper.render(key)

    # dynamically define helper method for queries to this connection
    if (! exists(sprintf('rport.%s', key), envir=.GlobalEnv))
      eval(parse(text=func.def), envir=.GlobalEnv)

    require(connections[[key]]$package, character.only=TRUE)

    driver <- dbDriver("PostgreSQL", max.con=32)

    assign(key,
           .dbConnect(drv=driver,
                     application_name=connections[[key]]$application_name,
                     dbname=connections[[key]]$database,
                     user=connections[[key]]$user,
                     password=connections[[key]]$password,
                     port=connections[[key]]$port,
                     host=connections[[key]]$host),
           envir=.RportRuntimeEnv)
  }
}

# A wrapper around dbConnect()
.dbConnect <- function(drv, application_name, ...) {
  old <- Sys.getenv("PGAPPNAME")
  Sys.setenv(PGAPPNAME=application_name)
  conn <- dbConnect(...)
  Sys.setenv(PGAPPNAME=old)
  conn
}

# Template for magic database query functions.
rport.db.helper.render <- function(key) {
  template <- '
    rport.{{name}} <- function(query, key=NULL, cache=FALSE)
      rport.db.query(\'{{name}}\', query, key, cache)
  '

  whisker.render(template, list(name=key))
}

#' Retrieve database connection by name
#'
#' @export
#'
rport.db.connection <- function(name) {
  if (! exists(name, envir=.RportRuntimeEnv))
    stop('Connection %s not found in envir .RportRuntimeEnv', conn)

  conn <- get(name, envir=.RportRuntimeEnv)

  if (! inherits(conn, 'DBIConnection'))
    stop('Object %s is not a database connection.', name)

  conn
}

#' Runns a query against given db connection.
#'
#' @export
#'
rport.db.query <- function(conn, query, key, cache) {
  if (! exists(conn, envir=.RportRuntimeEnv))
    stop(sprintf('Connection %s not found in envir .RportRuntimeEnv', conn))

  # boolean: should we do caching?
  is.cache <- function()
    cache && rport.environment.is('development')

  rport.log('Executing:', query, 'on', conn)

  if (is.cache()) {
    cached <- rport.db.cache.get(query, conn)

    if (!is.null(cached)) {
      rport.log('Retruning cached result.')
      return(cached)
    }
  }

  res <- data.table(dbGetQuery(get(conn, envir=.RportRuntimeEnv), query))

  if (! is.null(key) && ! is.null(res[[key]]))
    setkeyv(res, key)

  rport.log('Done:', query, 'on', conn)

  if (is.cache() && nrow(res) > 0)
    rport.db.cache.save(query, conn, res)

  res
}

rport.db.disconnect <- function() {
  for (obj.name in ls(envir=.RportRuntimeEnv)) {
    tryCatch(
      {
        obj = get(obj.name, envir=.RportRuntimeEnv)

        if (inherits(obj, 'DBIConnection')) {
          rport.log('Attempting to close', obj.name)

          r <- dbDisconnect(obj)

          if (r)
            rport.log('Connection closed successfully.')
          else
            stop('Connection failed to close.')
        }
      },
      error = function(e) {
        rport.log('Error closing database connection', obj.name)
        rport.log(geterrmessage())
      }
    )
  }
}
