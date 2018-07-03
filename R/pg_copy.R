#' A lightweight wrapper around postgresqlCopyInDataframe that allows for
#' custom field lists and temporary tables. It only allows numeric, character,
#' integer, date/time and bool types. It's more useful than dbWriteTable because
#' it allows SQL-copying into tables that have fields other than the data.frame.
#' Also using pg.copy you can SQL-copy in transactions with temp tables.
#'
#' @param con PostgreSQLConnection
#' @param tbl.name character
#' @param tbl.name PostgreSQLConnection
#'
#' @export
pg.copy <- function(con, tbl.name, DT) {
  stopifnot(inherits(con, 'PostgreSQLConnection'))
  stopifnot(inherits(tbl.name, 'character'))
  stopifnot(inherits(DT, 'data.frame'))

  .allowedDataTypes <- c('numeric', 'character', 'integer', 'POSIXt', 'POSIXct', 'logical', 'Date')
  if (length(setdiff(unique(unlist(lapply(DT, class))), .allowedDataTypes)) > 0) {
    stop('Allowed data types are', paste(.allowedDataTypes, collapse=','))
  }

  # convert columns we can't handle in C code
  DT[] <- lapply(DT, function(z) {
    if (is.object(z) && !is.factor(z)) as.character(z) else z
  })

  sql <- paste("COPY", postgresqlTableRef(tbl.name), "(", paste(postgresqlQuoteId(names(DT)), collapse=","), ") FROM STDIN")

  # This returns false for non-select statements, we ignore the return value
  postgresqlpqExec(con, sql)

  postgresqlCopyInDataframe(con, DT)
  rs <- postgresqlgetResult(con)

  if (inherits(rs, RPostgreSQL:::ErrorClass)) stop("Error performing SQL copy")

  dbClearResult(rs)
}
