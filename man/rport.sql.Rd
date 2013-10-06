\name{rport.app.new}
\alias{rport.app.new}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  ~~function to do ... ~~
}
\description{
Generates the directory structure and file templates for a new Rport app.
}
\usage{
(query, key = NULL, cache = FALSE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{query}{
%%     ~~Describe \code{query} here~~
}
  \item{key}{
%%     ~~Describe \code{key} here~~
}
  \item{cache}{
%%     ~~Describe \code{cache} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
%%  ~~who you are~~
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
##---- Should be DIRECTLY executable !! ----
##-- ==>  Define data, use random,
##--	or do  help(data=index)  for the standard data sets.

## The function is currently defined as
function (query, key = NULL, cache = FALSE)
{
    if (exists("read.con", envir = .RportConnEnv)) {
        runr.cat("Reading:", query)
        res <- data.table(dbGetQuery(get("read.con", envir = .RportConnEnv),
            query))
        if (!is.null(key) && !is.null(res[[key]]))
            setkeyv(res, key)
        res
    }
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
