# Benchmark Repository for High-Performance GPU-to-CPU Transpilation andOptimization via High-Level Parallel Constructs", to appear in PPoPP'23

Our paper proposes a representation of GPU parallel constructs and their use in program optimization and retargeting towards CPU. It evaluates CUDA-to-CPU transpilation experimentally.

The evaluation of our results consists of three parts:
* A performance comparison of a CUDA matrix multiply code on CPU, as transpiled by our pipeline (Polygeist) and an existing tool (MCuda).
* An evaluation of CUDA benchmarks from the Rodinia suite on CPU, as transpiled by our pipeline (Polygeist), and a comparison to the native CPU versions of the same benchmarks when available.
* An evaluation of the GPU kernels within PyTorch being replaced with CPU versions of the kernels.

## Machine
Experiments were run on an AWS c6i.metal instance with hyper-threading and Turbo Boost disabled, running Ubuntu 20.04 running on a dual-socket Intel Xeon Platinum 8375C CPU at 2.9 GHz with 32 cores each and 256 GB RAM.

## Obtaining the code
A meta repository containing dockerfiles and source for our set up is available here. The remainder of this section will describe the individual components of our system.

Code for our tool is available at [https://github.com/llvm/Polygeist](https://github.com/llvm/Polygeist), commit `4a232df859` and is obtained as follows:
```bash
$ cd $HOME && git clone https://github.com/llvm/Polygeist
$ cd Polygeist
$ git checkout 4a232df859
$ git submodule update --init --recursive
```

This repository contains submodules for a corresponding version of LLVM/MLIR/Clang, which is automatically checked out by the previous command.

A fork of the Rodinia benchmark suite with scripts for timing as well as the matrix multiplication tests are found at [https://github.com/ivanradanov/rodinia](https://github.com/ivanradanov/rodinia) at commit `025fa7dc`.
```bash
$ cd $HOME && git clone https://github.com/ivanradanov/rodinia
$ cd rodinia
$ git checkout 025fa7dc
```

The Cpucuda runtime dependency of the matrix multiplication comparison found at [https://github.com/ivanradanov/cpucuda_runtime](https://github.com/ivanradanov/cpucuda_runtime) at commit `265fe49`:
```bash
$ cd $HOME && git clone https://github.com/ivanradanov/cpucuda_runtime
$ cd cpucuda_runtime
$ git checkout 265fe49
```

The MocCUDA layer for PyTorch integration can be found at [https://gitlab.com/domke/MocCUDA](https://gitlab.com/domke/MocCUDA) at commit `5a3955d`:
```bash
$ cd $HOME && git clone https://gitlab.com/domke/MocCUDA
$ cd MocCUDA
$ git checkout 5a3955d
```

To evaluate the artifact, we offer three options.
* The first option is an AMI or Amazon Machine Image under image ID `ami-016572c3eb2ab565a`. You may then launch the instance and then skip the rest of this section that involves downloading or building the experiments.
* The second option is to build the tools and experiments from source and is outlined below.
* The third option is to use a Docker container. The docker container contains pre-built versions of the relevant binaries, a collection of all the benchmarks, and so on. As such any benchmark downloading or building of Polygeist/LLVM described here can be skipped, however the instructions on how to run the scripts are the same. The source for the Docker images is available at [https://github.com/wsmoses/PolygeistGPU-Docker](https://github.com/wsmoses/PolygeistGPU-Docker) and can be run by executing the following command:
```bash
# Rodinia and MCUDA
$ docker run -i -t ivanradanov/polygeistgpu /bin/bash
# MocCUDA on x86_64
$ docker run -i -t ivanradanov/moccuda /bin/bash
```

We begin by installing build dependencies (C++ compiler, cmake, ninja). This can be done on Ubuntu 20.04 with the following command:
```bash
$ sudo apt-get install -y cmake gcc g++ ninja-build
```

### llvm-project
We now need to build the LLVM compiler toolchain. To install LLVM, please follow the following steps:

```bash
$ cd $HOME/Polygeist
$ mkdir mlir-build && cd mlir-build
$ cmake ../llvm-project/llvm -GNinja \ 
 -DCMAKE_BUILD_TYPE=Release \ 
 -DLLVM_ENABLE_PROJECTS="mlir;clang;openmp" \ 
 -DLLVM_TARGETS_TO_BUILD="X86"
# This may take a while
$ ninja
```

### Polygeist
We now must build Polygeist based off of the LLVM version we just built.

```bash
$ cd $HOME/Polygeist
$ export MLIR_BUILD=`pwd`/mlir-build
$ mkdir build
$ cd build
$ cmake .. -GNinja \ 
 -DCMAKE_BUILD_TYPE=Release \ 
 -DMLIR_DIR=$MLIR_BUILD/lib/cmake/mlir \ 
 -DClang_DIR=$MLIR_BUILD/lib/cmake/clang 
$ ninja
# cgeist will now be available at  $HOME/Polygeist/build/bin/mlir-clang
```

### Cpucuda runtime
To build and install this dependency one can follow these steps:
```bash
$ cd $HOME/cpucuda_runtime
$ mkdir build
$ cd build
$ cmake .. -DCUDA_PATH=/usr/local/cuda \
 -DCMAKE_CXX_COMPILER=clang++ \
 -DCMAKE_C_COMPILER=clang
$ make
$ cp src/libcpucudart.a $HOME/rodinia/mcuda-test/mcuda/libcpucuda.a
```

## Disabling/Enabling Hyperthreading
We recommend disabling hyperthreading, and provide two scripts for this purpose, assuming a dual-socket 32-core machine.
```bash
$ cd $HOME/rodinia/scripts
$ ./disable.sh
```

## Benchmark Configuration
The Rodinia and MCUDA benchmarks use configuration files in `rodinia/common/` to specify Polygeist, Clang/LLVM, and other installations. The config files for the machine we used are located at
`ubuntu.polygeist.host.make.config` for the CUDA benchmarks and `ubuntu.polygeist-clang.openmp.host.make.config` for the openmp versions.
The structure of the filename must be kept the same, with the `ubuntu` substring representing the machine's hostname.
One must set five variables for the first file and two for the second.
* `POLYGEIST_DIR` should denote the build directory of Polygeist.
* `POLYGEIST_LLVM_DIR` should denote the build directory of LLVM.
* `CUDA_PATH` should denote a valid CUDA path.
* `CPUCUDA_BUILD_DIR` should denote the build directory of the cpucuda_runtime.
* `CUDA_SAMPLES_PATH`  should denote the directory of CUDA samples in a CUDA installation.

Note that even when running on a machine without a GPU, one still needs the header files from a functioning CUDA installation as Rodinia uses several of the helper functions defined within. On the AMI and docker containers, we have provided such a CUDA installation. If building from source on a machine without a GPU, a CUDA installation can be copied from another system.

```
POLYGEIST_DIR=${HOME}/Polygeist/build/
POLYGEIST_LLVM_DIR=${HOME}/Polygeist/mlir-build/
CPUCUDA_BUILD_DIR = ${HOME}/src/cpucuda_runtime/build/
CUDA_PATH = /usr/local/cuda/
CUDA_SAMPLES_PATH = /usr/local/cuda/samples/
```

To conclude configuration, symlink the configuration files:

```bash
$ cd $HOME/rodinia/common
$ ln -s ubuntu.polygeist.host.make.config host.make.config
$ ln -s ubuntu.polygeist-clang.openmp.host.make.config openmp.host.make.config
```

To configure the benchmark run, one should edit the file `rodinia/scripts/run_all_benches.sh`. The `HOST` variable should be set to the hostname of the machine (`ubuntu` above), the variables `NRUNS` and `NRUNS_SCALING` to how many times to run the ablation analysis and scaling analysis benchmarks respectively, and the variables
`THREAD_NUMS` and `THREAD_NUMS_OPENMP` to the list of number of threads to run the CUDA and OpenMP scaling tests respectively (excluding the default maximum number of threads case, which will always be run).

## Rodinia
The Rodinia benchmarks can be compiled and executed by running the following script.
Note that the script assumes a specific machine size, but can be edited.

```bash
$ cd $HOME/rodinia
$ ./scripts/run_all_benches.sh
# The timing results are now available at $HOME/rodinia_results/
```

The correctness of the generated code can be validated as follows. Note that this requires access to a GPU machine to run the GPU-versions of the programs.

On a GPU machine with relevant configuration set up (see `rodinia/common/kiev0.nvcc.host.make.config` for an example):

```bash
$ cd $HOME/rodinia
$ make MY_VERIFICATION_DISABLE=0 cuda
$ ./scripts/dump_cuda_correctness_info.sh
# Now ./verification_data contains the data
```

Ensure that the verification data is available on the machine used to test GPU to CPU. If this is the same machine, no action is required. Otherwise, one can copy the verification folder.

Restore the configuration for Polygeist as outlined above in the configuration section, and execute the following:

```bash
$ cd $HOME/rodinia
$ make MY_VERIFICATION_DISABLE=0 cuda
$ ./scripts/check_cuda_correctness.sh
```

Verification is successful if no `FAIL` can be seen in the output of the final script.

## Matrix Multiplication (MCUDA)
The following commands will compile and execute the matrix multiplication tests for both Polygeist and MCUDA. The arguments to the script are a list of matrix sizes, a list of thread numbers, and the number of runs. The timing data will be output in `mm_results.py`.
```bash
$ cd $HOME/rodinia/mcuda-test
$ make
$ ./run-scaling.sh "128 256 512 1024 2048" "1 2 4 8 16 24" 10 > mm_results.py
```

## MocCUDA
This section describes how to build the MocCUDA layer for Fugaku. 
To build MocCUDA for another system, one can edit the files in `./scripts/` to reflect the environment of their system. 
MocCUDA dependencies, including PyTorch and benchmarker can be built as follows.

```bash
$ cd $HOME/MocCUDA
$ for NR in $(seq -w 00 06); do
$	bash ./scripts/${NR}_*.sh
$ done
```

MocCUDA itself is built with the following script:

```bash
$ bash ./scripts/07_*.sh
```

And only required on Fugaku, the following will set up Fujitsu's custom pytorch:
```bash
$ bash ./scripts/08_*.sh
```

The following script will submit benchmark jobs to Fugaku and populate the `MocCUDA/log` directory with the results.

```bash
$ bash ./bench/submit_fugaku.sh
```

Alternatively, one can use a Fugaku-style MocCUDA docker container for X86 which we have created. The following command will training a single-node resnet50 in docker. Options for the `BACKEND` variable include
`moccuda`, `moccuda-no-polygeist`, `native`, or `dnnl`. Results will be output in the `MocCUDA/log` directory.
```bash
$ cd $HOME/MocCUDA/
$ BACKEND=<backend> ./bench/02_benchmarker_train.sh
```
