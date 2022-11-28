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
RUN apt-get install apt-utils -y
RUN apt-get -y install tzdata --assume-yes



RUN apt-get install git cmake gcc g++ ninja-build python3 -y

WORKDIR /root
RUN git clone https://github.com/wsmoses/Polygeist && cd Polygeist && git checkout 4a232df859a79c7ac0442a0a312ca0251c6f9b38 && git submodule update --init --recursive
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
RUN git clone https://github.com/ivanradanov/rodinia && cd rodinia && git checkout 025fa7dc6929d44f02bcbc9d9418c0472c6a124e

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
COPY ./command2.txt /root/rodinia/data/b+tree/

WORKDIR /root
RUN cd Polygeist/mlir-build && ninja install
RUN git clone https://github.com/ivanradanov/cpucuda_runtime && cd cpucuda_runtime && git checkout 265fe493e8c3cdc8dc52606100609302e0c6438f
WORKDIR cpucuda_runtime
RUN sed -i 's/cpucuda_libdevice.c//g' src/CMakeLists.txt
RUN mkdir build \
    && cd build \
    && cmake .. -DCUDA_PATH=/usr/local/cuda -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang \
    && make
RUN cp build/src/libcpucudart.a /root/rodinia/mcuda-test/mcuda/libcpucuda.a
COPY ./cuda-samples /root/cuda-samples

WORKDIR /root/rodinia
RUN sed -i 's/echo -n nn/#/g' scripts/cuda_apps.sh

WORKDIR /root/rodinia/mcuda-test/
RUN bash -c "CPUCUDA_BUILD_DIR=/root/cpucuda_runtime/build/ make"
RUN sed -i 's/numactl -N 0 -m 0 //g' /root/rodinia/mcuda-test/run-scaling.sh
RUN bash -c "./run-scaling.sh '128 256 512 1024 2048' '1 2 4 8 16 24' 10 > mm_results.py"
