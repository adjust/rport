\name{runr.start}
\alias{runr.start}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
%%  ~~function to do ... ~~
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
runr.start(envir = "apptrace")
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{envir}{
%%     ~~Describe \code{envir} here~~
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
function (envir = "apptrace") 
{
    runr.cat()
    runr.cat("Hello")
    if (envir == "apptrace") {
        assign("read.con", dbConnect("PostgreSQL", dbname = read.db, 
            user = read.usr, host = read.host), envir = .GlobalEnv)
        assign("write.con", dbConnect("PostgreSQL", dbname = write.db, 
            user = write.usr, host = write.host), envir = .GlobalEnv)
        runr.cat("Reading from", read.host, read.db, ";", "Writing to", 
            write.host, write.db)
    }
    else if (envir == "adjust") {
        assign("read.con", dbConnect("PostgreSQL", dbname = read.db.adjust, 
            user = read.usr.adjust, host = read.host.adjust), 
            envir = .GlobalEnv)
        assign("write.con", dbConnect("PostgreSQL", dbname = write.db, 
            user = write.usr, host = write.host), envir = .GlobalEnv)
        runr.cat("Reading from", read.host, read.db, ";", "Writing to", 
            write.host, write.db)
    }
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
