###########################################################
#
# Docker image for MocCUDA artifact evaluation.
#
###########################################################

FROM nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04
ARG DEBIAN_FRONTEND=noninteractive
ARG GID
ARG UID
RUN echo "Group ID: $GID"
RUN echo "User ID: $UID"

# Essential packages
RUN apt-get update
RUN apt-get install apt-utils -y
RUN apt-get -y install tzdata --assume-yes



RUN apt-get install git cmake gcc g++ ninja-build python3 build-essential -y

WORKDIR /root
RUN git clone https://gitlab.com/domke/MocCUDA && cd MocCUDA && git checkout c9647a52
WORKDIR MocCUDA
RUN git submodule update --init --recursive


RUN apt-get install python libkqueue-dev libblocksruntime-dev -y
COPY ./scripts/host.env ./scripts/
RUN bash ./scripts/00*
COPY ./scripts/01_cuda.sh ./scripts/
RUN bash ./scripts/01*
RUN apt-get install python3-venv -y
COPY ./scripts/02_python.sh ./scripts/
RUN bash ./scripts/02*

WORKDIR /root
RUN apt-get install wget -y
RUN wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
RUN apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
#RUN sh -c 'echo deb apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list' && apt-key adv --keyserver keyserver.ubuntu.com --recv ACFA9FC57E6C5DBE && apt update && apt-cache search intel-mkl-64bit
RUN wget https://apt.repos.intel.com/setup/intelproducts.list -O /etc/apt/sources.list.d/intelproducts.list
RUN apt-get update

WORKDIR MocCUDA

RUN apt-get install intel-mkl-2020.4-912 -y
RUN apt-get install python3-yaml python3-setuptools python-cffi python-typing -y --assume-yes
RUN apt-get install python3-pip -y
RUN pip3 install mkl-devel
RUN apt-get install libopenmpi-dev -y
COPY ./scripts/03_pytorch.sh ./scripts/
RUN bash ./scripts/03*

COPY ./scripts/04_horovod.sh ./scripts/
RUN bash ./scripts/04*

RUN apt-get -y install \
    curl \
    ghostscript \
    libffi-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libharfbuzz-dev \
    libjpeg-turbo-progs \
    libjpeg8-dev \
    liblcms2-dev \
    libopenjp2-7-dev \
    libssl-dev \
    libsqlite3-dev \
    libtiff5-dev \
    libwebp-dev \
    netpbm \
    ninja-build \
    tcl8.6-dev \
    tk8.6-dev \
    wget \
    xvfb \
    zlib1g-dev

WORKDIR /root
RUN wget https://github.com/Kitware/CMake/releases/download/v3.23.1/cmake-3.23.1.tar.gz
RUN tar xf cmake*
WORKDIR cmake-3.23.1
RUN ./bootstrap && make -j && make install

WORKDIR /root/MocCUDA
RUN git fetch && git checkout 983ace492fe71f449497b40f923d7886ad0c3033

RUN cd dep/Polygeist && git fetch && git checkout 3976ff996f5d748dc857e44bc1197d442f1626e8 && git submodule update --init --recursive
COPY ./scripts/06_polygeist.sh ./scripts/
RUN bash ./scripts/06*

RUN cd dep/Polygeist/mlir-brelease && ninja install

WORKDIR /root/MocCUDA
RUN git checkout HEAD -- scripts/06_polygeist.sh && git fetch && git checkout 0edb37fed6403e5a8561df11f111e5cecf3a6723
COPY ./scripts/06_polygeist.sh ./scripts/

# TODO we should probably specify version numbers in this script
COPY ./scripts/05_benchmarker.sh ./scripts/
RUN bash -xe ./scripts/05*

RUN apt-get install libunwind-dev -y
RUN apt-get install liblapack-dev -y
RUN apt-get install libopenblas-dev -y
RUN apt-get install gfortran -y
RUN apt-get install libiberty-dev -y
RUN apt-get install libkqueue-dev -y
COPY ./Makefile.docker ./
RUN git checkout HEAD -- scripts/06_polygeist.sh && git fetch && git checkout 91155a465e3eaa78905289912539db55ac701fe5
#RUN sed -i '/demangle.h/d' src/utils/utils.c
#RUN sed -i '/demangle.h/d' wrapper/wrapper.c
RUN sed -i 's/demangle.h/libiberty\/demangle.h/' src/utils/utils.c
RUN sed -i 's/demangle.h/libiberty\/demangle.h/' wrapper/wrapper.c
COPY ./scripts/07_moccuda.sh ./scripts/
RUN bash -e ./scripts/07*

SHELL ["/bin/bash", "-c"]
WORKDIR /root/MocCUDA/dep/benchmarker
RUN mkdir -p /tmp/benchmarkerlogs

RUN . ../../init.env; \
    LD_PRELOAD=/root/MocCUDA/lib/libMocCUDA.so:/usr/local/lib/libomp.so:/usr/lib/x86_64-linux-gnu/libopenblas.so \
    python3 -m benchmarker --framework=pytorch --problem=resnet50 --mode=training \
    --problem_size=1 --batch_size=1 --gpu=0 --path_out=/tmp/benchmarkerlogs

#RUN cd /root/MocCUDA/dep/benchmarker; . ../../init.env; LD_PRELOAD=/root/MocCUDA/lib/libMocCUDA.so:/usr/local/lib/libomp.so:/usr/lib/x86_64-linux-gnu/libopenblas.so python3 -m benchmarker --framework=pytorch --problem=resnet50 --mode=training --problem_size=1 --batch_size=1 --gpu=0 --path_out=/tmp/benchmarkerlogs
