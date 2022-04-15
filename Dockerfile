###########################################################
#
# Docker image for Polygeist artifact evaluation.
#
###########################################################

FROM nvidia/cuda:11.6.2-devel-ubuntu20.04
ARG DEBIAN_FRONTEND=noninteractive
ARG GID
ARG UID
RUN echo "Group ID: $GID"
RUN echo "User ID: $UID"

# Essential packages
RUN apt-get update
RUN apt-get install apt-utils
RUN apt-get -y install tzdata --assume-yes



RUN apt-get install git cmake gcc g++ ninja-build python3 -y

WORKDIR /root
RUN git clone https://github.com/wsmoses/Polygeist && cd Polygeist && git checkout 72029b6 && git submodule update --init --recursive
WORKDIR Polygeist
RUN mkdir mlir-build \
    && cd mlir-build \
    && cmake ../llvm-project/llvm -GNinja -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS="mlir;clang;openmp" -DLLVM_TARGETS_TO_BUILD="host" \
    && ninja
RUN mkdir build \
    && cd build \
    && cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release -DMLIR_DIR=`pwd`/../mlir-build/lib/cmake/mlir -DClang_DIR=`pwd`/../mlir-build/lib/cmake/clang \
    && ninja

WORKDIR /root
RUN git clone https://github.com/ivanradanov/rodinia && cd rodinia && git checkout a0b4308

WORKDIR rodinia
RUN ./scripts/enable-config.sh common/host.make.config common/docker.polygeist.host.make.config
RUN ./scripts/enable-config.sh common/openmp.host.make.config common/docker.polygeist-clang.openmp.host.make.config

WORKDIR /root
RUN apt-get install wget -y
RUN wget http://www.cs.virginia.edu/~skadron/lava/Rodinia/Packages/rodinia_3.1.tar.bz2
RUN tar xf rodinia_3.1.tar.bz2
RUN rm -r /root/rodinia/data
RUN ln -s /root/rodinia_3.1/data /root/rodinia/data

WORKDIR rodinia
RUN sed -i 's/memkf02/docker/g' scripts/run_all_benches.sh
