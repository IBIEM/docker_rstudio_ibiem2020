# mccahill/r-studio
#
# VERSION 1.1

FROM   ubuntu:18.04
MAINTAINER Mark McCahill "mark.mccahill@duke.edu"

RUN echo "Force Rebuild From Scratch 2"

# get R from a CRAN archive 
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   gnupg2
# RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu bionic/" >>  /etc/apt/sources.list
RUN DEBIAN_FRONTEND=noninteractive apt-key adv --keyserver keyserver.ubuntu.com --recv-keys  E084DAB9


RUN apt-get update && \
    apt-get dist-upgrade -y 

# we want OpenBLAS for faster linear algebra as described here: http://brettklamer.com/diversions/statistical/faster-blas-in-r/
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   apt-utils

RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   r-base \
   r-base-dev

#Utilities
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   vim \
   less \
   net-tools \
   inetutils-ping \
   curl \
   git \
   telnet \
   nmap \
   socat \
   software-properties-common \
   wget \
   sudo \
   libcurl4-openssl-dev \
   libxml2-dev 

# we need TeX for the rmarkdown package in RStudio
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   texlive \ 
   texlive-base \ 
   texlive-latex-extra \ 
   texlive-pstricks 

# R-Studio
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   gdebi-core \
   libapparmor1

RUN DEBIAN_FRONTEND=noninteractive wget https://download2.rstudio.org/rstudio-server-1.1.383-amd64.deb
RUN DEBIAN_FRONTEND=noninteractive gdebi -n rstudio-server-1.1.383-amd64.deb
RUN rm rstudio-server-1.1.383-amd64.deb

# dependency for R XML library
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   libxml2 \ 
   libxml2-dev \
   libssl-dev

# install rmarkdown
ADD ./conf /r-studio
# RUN R CMD BATCH /r-studio/install-rmarkdown.R
# RUN rm /install-rmarkdown.Rout 

# Supervisord
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   supervisor && \
   mkdir -p /var/log/supervisor
CMD ["/usr/bin/supervisord", "-n"]

# Config files
RUN cd /r-studio && \
    cp supervisord-RStudio.conf /etc/supervisor/conf.d/supervisord-RStudio.conf
RUN rm /r-studio/*


# add a non-root user so we can log into R studio as that user; make sure that user is in the group "users"
RUN adduser --disabled-password --gecos "" --ingroup users guest 

# add a script that supervisord uses to set the user's password based on an optional
# environmental variable ($VNCPASS) passed in when the containers is instantiated
ADD initialize.sh /

# set the locale so RStudio doesn't complain about UTF-8
RUN apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   locales 
RUN locale-gen en_US en_US.UTF-8
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales


#########
#
# if you need additional tools/libraries, add them here.
# also, note that we use supervisord to launch both the password
# initialize script and the RStudio server. If you want to run other processes
# add these to the supervisord.conf file
#
## BEGIN: Additional libraries for IBIEM 2018-2019 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
## END:   Additional libraries for IBIEM 2018-2019 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Switch back to root to start up server
USER root


# expose the RStudio IDE port
EXPOSE 8787 

# expose the port for the shiny server
#EXPOSE 3838

CMD ["/usr/bin/supervisord"]
