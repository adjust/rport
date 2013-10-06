\name{rport.db.connect}
\alias{rport.db.connect}
\title{Establishes all database connections in given configuration. Connections are
defined in config/database.yml. Also creates helper methods for accessing
these connections that are stored in .GlobalEnv.}
\usage{
  rport.db.connect(connections)
}
\arguments{
  \item{connections}{list like

  cons <- list ( read = list(db=my_slave,
  user=my_slave_user) )}
}
\description{
  Establishes all database connections in given
  configuration. Connections are defined in
  config/database.yml. Also creates helper methods for
  accessing these connections that are stored in
  .GlobalEnv.
}

