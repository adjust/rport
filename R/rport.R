.DB.CONFIG      <- 'db.config'
.DB.CONNECTIONS <- 'db.connections'
.RPORT.STORE    <- 'rport.store'
.DB.DRIVER      <- 'db.driver'
.QUERY.VALIDATION <- '^\\s*(select|with)'

#' @export
.RportRuntimeEnv <- new.env()

# TODO: consider what to do with streams
# TODO: what should we do with potential `db('shard1', 'insert into query')
# TODO: introduce sth like `db(list(shard1=sql1, shard2=sql2))` that will be run in parallel

#' Disconnect all open Database connections.
#' @export
db.disconnect <- function() {
  store <- get(.RPORT.STORE, envir=.RportRuntimeEnv)
  cons <- store[names(store)[grep(sprintf('%s::.*', .DB.CONNECTIONS), names(store))]]

  .db.disconnect <- function(con) {
    if (inherits(con, 'DBIConnection')) stop(con, 'is not a DBI connection')

    tryCatch({
      r <- dbDisconnect(con)

      if (r)
        rport.log('Connection closed successfully.')
      else
        stop('Connection failed to close.')
    }, error = function(e) {
      rport.log('Error closing database connection', con, geterrmessage())
    })
  }

  lapply(cons, db.disconnect)
}

#' Read from a Database (currently only PostgreSQL) connection.
#'
#' @param con.names a vector of connection names as defined in config/database.yml. If more than one connection names is
#' given then the same query is performed on all connections in parallel. This is particularly useful for analytical
#' queries on sharded setup. For example:
#'
#'   shards <- paste('shard', 1:16, sep='')
#'   db(shards, 'select count(*) from events'))
#'
#' will run in parallel on all 16 shards.
#'
#' @export
#'
db <- function(con.names, sql, cores=4) {
  if (length(con.names) > 1) {
    res <- list()

    cl <- makeCluster(min(cores, length(con.names)), outfile="")
    tryCatch({
      clusterEvalQ(cl, library(rport, quietly=TRUE))

      res <- parLapply(cl, con.names, db, sql)
    }, finally=stopCluster(cl))

    return(rbindlist(res))
  }

  stopifnot(grepl(.QUERY.VALIDATION, sql, ignore.case=TRUE))

  .db.query(con.names[1], sql)
}

#' Get connection by name from config.
#' @export
db.connection <- function(con.name) {
  .get(c(.DB.CONNECTIONS, con.name), setter=.db.connect, con.name)
}

### private functions

.db.query <- function(con.name, sql) {
  con <- db.connection(con.name)

  rport.log('Executing:', substr(sql, 1, 100), 'on', con.name)

  data.table(dbGetQuery(con, sql))
}

.db.connect <- function(con.name) {
  conninfo <- .get(c(.DB.CONFIG, con.name), setter=.read.yml.config)[[con.name]]

  if (is.null(conninfo))
    stop(sprintf('Database connection name %s not defined in config/database.yml', con.name))

  driver <- .get(.DB.DRIVER, setter=dbDriver, "PostgreSQL", max.con=32)

  .dbConnect(drv=driver, application_name=conninfo$application_name,
                  dbname=conninfo$database, user=conninfo$user,
                  password=conninfo$password, port=conninfo$port,
                  host=conninfo$host)
}

.read.yml.config <- function(root=.rport.root, path=NULL) {
  if (is.null(path)) {
    if (Sys.getenv('RPORT_CONFIG_PATH') != '')
      db.config.file <- Sys.getenv('RPORT_CONFIG_PATH')
    else
      db.config.file <- file.path(root(), 'config', 'database.yml')
  }

  if (!file.exists(db.config.file))
    stop('No configuration found here:', db.config.file, '\n',
              'Perhaps you are on the wrong directory.')

  db.config <- yaml.load_file(db.config.file)

  if (is.null(names(db.config)))
    stop('No valid database connections defined in:', db.config.file)

  db.config
}

# A wrapper around dbConnect()
# See https://github.com/rstats-db/RPostgres/issues/75 for a better solution
.dbConnect <- function(drv, application_name, ...) {
  old <- Sys.getenv("PGAPPNAME")
  Sys.setenv(PGAPPNAME=application_name)
  conn <- dbConnect(drv, ...)
  Sys.setenv(PGAPPNAME=old)
  conn
}

# TODO: fix the logic here!

#' The structure of the store variable living in .RportRuntimeEnv is like this:
#'
#' rport.store <- list(
#'   db.connections::shard1="PgConnection",
#'   db.config=list(shard1=list(dbname=shard1), shard2=list(dbname=shard2)),
#'   db.driver="DbDriver",
#' )
.get <- function(keys, setter=NULL, ...) {
  if (! exists(.RPORT.STORE, envir=.RportRuntimeEnv))
    assign(.RPORT.STORE, list(), envir=.RportRuntimeEnv)

  store <- get(.RPORT.STORE, envir=.RportRuntimeEnv)
  obj <- store[[.env.key(keys)]]

  if (!is.null(obj)) return(obj)

  if (is.null(setter)) return(NULL)

  obj <- setter(...)
  .set(keys, obj)
  obj
}

.set <- function(keys, value) {
  store <- get(.RPORT.STORE, envir=.RportRuntimeEnv)
  store[[.env.key(keys)]] = value
  assign(.RPORT.STORE, store, envir=.RportRuntimeEnv)
}

.env.key <- function(keys) {
  paste(keys, collapse='::')
}

.current.timestamp <- function(offset=0) {
  as.numeric(Sys.time()) + offset
}

.rport.root <- function() {
  getwd()
}
