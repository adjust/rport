\name{rport.db.cache.get}
\alias{rport.db.cache.get}
\title{Look up for an entry in the .Rportcache file and load the respective file with
.Rportcache extension to the global environment.}
\usage{
  rport.db.cache.get(query, conn)
}
\arguments{
  \item{query}{sql query string}

  \item{conn}{string connection name}
}
\value{
  nil if nothing found or results data.table with the
  loaded cache
}
\description{
  Look up for an entry in the .Rportcache file and load the
  respective file with .Rportcache extension to the global
  environment.
}

