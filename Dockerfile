# mccahill/r-studio
#
# VERSION 1.1

FROM   ubuntu:18.04
MAINTAINER Mark McCahill "mark.mccahill@duke.edu"

RUN echo "Force Rebuild From Scratch 2"

# get R from a CRAN archive 
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y gnupg2
# RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu bionic/" >>  /etc/apt/sources.list
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
   software-properties-common \
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
# This block ripped off from https://bitbucket.org/granek/parker_rat_lung/src/06190fd6fcac5054958f35dd37c303f538dec694/docker/Dockerfile?at=master&fileviewer=file-view-default
# Configure environment
ENV MANUAL_BIN /opt/bin
ENV MANUAL_SHARE="/opt/share"
ENV PATH $PATH:$MANUAL_BIN:/usr/lib/abyss/
ENV SHELL /bin/bash
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV RSTUDIO_USER guest

RUN apt-get update ; \
   DEBIAN_FRONTEND=noninteractive apt-get -yq install \
   seqtk \
   ea-utils \
   chimeraslayer \
   tmux \
   jove \
   raxml \
   htop \
   libudunits2-dev \
   software-properties-common \
   sra-toolkit \
   libgdal-dev \
   build-essential \
   python-dev \
   python-pip \
   python-numpy \
   python-matplotlib \
   python-pandas \
   ipython \
   samtools \
   rna-star \
   bwa \
   trimmomatic \
   python-igraph \
   abyss \
   bc   

RUN pip install qiime

#  Add microbiome specific R and bioconductor packages
RUN Rscript -e "install.packages(pkgs = c('fs','phangorn','ips','unvotes','tidyverse','DT','sandwich','TH.data', 'here', 'sf', 'spdep', 'agricolae'), \
    repos='https://cran.revolutionanalytics.com/', \
    dependencies=TRUE)"

RUN Rscript -e "source('https://bioconductor.org/biocLite.R'); \
    biocLite(pkgs=c('dada2','ShortRead','phyloseq','msa','DESeq2','metagenomeSeq','DECIPHER'))"

# need to install older version of multcomp to avoid dependency on newer mvtnorm, which depends on newer R
# also needed to install multcomp dependencies: "sandwich","TH.data"
RUN Rscript -e \
    "install.packages(c('https://cran.r-project.org/src/contrib/Archive/mvtnorm/mvtnorm_1.0-8.tar.gz', \
    'https://cran.r-project.org/src/contrib/Archive/multcomp/multcomp_1.4-8.tar.gz'), \
    repos=NULL, type='source')"

# Trans-ABySS
RUN mkdir -p $MANUAL_BIN $MANUAL_SHARE ; \
   wget --no-verbose -O $MANUAL_BIN/blat http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/blat/blat; \
   chmod 555 $MANUAL_BIN/blat ;\
   export TRANSABYSS_VERSION="2.0.1" ; \
   export TA_DIR="transabyss-${TRANSABYSS_VERSION}" ; \
   wget --no-verbose https://github.com/bcgsc/transabyss/archive/${TRANSABYSS_VERSION}.tar.gz ; \
   tar -zxf ${TRANSABYSS_VERSION}.tar.gz ; \
   mv $TA_DIR/transabyss $TA_DIR/transabyss-merge $TA_DIR/bin $TA_DIR/utilities $MANUAL_BIN ; \
   mv $TA_DIR/sample_dataset $MANUAL_SHARE/transabyss_sample_dataset ; \
   chmod -R 555 $MANUAL_BIN/transabyss $MANUAL_BIN/transabyss-merge ; \
   chmod -R 555 $MANUAL_BIN/bin $MANUAL_BIN/utilities $MANUAL_SHARE/transabyss_sample_dataset  ; \
   rm -rf ${TRANSABYSS_VERSION}.tar.gz transabyss-${TRANSABYSS_VERSION}

# DukeDSClient
RUN pip install DukeDSClient

#  Add microbiome specific R and bioconductor packages
RUN Rscript -e "install.packages(pkgs = c('robCompositions'), \
    repos='https://cran.revolutionanalytics.com/', \
    dependencies=TRUE)"

# Install FastTree and FastTreeMP
RUN MANUAL_BIN=/tmp/manual/bin ; \
   mkdir -p $MANUAL_BIN ; \
   wget --no-verbose -O $MANUAL_BIN/FastTree.c $MANUAL_BIN http://www.microbesonline.org/fasttree/FastTree-2.1.10.c ; \
   gcc -DUSE_DOUBLE -O3 -finline-functions -funroll-loops -Wall -o $MANUAL_BIN/FastTree $MANUAL_BIN/FastTree.c -lm ; \
   gcc -DUSE_DOUBLE -DOPENMP -fopenmp -O3 -finline-functions -funroll-loops -Wall -o $MANUAL_BIN/FastTreeMP $MANUAL_BIN/FastTree.c -lm ; \
   chmod 555 $MANUAL_BIN/FastTree $MANUAL_BIN/FastTreeMP ; \
   rm $MANUAL_BIN/FastTree*.c

USER $RSTUDIO_USER
COPY user-settings /home/guest/.rstudio/monitored/user-settings/user-settings_blah_blah_blah
# COPY user-settings /home/rstudio/.rstudio/monitored/user-settings/
# No chown will cause "RStudio Initalization Error"
# "Error occurred during the transmission"; RStudio will not load.
# RUN chown -R guest:guest /home/rstudio/.rstudio


## END:   Additional libraries for IBIEM 2017-2018 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Switch back to root to start up server
USER root


# expose the RStudio IDE port
EXPOSE 8787 

# expose the port for the shiny server
#EXPOSE 3838

CMD ["/usr/bin/supervisord"]
