# mccahill/r-studio
#
# VERSION 1.1

FROM   ubuntu:16.04
MAINTAINER Mark McCahill "mark.mccahill@duke.edu"

RUN echo "Force Rebuild From Scratch 1"

# get R from a CRAN archive 
RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >>  /etc/apt/sources.list
RUN DEBIAN_FRONTEND=noninteractive apt-key adv --keyserver keyserver.ubuntu.com --recv-keys  E084DAB9


RUN apt-get update ; \
    apt-get dist-upgrade -y 

# we want OpenBLAS for faster linear algebra as described here: http://brettklamer.com/diversions/statistical/faster-blas-in-r/
RUN apt-get install  -y \
   apt-utils


RUN apt-get update ; \
   DEBIAN_FRONTEND=noninteractive apt-get  install -y  \
   r-base \
   r-base-dev

#Utilities
RUN DEBIAN_FRONTEND=noninteractive apt-get  install -y \
   vim \
   less \
   net-tools \
   inetutils-ping \
   curl \
   git \
   telnet \
   nmap \
   socat \
   python-software-properties \
   wget \
   sudo \
   libcurl4-openssl-dev \
   libxml2-dev 

# we need TeX for the rmarkdown package in RStudio 
RUN apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get  install -y \
   texlive \ 
   texlive-base \ 
   texlive-latex-extra \ 
   texlive-pstricks 

# R-Studio
RUN DEBIAN_FRONTEND=noninteractive apt-get  install -y \
   gdebi-core \
   libapparmor1
   
#RUN DEBIAN_FRONTEND=noninteractive wget https://download2.rstudio.org/rstudio-server-1.0.44-amd64.deb
#RUN DEBIAN_FRONTEND=noninteractive gdebi -n rstudio-server-1.0.44-amd64.deb
#RUN rm rstudio-server-1.0.44-amd64.deb

#RUN DEBIAN_FRONTEND=noninteractive wget https://s3.amazonaws.com/rstudio-dailybuilds/rstudio-server-1.0.143-amd64.deb
#RUN DEBIAN_FRONTEND=noninteractive gdebi -n rstudio-server-1.0.143-amd64.deb
#RUN rm rstudio-server-1.0.143-amd64.deb

RUN DEBIAN_FRONTEND=noninteractive wget https://download2.rstudio.org/rstudio-server-1.1.383-amd64.deb
RUN DEBIAN_FRONTEND=noninteractive gdebi -n rstudio-server-1.1.383-amd64.deb
RUN rm rstudio-server-1.1.383-amd64.deb

# dependency for R XML library
RUN apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
   libxml2 \ 
   libxml2-dev \
   libssl-dev

# install rmarkdown
ADD ./conf /r-studio
# RUN R CMD BATCH /r-studio/install-rmarkdown.R
# RUN rm /install-rmarkdown.Rout 

# Supervisord
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y supervisor && \
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
RUN apt-get install  -y locales 
RUN locale-gen en_US en_US.UTF-8
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales


#########
#
# if you need additional tools/libraries, add them here.
# also, note that we use supervisord to launch both the password
# initialize script and the RStudio server. If you want to run other processes
# add these to the supervisord.conf file
#
## BEGIN: Additional libraries for IBIEM 2017-2018 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RUN DEBIAN_FRONTEND=noninteractive apt-get update ; \
   DEBIAN_FRONTEND=noninteractive \
   apt-get  install -y \
   seqtk \
   ea-utils \
   chimeraslayer \
   tmux \
   jove \
   raxml \
   htop \
   libudunits2-dev \
   software-properties-common


# This block ripped off from https://bitbucket.org/granek/parker_rat_lung/src/06190fd6fcac5054958f35dd37c303f538dec694/docker/Dockerfile?at=master&fileviewer=file-view-default
# Configure environment
ENV CONDA_DIR /opt/conda
ENV PATH $PATH:$CONDA_DIR/bin:/usr/lib/ChimeraSlayer
ENV SHELL /bin/bash
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV RSTUDIO_USER guest

RUN mkdir -p $CONDA_DIR && \
    chown $RSTUDIO_USER $CONDA_DIR

RUN export DEBIAN_FRONTEND=noninteractive ; \
   add-apt-repository ppa:ubuntugis/ppa ; \
   apt-get update ; \
   apt-get  install -y \
   libgdal-dev \
   libgdal1-dev
   
#  Add microbiome specific R and bioconductor packages
RUN Rscript -e "install.packages(pkgs = c('fs','phangorn','ips','unvotes','tidyverse','DT','robCompositions','sandwich','TH.data', 'here', 'sf', 'spdep', 'agricolae'), \
    repos='https://cran.revolutionanalytics.com/', \
    dependencies=TRUE)" && \
    Rscript -e "source('https://bioconductor.org/biocLite.R'); \
    biocLite(pkgs=c('dada2','ShortRead','phyloseq','msa','DESeq2','metagenomeSeq'))"

# need to install older version of multcomp to avoid dependency on newer mvtnorm, which depends on newer R
# also needed to install multcomp dependencies: "sandwich","TH.data"
RUN Rscript -e \
    "install.packages(c('https://cran.r-project.org/src/contrib/Archive/mvtnorm/mvtnorm_1.0-8.tar.gz', \
    'https://cran.r-project.org/src/contrib/Archive/multcomp/multcomp_1.4-8.tar.gz'), \
    repos=NULL, type='source')"

USER $RSTUDIO_USER

# Install conda as $RSTUDIO_USER
RUN cd /tmp && \
    mkdir -p $CONDA_DIR && \
    wget --quiet https://repo.anaconda.com/miniconda/Miniconda2-4.5.12-Linux-x86_64.sh && \
    echo "4be03f925e992a8eda03758b72a77298 *Miniconda2-4.5.12-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda2-4.5.12-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda2-4.5.12-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda install --quiet --yes conda==4.5.12 && \
    $CONDA_DIR/bin/conda install --quiet python=2.7 qiime=1.9.1 qiime-default-reference=0.1.3 matplotlib=1.4.3 mock nose vsearch=2.6.0 sra-tools mothur lefse -c bioconda -c r && \
    $CONDA_DIR/bin/conda config --system --add channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    conda clean -tipsy

# Install qiime2
RUN cd /tmp && \
    wget --quiet https://data.qiime2.org/distro/core/qiime2-2018.2-py35-linux-conda.yml && \
    $CONDA_DIR/bin/conda env create --quiet -n qiime2-2018.2 --file qiime2-2018.2-py35-linux-conda.yml && \
    rm qiime2-2018.2-py35-linux-conda.yml && \
    conda clean -tipsy

# set up link so vsearch can masquerade as usearch61
RUN ln -s $CONDA_DIR/bin/vsearch $CONDA_DIR/bin/usearch61

# # Install qiime1 notebook as 
# RUN conda install python=2.7 qiime matplotlib=1.4.3 mock nose -c bioconda && \
#     conda clean -tipsy

# ## END:   Additional libraries for IBIEM 2017-2018 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Switch back to root to start up server
USER root


# expose the RStudio IDE port
EXPOSE 8787 

# expose the port for the shiny server
#EXPOSE 3838

CMD ["/usr/bin/supervisord"]
