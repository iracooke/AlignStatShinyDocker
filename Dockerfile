# "ported" by Adam Miller <maxamillion@fedoraproject.org> from
#   https://github.com/fedora-cloud/Fedora-Dockerfiles
#
# Originally written for Fedora-Dockerfiles by
#   "Scott Collier" <scollier@redhat.com>
#   
# Taken from https://github.com/CentOS/CentOS-Dockerfiles/tree/master/httpd/centos7
# by Benji Wakely <b.wakely@latrobe.edu.au>, 20150116

# "supervisor"-ness taken from http://tiborsimko.org/docker-running-multiple-processes.html

# After build / for first-run setup, see /data/docker/shiny/READTHIS for steps
# relating to mounting host-directories for persistence,
# changing permissions on those directories etc.

#FROM centos-with-ssh:latest
FROM centos:latest
MAINTAINER Benji Wakely <b.wakely@latrobe.edu.au>

RUN yum install -y epel-release

RUN yum install -y cmake \
					make \
					gcc \
					g++ \
					git \
					hostname \
					openssh-server \
					supervisor \
                    wget \
                    openssl-devel libcurl-devel



RUN yum install -y R && \
	yum clean all

RUN groupadd -g 600 shiny && useradd -u 600 -g 600 -r -m shiny
# Note: /var/log/shiny-server needs to be mounted from the host at run-time, so creating it here
# won't actually do anything.  But just in case the build process needs it...
RUN mkdir -p /var/log/shiny-server /srv/shiny-server /var/lib/shiny-server /etc/shiny-server && \
	chown -R shiny /var/log/shiny-server

RUN cd /root/ &&\
	git clone https://github.com/rstudio/shiny-server.git &&\
	cd shiny-server &&\
	mkdir tmp &&\
	cd tmp &&\
	DIR=`pwd` &&\
	PATH=$DIR/../bin:$PATH &&\
	cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DPYTHON="$PYTHON" ../ &&\
	make  &&\
	mkdir ../build &&\
	(cd .. && ./bin/npm --python="$PYTHON" rebuild) &&\
	(cd .. && ./bin/node ./ext/node/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js --python="$PYTHON" rebuild) &&\
	make install

RUN mkdir -p /usr/share/doc/R-3.2.2/html/ 

RUN R -e "install.packages(c('shiny', 'rmarkdown'), repos='https://cran.rstudio.com/')"

RUN R -e "install.packages(c('devtools'), repos='https://cran.rstudio.com/')"

RUN R -e 'devtools::install_github("iracooke/AlignStat")'

RUN wget https://github.com/iracooke/AlignStatShiny/archive/v1.2.1.zip && \
    unzip v1.2.1.zip && \
    mkdir -p /srv/shiny-server/alignstat && \
    cp AlignStatShiny-1.2.1/*.R /srv/shiny-server/alignstat/

RUN ln -s /usr/local/shiny-server/bin/shiny-server /usr/bin/shiny-server

# This is the port that the docker container expects to recieve communications on.
# 
EXPOSE 3838

# Already done in the parent container.
# If modifying this dockerfile to generate a standalone container,
# please touch / create '/etc/supervisord.conf'
RUN echo "[supervisord]" > /etc/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:sshd]" >> /etc/supervisord.conf && \
    echo "command=/usr/sbin/sshd -D " >> /etc/supervisord.conf && \
    echo "[program:httpd]" >> /etc/supervisord.conf && \
    echo "command=/usr/sbin/apachectl -D FOREGROUND" >> /etc/supervisord.conf

# The above is already set up in the base image, centos-with-ssh:latest
COPY shiny-server.conf /etc/shiny-server/

RUN ssh-keygen -t rsa -f /root/.ssh/ssh_host_rsa_key -N ''

RUN echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA0A4feEXOoT0NW1buzUyxaQZmAojuLqCGn1q5acuU7g0ib/Q9huvDodRu642KJFp6VofdGkNMKFOe7kzVHRkDoO8Hy0QVP1xygPol7U1da8XeSbLxpzVaVftuWb9XOukqiJmRiX2ElvT9KAkrDuwnEchynkPfF81DFBZnEsYW3yKGNfYq+fgzf+4yTaAvqFA0FvvVMIwh/NUf5Ct10u5kD1zyz50ZTBoF/tEmtleMWrl+zMRj6WQtZftDnL8JF83m5SU8R54GRQwYAKkGCiK+F+OzI5Zxbz3VYWlKsixMELGv6xE11AZ8t684LdBHaDIrox8SZruAzHexjV7aOVFbXQ==' >> /root/.ssh/authorized_keys

RUN echo "[program:shiny]" >> /etc/supervisord.conf && \
    echo "command=/usr/bin/bash -c '/usr/bin/shiny-server'" >> /etc/supervisord.conf

CMD ["/usr/bin/supervisord"]
