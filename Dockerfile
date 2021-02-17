# mccahill/r-studio
#
# VERSION 1.1

FROM   ubuntu:18.04
MAINTAINER Mark McCahill "mark.mccahill@duke.edu"

ENV DEBIAN_FRONTEND noninteractive
ENV R_VERSION="3.6.3"
ENV RSTUDIO_VERSION="1.2.1335"
ENV CRAN_REPO="'https://mran.revolutionanalytics.com/snapshot/2020-04-23'"

# get R from a CRAN archive 
RUN apt-get update && \
   apt-get -yq install \
   gnupg2
# RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu bionic/" >>  /etc/apt/sources.list
# RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys  E084DAB9
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9


RUN apt-get update && \
    apt-get dist-upgrade -y 

# we want OpenBLAS for faster linear algebra as described here: http://brettklamer.com/diversions/statistical/faster-blas-in-r/
RUN apt-get update && \
   apt-get -yq install \
   apt-utils



# Install R
RUN echo "deb http://cran.r-project.org/bin/linux/ubuntu bionic-cran35/" > /etc/apt/sources.list.d/r.list
  # apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
RUN apt-get update && \
    apt-get -yq --no-install-recommends install \
    r-base=${R_VERSION}* \
    r-base-core=${R_VERSION}* \
    r-base-dev=${R_VERSION}* \
    r-recommended=${R_VERSION}* \
    r-base-html=${R_VERSION}* \
    r-doc-html=${R_VERSION}* \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libcairo2-dev \
    libxt-dev

#Utilities
RUN apt-get update && \
   apt-get -yq install \
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
   apt-get -yq install \
   texlive \ 
   texlive-base \ 
   texlive-latex-extra \ 
   texlive-pstricks 

# R-Studio
RUN apt-get update && \
   apt-get -yq install \
   gdebi-core \
   dpkg-sig \
   libapparmor1

RUN wget --no-verbose https://download2.rstudio.org/rstudio-server-1.1.383-amd64.deb
RUN gdebi -n rstudio-server-1.1.383-amd64.deb
RUN rm rstudio-server-1.1.383-amd64.deb
# https://github.com/inversepath/usbarmory-debian-base_image/issues/9
RUN mkdir ~/.gnupg && \
    echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf && \
    gpg2 --keyserver keys.gnupg.net --recv-keys 3F32EE77E331692F

# https://www.rstudio.com/code-signing/
RUN wget --no-verbose https://download2.rstudio.org/server/bionic/amd64/rstudio-server-${RSTUDIO_VERSION}-amd64.deb && \
    dpkg-sig --verify rstudio-server-${RSTUDIO_VERSION}-amd64.deb && \
    gdebi -n rstudio-server-${RSTUDIO_VERSION}-amd64.deb && \
    rm rstudio-server-${RSTUDIO_VERSION}-amd64.deb

# dependency for R XML library
RUN apt-get update && \
   apt-get -yq install \
   libxml2 \ 
   libxml2-dev \
   libssl-dev

# install rmarkdown
ADD ./conf /r-studio
# RUN R CMD BATCH /r-studio/install-rmarkdown.R
# RUN rm /install-rmarkdown.Rout 

# Supervisord
RUN apt-get update && \
   apt-get -yq install \
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
   apt-get -yq install \
   locales 
RUN locale-gen en_US en_US.UTF-8
RUN dpkg-reconfigure locales


#########
#
# if you need additional tools/libraries, add them here.
# also, note that we use supervisord to launch both the password
# initialize script and the RStudio server. If you want to run other processes
# add these to the supervisord.conf file
#
## BEGIN: Additional libraries for IBIEM 2018-2019 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# This block ripped off from https://bitbucket.org/granek/parker_rat_lung/src/06190fd6fcac5054958f35dd37c303f538dec694/docker/Dockerfile?at=master&fileviewer=file-view-default
# Configure environment
ENV MANUAL_BIN /opt/bin
ENV MANUAL_SHARE="/opt/share"
ENV PATH $PATH:$MANUAL_BIN:/usr/lib/abyss/:/usr/lib/rstudio-server/bin/pandoc
ENV SHELL /bin/bash
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV RSTUDIO_USER guest

RUN apt-get update && \
   apt-get -yq install \
   seqtk \
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
   bc \
   rdp-readseq \
   rdp-classifier \
   rdp-alignment \
   librdp-taxonomy-tree-java \
   clustalw \
   fastqc
   
# RUN pip install qiime

# Install tidyverse and packages necessary for knitting to HTML 
RUN Rscript -e "install.packages(pkgs = c('tidyverse','caTools','rprojroot','rmarkdown','R.utils'), \
     repos=${CRAN_REPO}, \
     dependencies=TRUE, \
     clean = TRUE)"


#  Add microbiome specific R and bioconductor packages
RUN Rscript -e "install.packages(pkgs = c('fs','ips','unvotes','DT','sandwich','TH.data', 'here', 'sf', 'spdep', 'agricolae','topicmodels'), \
    repos=${CRAN_REPO}, \
     dependencies=TRUE, \
     clean = TRUE)"

RUN Rscript -e "if (!requireNamespace('BiocManager')){install.packages('BiocManager')}; \
    BiocManager::install(c('dada2','ShortRead','phyloseq','msa','DESeq2','metagenomeSeq','ALDEx2','decontam','ANCOMBC'))"

# need to install older version of multcomp to avoid dependency on newer mvtnorm, which depends on newer R
# also needed to install multcomp dependencies: "sandwich","TH.data"
RUN Rscript -e \
    "install.packages(c('https://cran.r-project.org/src/contrib/Archive/mvtnorm/mvtnorm_1.0-8.tar.gz', \
    'https://cran.r-project.org/src/contrib/Archive/multcomp/multcomp_1.4-8.tar.gz'), \
    repos=NULL, type='source', \
    clean = TRUE)"

RUN Rscript -e "install.packages(pkgs = c('robCompositions'), \
    repos=${CRAN_REPO}, \
    dependencies=TRUE, \
    clean = TRUE)"



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
RUN pip install DukeDSClient multiqc

# Install FastTree and FastTreeMP
RUN mkdir -p $MANUAL_BIN && \
   wget --no-verbose -O $MANUAL_BIN/FastTree.c http://www.microbesonline.org/fasttree/FastTree-2.1.10.c && \
   gcc -DUSE_DOUBLE -O3 -finline-functions -funroll-loops -Wall -o $MANUAL_BIN/FastTree $MANUAL_BIN/FastTree.c -lm && \
   gcc -DUSE_DOUBLE -DOPENMP -fopenmp -O3 -finline-functions -funroll-loops -Wall -o $MANUAL_BIN/FastTreeMP $MANUAL_BIN/FastTree.c -lm && \
   chmod 555 $MANUAL_BIN/FastTree $MANUAL_BIN/FastTreeMP && \
   rm $MANUAL_BIN/FastTree*.c

# Install Lefse
# R libraries: splines, stats4, survival, mvtnorm, modeltools, coin, MASS
RUN Rscript -e "install.packages(pkgs = c('coin'), \
    repos=${CRAN_REPO}, \
    dependencies=TRUE)"

# python libraries: rpy2 (v. 2.1 or higher), numpy, matplotlib (v. 1.0 or higher), argparse 
RUN apt-get update && \
   apt-get -yq install \
   python-rpy2

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python-h5py

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nano \
    jed

RUN mkdir -p $MANUAL_BIN && \
   cd $MANUAL_BIN && \
   curl -s -o lefse.tar.gz https://bitbucket.org/nsegata/lefse/get/1.0.8.tar.gz && \
   tar --strip-components=1 -zxf lefse.tar.gz && \
   chmod 555 format_input.py lefse.py \
      lefse2circlader.py plot_cladogram.py \
      plot_features.py plot_res.py \
      qiime2lefse.py run_lefse.py && \
   rm lefse.tar.gz

# USER $RSTUDIO_USER

RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    python-h5py


##------------------------------------------------------------
# install fastq-mcf and fastq-multx from source since apt-get install causes problems
RUN mkdir -p /usr/bin && \
    cd /tmp && \
    wget  --no-verbose https://github.com/ExpressionAnalysis/ea-utils/archive/1.04.807.tar.gz && \
    tar -zxf 1.04.807.tar.gz &&  \
    cd ea-utils-1.04.807/clipper &&  \
    make fastq-mcf fastq-multx &&  \
    cp fastq-mcf fastq-multx /usr/bin &&  \
    cd /tmp &&  \
    rm -rf ea-utils-1.04.807

# Not sure what this block is for
RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    man-db \
    manpages-posix \
    tree

# UNDER CONSTRUCTION: Nerd Work Zone >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Install RAxML-NG
RUN mkdir -p $MANUAL_BIN download && \
    wget  --no-verbose --directory-prefix download --no-verbose https://github.com/amkozlov/raxml-ng/releases/download/0.9.0/raxml-ng_v0.9.0_linux_x86_64.zip && \
    unzip -d download download/raxml-ng_v0.9.0_linux_x86_64.zip && \
    mv download/raxml-ng $MANUAL_BIN && \
    rm -rf download

#-----------------------------------------
# Daniel's packages for phylogenetic trees
#-----------------------------------------
RUN Rscript -e "install.packages(pkg='phangorn',repos='http://archive.linux.duke.edu/cran/',INSTALL_opts = c('--no-docs', '--no-help'))" && \
    Rscript -e "BiocManager::install(c('philr','DECIPHER','ggtree'),version='3.10')" && \
    Rscript -e "devtools::install_github('reptalex/phylofactor',version='3.10')"

#SEPP for greengenes
RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    python3-setuptools \
    cmake \
    bison \
    flex && \
    cd /opt && \
    wget --no-verbose https://raw.github.com/smirarab/sepp-refs/master/gg/sepp-package.tar.bz && \
    tar -xjf sepp-package.tar.bz && \
    cd /opt/sepp-package/sepp && \
    python3 setup.py config -c && \
    chmod -R 555 /opt/sepp-package && \
    rm /opt/sepp-package.tar.bz

#GAPPA
RUN cd /opt && \
    git clone --recursive https://github.com/lczech/gappa.git /opt/gappa && \
    cd /opt/gappa && \
    make

#EPA-NG
RUN cd /opt && \
    git clone --recursive https://github.com/Pbdas/epa-ng /opt/epa-ng && \
    cd /opt/epa-ng && \
    make

# UNDER CONSTRUCTION: Nerd Work Zone <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

## END:   Additional libraries for IBIEM 2018-2019 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Switch back to root to start up server
USER root


# expose the RStudio IDE port
EXPOSE 8787 

# expose the port for the shiny server
#EXPOSE 3838

CMD ["/usr/bin/supervisord"]
