# To run the specs set the working dir to package root and issue:
#
#    library(testthat)
#    test_file('inst/tests/file_structure.R') # or another spec
#

library(RPostgreSQL)

files <- list.files('../../R', pattern='\\.[rR]$',
                    full.names=TRUE, recursive=TRUE)

source('../../R/bootstrappers.R', local=TRUE)
source('../../R/specs.R',         local=TRUE)
source('../../R/db.R',            local=TRUE)
source('../../R/db_cache.R',      local=TRUE)
source('../../R/environment.R',   local=TRUE)
source('../../R/initializers.R',  local=TRUE)
source('../../R/logger.R',        local=TRUE)
source('../../R/parallel.R',      local=TRUE)
source('../../R/rport.R',         local=TRUE)
