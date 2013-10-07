#' Bootstraps specific feature of an Rport app. Loads dependencies and sets up.
#'
#' @param arg what should we bootstrap: 'executable', 'mailing', 'parallel'
#'
#' @export
#'
rport.bootstrap <- function(arg, ...) {
  switch (arg,
          executable = rport.bootstrap.executable(...),
          mailing    = rport.bootstrap.mailing(...),
          parallel   = rport.bootstrap.parallel(...),
          stop(sprintf('No bootstrapper found for %s', arg))
         )
}

#' Source all files in `lib/projects/my_project/*.R` and `lib/opts/*.R`
#'
#' @param shared should the .r or .R files from `lib/shared` be sourced.
#' @param opts should the .r or .R files from `lib/shared` be sourced.
#'
rport.bootstrap.executable <- function(project, shared=TRUE, opts=TRUE) {

  load.all <- function(path, pattern="[.][rR]")
    for (f in list.files(path, pattern)) source(file.path(path, f))

  if (opts)
    load.all(file.path('lib', 'opts'), pattern=sprintf("%s.[rR]", project))

  if (shared)
    load.all(file.path('lib', 'shared'))

  load.all(file.path('lib', 'projects', project))
}
