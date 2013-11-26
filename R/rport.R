#' @export
#'
.RportRuntimeEnv <- new.env()

#' Bootstraps your Rport project using the `env` configuration. Should be
#' placed at the beginning of each project. This is done automatically if you
#' use the project generators.
#'
#' @param env string specifying configuration settings to use.
#'
#' @export
#'
rport <- function(env) {
  db.config <- file.path(rport.root(), 'config', 'database.yml')

  if (file.exists(db.config)) {
    config <- yaml.load_file(db.config)

    if (is.null(config[[env]]))
      stop(sprintf('Environment %s is not defined in config/database.yml', env))

    assign('rport.environment', env, envir=.RportRuntimeEnv)
    rport.db.connect(config[[env]])

  } else {
    rport.log('No configuration found here:', db.config, '\n',
              'Perhaps you are on the wrong directory.')
  }
}

#' Prepares Rport for exist.
#'
#'  * closes database connections
#'
#' @param env string specifying configuration settings to use.
#'
#' @export
#'
rport.runtime.exit <- function() {
  rport.db.disconnect()
}

#' The root directory of the Rport app. For now consider this to be the working
#' directory of the R process.
rport.root <- function() {
  getwd()
}
