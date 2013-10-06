\name{rport.db.cache.save}
\alias{rport.db.cache.save}
\title{Upsert an entry in the .Rportcache file with a hash(query)}
\usage{
  rport.db.cache.save(query, conn, dat)
}
\arguments{
  \item{query}{sql query string}

  \item{conn}{string connection name}

  \item{dat}{data.table with the results to save.}
}
\description{
  Upsert an entry in the .Rportcache file with a
  hash(query)
}

