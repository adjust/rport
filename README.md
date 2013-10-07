## Disclaimer

This project is released in

Rport is an R package that greatly facilitates common tasks found in many R
Business Intelligence apps. It bridges R and SQL analytics similarly to how
Rails bridges Ruby and Web Development.

## Introduction

From our analytics work on data from [Adjust][adjust] and [Apptrace][apptrace],
we've identified several tasks needed for nearly any new R project.

* Handling multiple database connections within one R session

* Caching results from long SQL statements in development

* Parallel jobs processing

* Building UNIX executables

* Organizing the growing codebase

While R supports all these, there isn't a framework to contain the repeated code
that you'll end up with when building a multi-projects analytics app.

For our needs we built such a framework and this article presents it. We named it
Rport and it's open-sourced as an R extension.

## Quick Start

Rport is distributed as an R package and you can get the most up-to-date version
from GitHub, directly from within an R session:

    > library(devtools)
    > install_github('rport', 'adeven')

Then if you want to set up a fresh Rport app do:

    > library(rport)

    > rport.app.new('BI kingdom', root.dir='~/my_apps/')
    # help(rport.app.new) for full list of options

This will create the file structure of a clean Rport app. Next you'll probably
want to start setting up different projects for this and that in your new Rport
app. To do this:

    > rport.project.new('weekly kpi report', root.dir='~/my_apps/bi_kingdom')
    # again help(rport.project.new) for more

Now you've bootstrapped your first Rport app with one project in it for reporting
Weekly KPIs. The generators created some code for you already so you can already
see some output by going:

    $ cd ~/my_apps/bi_kingdom
    $ ./bin/weekly_kpi_report.R

Go ahead and browse those generated files, they're well commented and you will
find some next steps there too.

## Rport Apps

Now that you've set up an Rport app, let's take a more detailed look at it. An
Rport app would likely contain multiple projects, often serving different purposes.
You might have:

* Cron jobs for analytics, reports, calculation and other tasks.
* A lot of one-off exploration scripts
* Asynchronous processing of tasks from web apps
* Standalone web services
* Others

An Rport app with two projects might have the following folder structure:

    .
    ├── bin
    │   ├── apptrace_newsletter
    │   └── new_apps_report
    ├── config
    │   └── database.yml
    │   └── settings.R
    ├── doc
    ├── lib
    │   ├── functions
    │   │   ├── apptrace_newsletter
    │   │   │   └── main.R
    │   │   └── new_apps_report
    │   │       └── main.R
    │   └── opts
    │       ├── apptrace_newsletter.R
    │       └── new_apps_report.R
    ├── log
    ├── script
    └── spec

For an illustration of Rport's features we created a [Demo Rport App][sample_app].
Make sure you refer to it along with reading this post.

## Rport Features

Rport will take care of tedious background tasks, while you can focus on the
actual explorations and analytics of your data. Let's introduce the core features
of the package below.

### Database Connectivity

If you're directly interfacing R's SQL drivers, you'll likely find yourself often
using the `dbGetQuery(connection, query)` routine, meaning that you need to
carry your connection object around every time you issue a database query.

#### Multiple Connections Handling

Using Rport in the scenario above, you'll define all your connections in a
`config/database.yml` file, similarly to what you'd do in other frameworks (e.g.
Rails). The difference here is that with Rport you can not only define multiple
environments, but also multiple connections within each environment.

    {% codeblock lang:r %}

    # bootstrap production environment
    rport('production')

    # use the handy accessor method for the `read` connection, generated by Rport
    dat <- rport.read('select me from you')

    # access another database and get more data:
    old.dat <- rport.backup('select me from old_you')

    # `dat` and `old.dat` are now `data.table` objects with results from the
    # `production->read` and `production->backup` connections respectively

    {% endcodeblock %}

Few things are worth mentioning in this snippet:

* Rport created the `rport.read` and `rport.backup` methods magically based on
  the `read` and `backup` database configurations in the `config/database.yml`.
  Check out the [Example app][sample_app] to see more of this.

* You can have as many database configurations as you like and combine results
  from all of them into a single R session. We use this feature a lot when doing
  adjust.io <-> apptrace stuff or when we offload heavy reads to a replication
  server.

* Note that different configurations could also mean entirely different database
  servers. Nothing stops you from having PostgreSQL and MySQL results brought
  together in R by Rport. And you wouldn't even care about the underlying
  connection mechanics, because Rport will do that for you.

* Rport works with the [Data Table][data_table] package and all the results
  returned from database queries are `data.table` objects. If you're wondering
  why we introduced this dependency, just check out this fantastic package from
  the link above.

#### Caching Query Results

When working on scripts, you might want to load larger chunks of raw data into
memory and crunch them in R (ideally with Data Table) to produce your results.
When just 'playing' or exploring the raw data, you won't really want to wait for
an unchanged SQL query to run again when rerunning a script to test your R code.

Rport's connection accessors allow you to cache results using R's `load` and
`save` routines.

    {% codeblock lang:r %}
    rport('development')

    # Read the data in memory only if not found in the cache.
    dat <- rport.read('select app_id, rank from application_ranks', cache=TRUE)

    # do crazy crunching on `dat`
    {% endcodeblock %}

This query will now only run once and subsequent executions of the script will
read and return the cached R object from the file system.

To ensure that nothing bad ever happens to you using this caching, it only works
in development and it logs clearly when reading from cache. Furthermore, it
works on a per-connection basis, so the same queries under different connections
will be cached separately.

## See more

Read the blog post for more of the features.

[rport]: http://github.com/adeven/rport "Rport Home"
[sample_app]: http://github.com/adeven/rport_demo "A Sample Rport App"
[data_table]: http://cran.r-project.org/web/packages/data.table/index.html "The Data Table R Package"
[adjust]: http://adjust.io "Adjust"
[apptrace]: http://apptrace.com "Apptrace"
