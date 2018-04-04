#

* update README
* allow dynamic connections to be created

- improve working with multible databases.
  - connect lazy
  - don't connect all connections at the same time because we'll have to
    maintain dozens of connections most of which we dont use.
  - don't expect connections to be disconnected within the session but provide
    disconnect.db()
- introduce easy access to data in a sharded environment.
- introduce parallelism that supports execution of functions and not necessarily
  only simple SQL. The point is that our experience shows that we source data for
  reports from multiple sources that might each take time and often we work with
  helpers or enable no-sql. The point is that we have

---
side aspects:
- Simplified syntax and functionality
- Bring travis integration
- code fixes

## Disclaimer

This project is still under development; CRAN release pending.

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

For our needs we built such a framework and this article presents it. We named
it Rport and it's open-sourced as an R extension.

## Quick Start

Rport is distributed as an R package and you can get the most up-to-date version
from GitHub, directly from within an R session:

    > library(devtools); install_github('rport', 'adeven')

Then if you want to set up a fresh Rport app do:

    > library(rport)

    > rport.app.new('BI kingdom', root.dir='~/my_apps/')
    # help(rport.app.new) for full list of options

This will create the file structure of a clean Rport app. Next you'll probably
want to start setting up different projects for this and that in your new Rport
app. To do this:

    > rport.project.new('weekly kpi report', root.dir='~/my_apps/bi_kingdom')
    # again help(rport.project.new) for more

Now you've bootstrapped your first Rport app with one project in it for
reporting Weekly KPIs. The generators created some code for you already so you
can already see some output by going:

    $ cd ~/my_apps/bi_kingdom $ ./bin/weekly_kpi_report.R

Go ahead and browse those generated files, they're well commented and you will
find some next steps there too.

Finally, note that Rport generated some dummy `spec` files for you that you can
already run:

    $ ./spec/all

from your shell and see your new tests outputting:

    Specs for weekly_kpi_report : .

    /Users/nikola/rport_app/spec/weekly_kpi_report/main_spec.R
    file    "main_spec.R"
    context "Specs for weekly_kpi_report"
    test    "Make sure you add proper tests here"
    nb      1
    failed  0
    error   FALSE
    user    0.003
    system  0
    real    0.003

Make sure you edit the relevant files in `spec` folder to write real tests for
your projects.

## Rport Apps

Now that you've set up an Rport app, let's take a more detailed look at it. An
Rport app would likely contain multiple projects, often serving different
purposes.  You might have:

* Cron jobs for analytics, reports, calculation and other tasks.
* A lot of one-off exploration scripts
* Asynchronous processing of tasks from web apps
* Standalone web services
* Others

An Rport app with two projects might have the following folder structure:

    ├── README.md
    ├── bin
    │   ├── monthly_aggregates.R
    │   └── weekly_kpis_report.R
    ├── config
    │   ├── database.yml
    │   └── settings.R
    ├── doc
    │   ├── monthly_aggregates.md
    │   └── weekly_kpis_report.md
    ├── lib
    │   ├── functions
    │   │   ├── monthly_aggregates
    │   │   │   └── main.R
    │   │   └── weekly_kpis_report
    │   │       └── main.R
    │   └── opts
    │   │   ├── monthly_aggregates.R
    │   │   └── weekly_kpis_report.R
    │   └── shared
    ├── log
    ├── script
    └── spec
        ├── all
        ├── monthly_aggregates
        │   └── main_spec.R
        └── weekly_kpi_report
            └── main_spec.R

For an illustration of Rport's features we created a [Demo Rport
App][sample_app].  Make sure you refer to it along with reading this post.

## Rport Features

Rport will take care of tedious background tasks, while you can focus on the
actual explorations and analytics of your data. Let's introduce the core
features of the package below.

### Database Connectivity

If you're directly interfacing R's SQL drivers, you'll likely find yourself
often using the `dbGetQuery(connection, query)` routine, meaning that you need
to carry your connection object around every time you issue a database query.

#### Multiple Connections Handling

Using Rport in the scenario above, you'll define all your connections in a
`config/database.yml` file, similarly to what you'd do in other frameworks (e.g.
Rails). The difference here is that with Rport you can not only define multiple
environments, but also multiple connections within each environment.

    # bootstrap production environment rport('production')

    # use the handy accessor method for the `read` connection, generated by
    Rport dat <- rport.read('select me from you')

    # access another database and get more data:
    old.dat <- rport.backup('select me from old_you')

    # `dat` and `old.dat` are now `data.table` objects with results from the
    # `production->read` and `production->backup` connections respectively

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

#### Database Query Caching

The configuration in `config/database.yml` supports a `query_cache_ttl` config
in seconds, which sets the time before a query is repeated to a database
connection.

This feature is meant to facilitate interactive data exploration, in which the
same query might be run from a script multiple times within a short time frame.
Particularly when the query takes long to execute, setting `query_cache_ttl:
300` will not repeat the same query to a database connection unless 5 minutes
have passed since the last run.

The following snippet exemplifies that:

```R
library(rport)

# This will take a long time, so we wait.
dat <- db('shard1', 'select count(*) from events')
dat <- NULL

# This will now read and return the result from the Rport cache.
dat <- db('shard1', 'select count(*) from events')
```

To disable caching either set `query_cache_ttl: 0` in the config or pass
`query_cache_ttl=0` to the `rport::db()` function call.

### Parallel report compilation

Since R 2.15 the `parallel` package is part of R Core. Rport provides some
wrappers around that package to address specific use cases.

For example a newsletter or report will likely be constituted of several
independent items that could probably be generated independently to gain
performance.

    rport('production')

    rport.bootstrap('parallel', cluster.size=8)

    users.stats <- function(opts) {
      sql <- ' SELECT count(*) FROM users WHERE created_at >= %s'

      rport.apptrace(sprintf(sql, opts$start_date))
    }

    products.stats <- function(opts) {
      sql <- ' SELECT count(*) FROM products WHERE created_at >= %s'

      rport.apptrace(sprintf(sql, opts$start_date))
    }

    # run the components in parallel
    result = rport.parallel (
      useres   = { users.stats, opts },
      products = { products.stats, opts }
    )

    # result is now a list with the results like:
    # list (users=data.table(..), products=data.table(..))

### Working with Executables

Executables are a common interface to our Rport apps. We use them to schedule
cron jobs (e.g. reports generation, aggregations, etc.) or to run other
analytics tasks. Rport uses Rscript for creation of cross-platform executables.

The `rport.project.new()` initializer already created a file in the `bin/`
folder for you. Rport will also automatically load all R files relevant to your
project.

#### CLI options

Rport manages CLI options using the R standard lib `optparse` package and the
convention of placing opts files under `lib/opts/my_script_name.R`. Check what
`rport.project.new()` generated for you above or the [sample app][sample_app]
for an illustration.

#### Logging

Rport writes a lot about what it's doing either interactively or in log files.
You can use these logs to get an idea about query and script execution times as
well as debugging.

The convention for executables is that all output is `sink`ed (including output
from parallel workers) to `log/my_script_name.log`.

## Summary

Rport is an ambitious project under ongoing development. Be sure to follow the
[GitHub repository][rport] for all updates.

## See more

Read the [blog post][blog_post] for more of the features.

## License

This Software is licensed under the MIT License.

Copyright (c) 2012 adeven GmbH, http://www.adeven.com

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[rport]: http://github.com/adeven/rport "Rport Home"
[sample_app]: http://github.com/adeven/rport_demo "A Sample Rport App"
[data_table]: http://cran.r-project.org/web/packages/data.table/index.html "The Data Table R Package"
[adjust]: http://adjust.io "Adjust"
[apptrace]: http://apptrace.com "Apptrace"
[blog_post]: http://big-elephants.com/2013-10/rport-business-intelligence-apps-with-r/ "Rport Blog Post"
