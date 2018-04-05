.DB.CONFIG       <- 'db.config'
.DATABASE.YML    <- 'database.yml'
.DB.CONNECTIONS  <- 'db.connections'
.RPORT.STORE     <- 'rport.store'
.DB.DRIVER       <- 'db.driver'
.RPORT.DB.CONFIG <- 'RPORT_DB_CONFIG'
.RPORT.MAX.CON   <- 'RPORT_MAX_CON'

.DEFAULT.MAX.CON <- 32

#' The structure of the store variable living in .RportRuntimeEnv is like this:
#'
#' rport.store <- list(
#'   db.connections::shard1="PgConnection",
#'   db.connections::shard2="PgConnection",
#'   ...
#'   db.config=list(shard1=list(dbname=shard1), shard2=list(dbname=shard2)),
#'   db.driver="DbDriver",
#' )
#'
#' @export
.RportRuntimeEnv <- new.env()
assign(.RPORT.STORE, list(), envir=.RportRuntimeEnv)

#' @export
list.connections <- function() {
  store <- get(.RPORT.STORE, envir=.RportRuntimeEnv)

  Filter(function(x) inherits(x, 'DBIConnection'), store)
}

#' Get the DBIConnection connection object by config name. Connection names are
#' either defined in database.yml or added at runtime. If connection
#' configuration exists, but the DB connection has not yet been established,
#' calling this function will also try to connect to the database.
#' @export
db.connection <- function(con.name) {
  .get(c(.DB.CONNECTIONS, con.name), setter=.db.connect, con.name)
}

#' Disconnect database connections. If `con.name` is not NA, then a connection
#' is closed by the given name. Otherwise all open database connections are
#' closed.
#'
#' @export
db.disconnect <- function(con.name=NA) {
  .db.disconnect <- function(con) {
    if (!inherits(con, 'DBIConnection')) stop('Attempted to close object of class ', class(con), ', which is not a DBI connection')

    tryCatch({
      if (!dbDisconnect(con)) stop('Connection failed to close.')

      .rport.log('Connection closed successfully.')
    }, error = function(e) {
      .rport.log('Error closing database connection', con, geterrmessage())
    })
  }

  if (!is.na(con.name)) {
    con <- list.connections()[[.build.key(c(.DB.CONNECTIONS, con.name))]]
    if (is.null(con)) stop('No DBI connection by name: ', con.name, ' has been open.')
    .db.disconnect(con)
    .set(c(.DB.CONNECTIONS, con.name), NULL)
    return
  }

  lapply(list.connections(), .db.disconnect)
  assign(.RPORT.STORE, list(), envir=.RportRuntimeEnv)
}

#' Read from a Database (currently only PostgreSQL) connection.
#'
#' @param con.names a vector of connection names as defined in database.yml (or
#' using custom connection definitions).
#'
#' `db` parallelizes if multiple connections or queries are given. If more than one connection names is
#' given then the same query is performed on all connections in parallel. This
#' is particularly useful for analytical queries on sharded setup. For example:
#'
#'   shards <- paste('shard', 1:16, sep='')
#'   db(shards, 'select count(*) from events'))
#'
#' will run in parallel on all 16 shards.
#'
#' If more than one SQL queries is given, then each of them are run in parallel on the
#' single DB connection. If the same length of connections and the same length
#' of SQL queries is given, they are parallelized in pairs. See
#' https://github.com/adjust/rport/ for examples.
#'
#' @param cores determines the size of the parallel cluster for parallel
#' queries.
#'
#' @param params binds SQL parameters to the SQL query using parameter binding.
#' The PostgreSQL R driver takes care for the quoting. Parameter binding is very
#' important against SQL injection. For example, to get id=123:
#'
#'   db(shards, 'select count(*) from events where id = $1', 123)
#'
#' @export
db <- function(con.names, sql, params=c(), cores=4) {
  if (length(con.names) == 1 & length(sql) == 1) {
    return(.db.query(con.names[1], sql, params))
  }

  if (length(con.names) == 1 & length(sql) > 1) {
    return(.parallelize.queries(con.names, sql, params, cores))
  }

  if (length(con.names) > 1 & length(sql) == 1) {
    return(.parallelize.connections(con.names, sql, params, cores))
  }

  if (length(con.names) == length(sql)) {
    return(.parallelize.index(con.names, sql, params, cores))
  }

  stop('con.names and sql have incompatible lengths')
}

#' This function lets users define DB connection settings from sources other
#' than the database.yml config. This is useful for DB setups where a master
#' node maintains a dynamic list of DB nodes. This function only lets you define
#' the connection settings. The actual connection will be open by a subsequent
#' `db('my-custom-con1', 'select 1') call.
#'
#' This function doesn't check or validate the input, the caller is responsible
#' for making sure that the list has the correct format, otherwise the
#' connection (i.e. the `db` call) would fail.
#'
#' @param db.config is a list of format:
#'   list(
#'     my-custom-con1=list(
#'       database='db1',
#'       username='analytics',
#'       password='',
#'       host='db-1',
#'       port=5432,
#'       application_name='rport'
#'     ),
#'     my-custom-con2=list(
#'       database='db2',
#'       username='analytics',
#'       password='',
#'       host='db-2',
#'       port=5432,
#'       application_name='rport'
#'     )
#'  )
#'
#' @export
register.connection.settings <- function(db.config) {
  names(db.config) <- sprintf('%s::%s', .DB.CONFIG, names(db.config))
  assign(.RPORT.STORE, c(get(.RPORT.STORE, envir=.RportRuntimeEnv), db.config), envir=.RportRuntimeEnv)
}

#' Rport stores database configuration settings by default in `config/database.yml` (or the
#' file given in the value of environment variable RPORT_DB_CONFIG). Once a
#' database connection is read from the config, it doesn't get read again. This
#' function lets the user reload the YAML config. It's useful when the config is
#' changed during an ongoing R session.
#'
#' @export
reload.db.config <- function() {
  .read.yml.config()
}

### Private functions

.parallelize.index <- function(con.names, sql, params, cores) {
  res <- list()

  cl <- makeCluster(min(cores, length(sql)), outfile="")
  tryCatch({
    clusterEvalQ(cl, library(rport, quietly=TRUE))

    res <- parLapply(cl, 1:length(sql), function(index) {
      db(con.names[index], sql[index], params)
    })
  }, finally=stopCluster(cl))

  rbindlist(res)
}

.parallelize.queries <- function(con.name, sql, params, cores) {
  res <- list()

  cl <- makeCluster(min(cores, length(sql)), outfile="")
  tryCatch({
    clusterEvalQ(cl, library(rport, quietly=TRUE))

    res <- parLapply(cl, 1:length(sql), function(index) {
      db(con.name, sql[index], params)
    })
  }, finally=stopCluster(cl))

  rbindlist(res)
}

.parallelize.connections <- function(con.names, sql, params, cores) {
  res <- list()

  cl <- makeCluster(min(cores, length(con.names)), outfile="")
  tryCatch({
    clusterEvalQ(cl, library(rport, quietly=TRUE))

    res <- parLapply(cl, con.names, db, sql, params)
  }, finally=stopCluster(cl))

  rbindlist(res)
}

.db.query <- function(con.name, sql, ...) {
  # We need to make sure that db() doesn't open more connections than the driver
  # supports. Potentially here we could be smarter and instead of disconnecting
  # _all_ connections, we can maintain some kind of usage ranking.
  if (dbGetInfo(.get.driver())$num_con == .max.con()) {
    .rport.log('Max DB connections limit by the R driver hit, reconnecting.')
    db.disconnect()
  }

  con <- db.connection(con.name)

  .rport.log('Executing:', substr(sql, 1, 100), 'on', con.name)
  res <- data.table(dbGetQuery(con, sql, ...))
  .rport.log('Done:', con.name)

  res
}

.db.connect <- function(con.name) {
  if (!exists(.DATABASE.YML, envir=.RportRuntimeEnv)) reload.db.config()

  conninfo <- .get(c(.DB.CONFIG, con.name))

  if (is.null(conninfo))
    stop(sprintf('Database connection name %s not defined in database.yml', con.name))

  d <- .get.driver()

  .dbConnect(drv=d, application_name=conninfo$application_name,
                  dbname=conninfo$database, user=conninfo$user,
                  password=conninfo$password, port=conninfo$port,
                  host=conninfo$host)
}

.read.yml.config <- function() {
  if (Sys.getenv(.RPORT.DB.CONFIG) != '')
    db.config.file <- Sys.getenv(.RPORT.DB.CONFIG)
  else
    db.config.file <- file.path(.rport.root(), 'config', 'database.yml')

  if (!file.exists(db.config.file))
    stop('No configuration found here:', db.config.file, '\n',
              'Perhaps you are on the wrong directory.')

  db.config <- yaml.load_file(db.config.file)
  .set(.DATABASE.YML, db.config)

  if (is.null(names(db.config)))
    stop('No valid database connections defined in:', db.config.file)

  register.connection.settings(db.config)
}

# A wrapper around dbConnect()
# See https://github.com/rstats-db/RPostgres/issues/75 for a better solution
.dbConnect <- function(drv, application_name, ...) {
  if (is.null(application_name)) return(dbConnect(drv, ...))

  old <- Sys.getenv("PGAPPNAME")
  Sys.setenv(PGAPPNAME=application_name)
  conn <- dbConnect(drv, ...)
  Sys.setenv(PGAPPNAME=old)
  conn
}

.get <- function(keys, setter=NULL, ...) {
  store <- get(.RPORT.STORE, envir=.RportRuntimeEnv)
  obj <- store[[.build.key(keys)]]

  if (!is.null(obj)) return(obj)

  if (is.null(setter)) return(NULL)

  obj <- setter(...)
  .set(keys, obj)
  obj
}

.set <- function(keys, value) {
  store <- get(.RPORT.STORE, envir=.RportRuntimeEnv)
  store[[.build.key(keys)]] = value
  assign(.RPORT.STORE, store, envir=.RportRuntimeEnv)
}

.build.key <- function(keys) {
  paste(keys, collapse='::')
}

.rport.root <- function() {
  getwd()
}

.rport.log <- function(...) {
  cat(as.character(Sys.time()), '--', Sys.getpid(), ..., "\n")
}

.get.driver <- function() {
  .get(.DB.DRIVER, setter=dbDriver, "PostgreSQL", max.con=.max.con())
}

.max.con <- function() {
  if (Sys.getenv(.RPORT.MAX.CON) != '')
    as.numeric(Sys.getenv(.RPORT.MAX.CON))
  else
    .DEFAULT.MAX.CON
}
