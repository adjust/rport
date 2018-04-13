image_name=rportimg
container_name=rportcnt
tag=latest

test:
	R --slave --vanilla -e 'roxygen2::roxygenize(clean=TRUE)' > /dev/null
	docker exec -w /build ${container_name} bash -c 'bash tests/suite.sh'

build-image:
	docker build --tag ${image_name} .

start-container:
	docker run -d --rm -it -v $$(pwd):/build -e R_LIBS_USER=~/R/library --name ${container_name} ${image_name}:latest
	docker exec ${container_name} bash -c '/etc/init.d/postgresql start'
	docker exec -w /build ${container_name} bash -c "R --vanilla -e 'devtools::install_deps()'"
	docker exec -w /build ${container_name} bash -c "R --vanilla -e \"install.packages('testthat', repos='http://cran.rstudio.com')\""

stop-container:
	docker stop ${container_name}
