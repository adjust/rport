# rport - Parallel Querying on Sharded PostgreSQL Clusters for Analytics in R

Querying PostgreSQL from R is typically done using the [RPostgreSQL][rpostgresql] driver (or the newer
[RPostgres][rpostgres]). However in both cases it's the responsibility of the analyst to maintain the connection objects
and pass them on every query. In analytical contexts, where data resides in multiple databases (e.g. sharded setup,
microservice setup, etc.) the task of maitaining all connection objects, quickly becomes very tedious.

Furthermore, in many partitioning and sharding data architectures, queries could be parallized and run simultaneously to
get the necessary data more efficiently. However parallelizing the querying could mean even more complexity for the analyst.

`rport` solves both of these issues by:

* allowing data scientists to maintain DB connection details outside of their analytics
codebase (e.g. in a `database.yml` config)
* providing parallelisation facility for easy SQL query-distribution

## Installation

Rport is distributed as a lightweight R package and you can get the most up-to-date version
from GitHub, directly from within an R session:

    > library(devtools); install_github('rport', 'adjust')

Next you'll have to define some PostgreSQL connection settings in YML format
by default here `config/database.yml`. See [the example
database.yml](https://github.com/adjust/rport/blob/master/tests/database.yml)
for an example.

Given that you have a connection name `db1` (and a running PostgreSQL database),
you can test by:

```r
library(rport)

db('db1', 'select 1')
```

If successful, you should see the following output:

```
> db('db1', 'select 1')
2018-04-10 17:09:04 -- 1468 Executing: select 1 on db1
2018-04-10 17:09:05 -- 1468 Done: db1
   ?column?
1:        1
```

## Usecases

Managing the PostgreSQL connectivity in an analytics environment with even a
single database can already be very beneficial. This usecase is popular and
encouraged. The full benefit of `rport` is however unlocked in multi-database
contexts.

Below are some of the usecases for `rport` which emphasize the benefits it
offers in handling DB connection objects and distributing SQL queries.

### rport on Sharded Database Cluster

Suppose we have 16 database nodes (shards), where data is distributed by some
key. Below is a sample `config/database.yml`, which we might have on our
workspace defining all connection settings.

```YML
shard1:
  database: db1
  username: postgres
  port: 5432
  application_name: rport
shard2:
  database: db2
  username: postgres
  port: 5432
  application_name: rport

...

shard16:
  database: db16
  username: postgres
  port: 5432
  application_name: rport
```

Let's say we want to run the following SQL query on every shard and combine the
results for analysis in R.

```SQL
SELECT id, name, city, sum(events) as events
FROM events
WHERE country IN ('de', 'fr', 'bg')
```

To distribute this SQL on all 16 database servers (shards), we can use the
following R code.

```r
library(rport)

sql <- "
  SELECT id, name, city, sum(events) as events
  FROM events
  WHERE country IN ('de', 'fr', 'bg')
"
# Perform intermediate (per-shard) aggregation, parallel on 4 cores by default.
events <- db(paste0('shard', 1:16), sql)

# Perform final (in-memory) aggregation on the resulting `data.table`
events <- events[, .(events=sum(events)), by='country']
```

### Multiple Queries on Single Database

One of our product's database model has data partitioned over several thousand
of PostgreSQL tables. All tables have the same schema so often we want to do
analytics on data from many these tables. See the example data model below where
each app's data is stored on its own table.

```SQL
create table app_1 (id int, title text, created_at date, installs int,...);
create table app_2 (id int, title text, created_at date, installs int,...);
...
create table app_100 (id int, title text, created_at date, installs int,...);
```

To distribute a query on all apps, using `rport` you can do:

```R
sql <- sprintf("
  SELECT
    id AS app_id,
    created_at AS date,
    sum(installs) installs
  FROM app_%s
  WHERE created_at > '2018-01-01'
  GROUP BY 1, 2
", 1:100)

dat <- db('apps-db', sql)
```

Note that the `sql` variable above is a vector of queries, each being different
from the others by the table name it reads from. `db('apps-db', sql)` will
distribute those queries in parallel on the single PostgreSQL database instance.

### TODO: Multiple Queries on Multiple Databases

Similar to the above usecase, - this is no

### TODO: rport on PostgreSQL and Shiny

[Shiny][shiny] is a popular framework for interactive data visualisations in R. The

TODO: add config settings (or maybe simply explain all functions)

## Configuration

`rport` allows some configuration through the R's `options()` functionality.

### Custom Database Config

By default `rport` looks for a `config/database.yml` file. Custom `database.yml`
location could be given in two ways:

* by calling `options('rport-database-yml-file'='~/my-dir/my-config.yml')`
* by setting an evironment variable `RPORT_DB_CONFIG=~/my-dir/my-config.yml`

### Length of the SQL log

`rport` logs SQL statements on `db()` call. By default only the first 100
characters are logged. This length could be changed by:

* `options('rport-max-sql-query-log-length'=111)`

### FAQ

* Why did you choose only PostgreSQL as supported backend

The development of Rport has been driven by the internal needs at Adjust, which is a PostgreSQL company. However
abstracting the RDBMS backend is easily achievable and could be done at future iterations on the project. Contributions
are also welcome.

* Why not make the project even more lightweight by dropping the YML dependency

The concept of `database.yml` connection definitions have been borrowed from the `Ruby on Rails` world. For the time
being this will stay part of `rport`, but we might in the future offer support for other configuration formats and even
make the YML dependency obsolete.

* Why did you switch the goal of the project away from a generic framework for analytics apps

The idea of a framework for analytics apps is not dead for us. In a possible future development of such framework,
`rport` would definitely be a part of it. However, we chose to focus the project on addressing our growing analytics
needs and we realized we were mainly using the DB connectivity feature of `rport`, so we further developed that. Caching
was one example where we found that the `memoise` package was exactly what we needed for the purpose and so there was no
use of us duplicating the functionality in `rport`.

* Why don't you consider the newer `RPostgres` driver for PostgreSQL.

We follow the development of the [RPostgres][rpostgres] project closely and we might switch to it as a supported
PostgreSQL driver in the future.

-----

This version deprecates some of the unused functionality and focuses rport to distributed database connectivity. Deprecated features are:

* caching (this is left in the hands of the client - for example by using memoise).
* project/app skeleton building (this can be done using other tools).

---

Instead this version 1.0.0 focuses the project on handling Database querying for analytics in various sharding setups and SQL data models. See the updated readme for more examples.

closes https://github.com/adjust/rport/issues/1
closes https://github.com/adjust/rport/issues/3
closes https://github.com/adjust/rport/issues/7
closes https://github.com/adjust/rport/issues/8
closes https://github.com/adjust/rport/issues/9
closes https://github.com/adjust/rport/issues/12
closes https://github.com/adjust/rport/issues/14
closes https://github.com/adjust/rport/issues/16

-----

#

* update README
* configure query output length
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

## Contributing

* Running the test suite
* Send a Pull request

## License

This Software is licensed under the MIT License.

Copyright (c) 2018 adjust GmbH, http://www.adjust.com

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

[shiny]: https://shiny.rstudio.com "Shiny"
[data_table]: https://github.com/Rdatatable/data.table "The Data Table R Package"
[adjust]: http://adjust.com "Adjust"
[rpostgres]: https://github.com/r-dbi/RPostgres
[rpostgresql]: https://cran.r-project.org/web/packages/RPostgreSQL/index.html
