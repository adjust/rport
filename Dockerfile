FROM postgres:10
FROM r-base

RUN apt-get update

# Postgres deps
RUN apt-get install -y postgresql-10 postgresql-client-10 postgresql-contrib-10 postgresql-server-dev-10

# Necessary for devtools
RUN apt-get install -t unstable -y libcurl4-openssl-dev libssl-dev

VOLUME /build

USER "postgres"

RUN mkdir -p ~/R/library
RUN R --vanilla -e "install.packages('devtools', '~/R/library', repos='http://cran.rstudio.com')"

RUN /etc/init.d/postgresql start

CMD ["bash"]
