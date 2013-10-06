#' Check if the given string is the current runtime environment of Rport.
#' Useful to execute code conditional on runtime environment, e.g. only
#' development or only production.
#'
#' @param env string the name of the environment to compare
#' @return TRUE/FALSE
#' @export
#'
rport.environment.is <- function(env) {
  rport.environment() == env
}

#' Return the name of Rport runtime environment.
#'
#' @return string name of environment
#' @export
#'
rport.environment <- function() {
  get('rport.environment', envir=.RportRuntimeEnv)
}

rport.environment.set <- function(env) {
  assign('rport.environment', env, envir=.RportRuntimeEnv)
}
