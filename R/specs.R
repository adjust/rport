#' Runs the specs of an app found in the app's spec/ folder.
#' You can use this function to run the specs from an interactive R session.
#' This is what is used by the specs/all executable.
#'
#' @param root.dir the path of the app
#'
#' @export
#'
rport.specs.all <- function(root.dir=getwd()) {
  path  <- file.path(root.dir, 'spec')
  files <- list.files(path, pattern='\\.[rR]', recursive=TRUE, full.names=TRUE)

  if (length(files) > 0) {
    sapply(files, test_file)
  } else {
    cat('No tests found in', path, '\n')
  }
}
