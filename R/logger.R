#' Formats logging output.
#' @export
#'
rport.log <- function(...) {
  cat(Sys.time(), '--', Sys.getpid(), ..., "\n")
}
