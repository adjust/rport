## Disclaimer

This project is currently under development and is still unreleased.

## TL;DR

Rport is an R package that greatly facilitates common tasks found in many R
Business Intelligence apps. It bridges R and SQL analytics similarly to how
Rails bridges Ruby and Web Development.

## Introduction

From our work doing analytics with R on Adjust and Apptrace data, we could
identify several tasks, repeating in nearly any project we'd initiate.

* Handling mutiple database connections within one R session.

* Caching results from long SQL statements in development.

* Parallel jobs processing.

* Building UNIX executables.

* Organizing the growing codebase.

While R supports all these, there isn't a framework to contain the repeated code
that you'll end up with when building a multi-projects analytics app.

For our needs we built such framework and this article presents it. We named it
Rport and it's open-sourced as an R extension.

## Quick Start

Rport is distributed as an R package and is available from CRAN, so what you
need to do to start using it is:

    install.packages('rport')

Alternativey, install from GitHub:

    library(devtools)
    install_github('rport', 'adeven')

Then if you want to set up a fresh Rport app, from an interactive R session do:

    library(rport)

    rport.app.new('BI kingdom', root.dir='~/my_apps/')
    # help(rport.app.new) for full list of options

This will create the file structure of a clean Rport app. Next you'll probably
want to start setting up different projects for this and that in your new Rport
app. To do this:

    rport.project.new('weekly kpi report', root.dir='~/my_apps/bi_kingdom')
    # again help(rport.project.new) to see more

Now you've bootstraped your first Rport app with one project in it for reporting
Weekly KPIs. In fact, if all went well you should already be able to see some
output from your app by doing:

    cd ~/my_apps/bi_kingdom
    ./bin/weekly_kpi_report.R

Go ahead and browse the generated files, they're well commented and
you will find some next steps there too.

## See more

Read the blog post for more of the features.
