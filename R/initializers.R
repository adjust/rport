#' Creates an empty folder structure and file templates for an Rport app. If
#' directory `root/name` exists, stops with an error.
#'
#' @param name name of the app
#' @param name of the project
#'
#' @export
#'
rport.app.new <- function(app.name, root.dir=getwd()) {
  app.name.fs <- tolower(gsub('\\s+', '_', app.name))

  app.root.dir <- file.path(root.dir, app.name.fs)
  if (file.exists(app.root.dir)) {
    msg <- 'Can\'t create Rport app, because directory %s already exists.'
    stop(sprintf(msg, app.root.dir))
  }

  # Create dir structure
  dir.create(app.root.dir, recursive=TRUE)

  dirs <- c('bin',
            'config',
            'doc',
            'lib',
            file.path('lib', 'opts'),
            file.path('lib', 'projects'),
            file.path('lib', 'shared'),
            'log',
            'script',
            'spec')
  sapply(dirs, function(d) { dir.create(file.path(app.root.dir, d)) })

  # What variables will be available for `brew` template interpolation
  env <- new.env()
  assign('app.name', app.name, envir=env)

  # Copy necessary templates
  src.dir <- file.path(system.file(package='rport'), 'templates', 'app')

  src    <- file.path(src.dir, 'README.md.brew')
  target <- file.path(app.root.dir, 'README.md')
  rport.copy.template(src, target, env)

  src    <- file.path(src.dir, 'database.yml.brew')
  target <- file.path(app.root.dir, 'config', 'database.yml')
  rport.copy.template(src, target, env)

  src    <- file.path(src.dir, 'settings.R.brew')
  target <- file.path(app.root.dir, 'config', 'settings.R')
  rport.copy.template(src, target, env)

  src    <- file.path(src.dir, 'all.brew')
  target <- file.path(app.root.dir, 'spec', 'all')
  rport.copy.template(src, target, env)
  Sys.chmod(target, '777')
}

#' Creates a new project with templates.
#'
#' @param name name of the app
#' @param  name of the project
#'
#' @export
#'
rport.project.new <- function(project.name, root.dir=getwd()) {
  if (! rport.is.root.dir(root.dir))
    stop(sprintf('%s doesn\'t seem to be the root of an Rport app.', root.dir))

  # Santitize project name. So far only replaces whitespaces.
  project.name.fs <- tolower(gsub('\\s+', '_', project.name))
  project.name.r  <- tolower(gsub('(\\s+|-+)', '.', project.name))

  # what variables will be available for `brew` template interpolation
  env <- new.env()
  assign('project.name.fs', project.name.fs, envir=env)
  assign('project.name.r', project.name.r, envir=env)
  assign('project.name', project.name, envir=env)

  src.dir <- file.path(system.file(package='rport'), 'templates', 'project')

  src    <- file.path(src.dir, 'README.md.brew')
  target <- file.path(root.dir, 'doc', sprintf('%s.md', project.name.fs))
  rport.copy.template(src, target, env)

  src    <- file.path(src.dir, 'executable.R.brew')
  target <- file.path(root.dir, 'bin', sprintf('%s.R', project.name.fs))
  rport.copy.template(src, target, env)
  Sys.chmod(target, '777')

  src    <- file.path(src.dir, 'opts.R.brew')
  target <- file.path(root.dir, 'lib', 'opts', sprintf('%s.R', project.name.fs))
  rport.copy.template(src, target, env)

  code.dir.name <- file.path(root.dir, 'lib', 'projects', project.name.fs)
  if (! file.exists(code.dir.name))
    dir.create(code.dir.name)

  src    <- file.path(src.dir, 'main.R.brew')
  target <- file.path(root.dir, 'lib', 'projects', project.name.fs, 'main.R')
  rport.copy.template(src, target, env)

  spec.dir.name <- file.path(root.dir, 'spec', project.name.fs)
  if (! file.exists(spec.dir.name))
    dir.create(spec.dir.name)

  src    <- file.path(src.dir, 'spec.R.brew')
  target <- file.path(root.dir, 'spec', project.name.fs, 'main_spec.R')
  rport.copy.template(src, target, env)

}

#' Is the given path a root directory of an Rport app
#'
#' @param path character
#' @return TRUE/FALSE
#'
rport.is.root.dir <- function(path) {
  if (! is.character(path))
    stop('Argument path needs to be given and be character')

  files <- file.path(path, c(
    'bin',
    file.path('lib', 'projects'),
    file.path('lib', 'opts'),
    file.path('config', 'database.yml'),
    file.path('config', 'settings.R')
  ))

  all(file.exists(files))
}

rport.copy.template <- function(src, target, envir) {
  if (! file.exists(target)) {
    brew::brew(
      file   = src,
      output = target,
      envir  = envir
    )
    cat('Created file:', target, '\n')
  } else {
    cat('File already existed, nothing done:', target, '\n')
  }
}
