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

    > library(devtools); install_github('adjust/rport')

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
encouraged. The full benefit of `rport` is however unlocked in contexts where
data is partitioned/sharded.

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
analytics on data from many of these tables. See the example data model below
where each app's data is stored on its own table.

```SQL
create table app_1 (id int, title text, created_at date, installs int,...);
create table app_2 (id int, title text, created_at date, installs int,...);
...
create table app_100 (id int, title text, created_at date, installs int,...);
```

To distribute a query on all apps, using `rport` in R you can do:

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
distribute those queries in parallel on the single PostgreSQL instance.

### Multiple Queries on Multiple Databases

Scaling the usecase above, let's model the raw data on the usage of apps. Each
user's interaction with an app will be producing raws into our tables:

```SQL
create table app_1_20180101 (device_id uuid, created_at timestamp, os_name text, os_version ...);
create table app_1_20180102 (device_id uuid, created_at timestamp, os_name text, os_version ...);
create table app_1_20180103 (device_id uuid, created_at timestamp, os_name text, os_version ...);
...
create table app_2_20180101 (device_id uuid, created_at timestamp, os_name text, os_version ...);
...
```

We'll also put these tables into multiple PostgreSQL instances.

```SQL
create database db1;
create database db2;
create database db3;
...
create database db50;
```

At adjust we actually query hundreds of PostgreSQL databases, where petabytes of
data live according to a similar partitioning scheme. We have a master
PostgreSQL node, which contains the meta-data determining, on which database
data is stored.  Suppose the master instance manages the metadata in a table
like that:

```SQL
CREATE TABLE metadata (
  connection_name text,
  app_id          int,
  created_at      date
)
```

Let's look at how we can run analytical queries using `rport` in R on such
setup. We are interested in estimating the adoption rates of iOS versions and
the activity we see on each version over the last 6 months from our distributed
raw data.

```R
library(rport)

# Get all DB connections containing data for the last 180 days.
metadata <- db('master', '
  SELECT connection_name, app_id, created_at
  FROM metadata
  WHERE created_at > current_date - 180
')

# SQL query that we want to run on every relevant node.
sql.template <- "
  SELECT os_veresion, created_at::date, count(*) AS events
  FROM app_%d_%d
  WHERE os_name = 'ios'
  GROUP BY os_version
"

# data.table syntax to connection names and the relevant SQL
metadata[, sql:=sprintf(sql.template, app_id, created_at)]

dat <- db(metadata$connection_name, metadata$sql)
```

We expect that the database connections are defined at runtime in
`database.yml`. This doesn't have to be the case and at adjust we define these
connections dynamically using `register.connections()` after reading
from the master node.

### rport on PostgreSQL and Shiny

[Shiny][shiny] is a popular framework for interactive data visualisations in R.
Using the [Pool][pool] project and `rport` you can connect Shiny to either your
distributed cluster or simply to all different database you might have. Managing
DB configurations in a centralized file makes it much easier to deploy multiple
Shiny apps.

## Other Features

The main function that `rport` provides is `db()` and it's exemplified in the
Usecases section below. Here's an overview of the rest of `rport`'s functions.

```R
db.connection        # retrieve a connection object from a connection name
db.disconnect        # disconnect either all open connections or by connection name
list.connections     # get a list of all open database connections
register.connections # register a list of new connections (other than those defined in `database.yml`)
reload.db.config     # reload the `database.yml` connection config file
```

For more details on each of those functions, check their help from R - for
example `?db.connection`.

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

## Contributing

To run the test suite of `rport` you'll need [Docker][docker]. Check the
project's Makefile to find your way in the test suite. Build your feature and
send a Pull Request on GitHub. Or just write an issue first.

## Author

Nikola Chochkov nikola@adjust.com, Berlin, adjust GmbH, Germany

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
[pool]: https://github.com/rstudio/pool
[docker]: https://www.docker.com/
