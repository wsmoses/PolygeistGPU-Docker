###########################################################
#
# Docker image for Polygeist artifact evaluation.
#
###########################################################

FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ARG GID
ARG UID
RUN echo "Group ID: $GID"
RUN echo "User ID: $UID"

# Essential packages
RUN apt-get update
RUN apt-get install apt-utils
RUN apt-get -y install tzdata --assume-yes



RUN apt-get install git cmake gcc g++ ninja-build python -y

RUN git clone https://github.com/wsmoses/Polygeist && cd Polygeist && git checkout 72029b6 && git submodule update --init --recursive
RUN cd Polygeist \
    && mkdir mlir-build \
    && cd mlir-build \
    && cmake ../llvm-project/llvm -GNinja -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS="mlir;clang;openmp" -DLLVM_TARGETS_TO_BUILD="host" && ninja

RUN cd Polygeist \
    && mkdir build \
    && cd build \
    && cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_TYPE=Release -DMLIR_DIR=`pwd`/../mlir-build/lib/cmake/mlir -DClang_DIR=`pwd`/../mlir-build/lib/cmake/clang&& ninja


RUN git clone https://github.com/ivanradanov/rodinia && cd rodinia && git checkout 5cec002c0

RUN git clone https://github.com/pytorch/pytorch && cd pytorch && git checkout v1.4.0

RUN sudo apt-get install numactl --yes
