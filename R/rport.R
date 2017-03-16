.DB.CONFIG      <- 'db.config'
.DB.CONNECTIONS <- 'db.connections'
.QUERY.CACHE    <- 'query.cache'
.RPORT.STORE    <- 'rport.store'
.DB.DRIVER      <- 'db.driver'

#' @export
.RportRuntimeEnv <- new.env()

# TODO: consider what to do with streams
# TODO: what should we do with potential `db('shard1', 'insert into query')
# TODO: introduce sth like `db(list(shard1=sql1, shard2=sql2))` that will be run in parallel
# TODO: we should respect the config option query_cache_ttl

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

#' Read from a Database (currently only PostgreSQL) connection. Results could be cached in memory as objects of the
#' following format:
#'
#'    list(timestamp=1489509849, ttl=10, object=data.table())
#'
#' `timestamp` is the UNIX timestamp when the object got created.
#' `ttl` is the time-to-live for that cached object.
#' `object` is the result from the query itself.
#'
#' @param con.names a vector of connection names as defined in config/database.yml. If more than one connection names is
#' given then the same query is performed on all connections in parallel. This is particularly useful for analytical
#' queries on sharded setup. For example:
#'
#'   shards <- paste('shard', 1:16, sep='')
#'   db(shards, 'select count(*) from events'))
#'
#' will run in parallel on all 16 shards.
#' @param max.cache.age Control cache access before or after reading from the database.
#' max.cache.age controls if memory cache should be looked-up before reading from the database. If
#' max.cache.age > 0, then cached objects are only read if they were cached less than max.cache.age seconds ago (and
#' the cached TTL option does not conflict). If max.cache.age = 0 cached objects are effectively ignored and a new
#' query gets made. If max.cache.age < 0, cached objects are looked up indifferent to when they were cached (but the
#' cached objects TTL setting is still considered).
#'
#' @param cache.ttl Control the TTL setting of an object was just read from the database would be added to the cache. TTL is
#' an integer and interpreted as seconds. Setting cache.ttl = 0 will result in the query not being cached.
#' cache.ttl < 0 is not enabled for now as it would mean cache indefinitely, which we currently don't want. Default
#' value is 300 seconds.
#'
#' @export
#'
db <- function(con.names, sql, max.cache.age=-1, cache.ttl=300) {
  if (length(con.names) > 1) {
    res <- list()

    cl <- makeCluster(min(4, length(con.names)), outfile="")
    tryCatch({
      clusterEvalQ(cl, library(rport, quietly=TRUE))

      res <- parLapply(cl, con.names, db, sql, max.cache.age=max.cache.age, cache.ttl=cache.ttl)
    }, finally=stopCluster(cl))

    return(rbindlist(res))
  }

  if (is.null(max.cache.age))
    stop('max.cache.age cannot be NULL.')

  if (is.null(cache.ttl) || cache.ttl < 0)
    stop('cache.ttl cannot be NULL or negative.')

  cached <- .get(c(.QUERY.CACHE, .cache.key(con.name=con.names[1], sql=sql)))

  if (.cache.eligible(cached, max.cache.age, cache.ttl))
    cached$object
  else
    .db.query(con.names[1], sql, cache.ttl=cache.ttl)
}

### private functions

.cache.eligible <- function(cached, max.cache.age, new.ttl, .timestamp=.current.timestamp) {
  if (is.null(cached) || cached$ttl != new.ttl) return(FALSE)

  ttl.eligible <- .timestamp() <= cached$timestamp + cached$ttl

  if (max.cache.age < 0)
    ttl.eligible
  else
    ttl.eligible && cached$timestamp >= .timestamp(-max.cache.age)
}

.db.query <- function(con.name, sql, cache.ttl) {
  con <- .get(c(.DB.CONNECTIONS, con.name), setter=.db.connect, con.name)

  rport.log('Executing:', substr(sql, 1, 100), 'on', con.name)

  res <- data.table(dbGetQuery(con, sql))

  if (cache.ttl > 0) {
    cached <- list(timestamp=.current.timestamp(), ttl=cache.ttl, object=res)
    .set(c(.QUERY.CACHE, .cache.key(con.name, sql)), cached)
    rport.log('Cached:', substr(sql, 1, 100), 'with TTL', cache.ttl, 'sec.')
  } else {
    .set(c(.QUERY.CACHE, .cache.key(con.name, sql)), NULL)
    rport.log('Done:', substr(sql, 1, 100), 'on', con)
  }

  res
}

.db.connect <- function(con.name) {
  conninfo <- .get(c(.DB.CONFIG, con.name), setter=.read.db.config)[[con.name]]

  if (is.null(conninfo))
    stop(sprintf('Database connection name %s not defined in config/database.yml', con.name))

  driver <- .get(.DB.DRIVER, setter=dbDriver, "PostgreSQL", max.con=32)

  .dbConnect(drv=driver, application_name=conninfo$application_name,
                  dbname=conninfo$database, user=conninfo$user,
                  password=conninfo$password, port=conninfo$port,
                  host=conninfo$host)
}

.read.db.config <- function(root=.rport.root, path=NULL) {
  if (is.null(path)) {
    if (Sys.getenv('RPORT_CONFIG_PATH') != '')
      path <- Sys.getenv('RPORT_CONFIG_PATH')
    else
      path <- file.path('config', 'database.yml')
  }
  db.config.file <- file.path(root(), path)

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
#'   query.cache::43114d8625425a83621ef6cb20b38918bfd512a2=list(timestamp=1489509849, ttl=10, object=data.table(installs=123)),
#'   query.cache::231rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr12a2=list(timestamp=1489509812, ttl=10, object=data.table(sessions=1))
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

.cache.key <- function(con.name, sql) {
  digest::sha1(c(con.name, tolower(sql)))
}

.current.timestamp <- function(offset=0) {
  as.numeric(Sys.time()) + offset
}

.rport.root <- function() {
  getwd()
}
