#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"
source "${SDIR}/../dep/python.env"

cd ${SDIR}/../dep/pytorch
TORCHDIR=$(pwd)

buildDEBUG=0
buildRELEASE=1

git submodule update --init --recursive
git checkout -- \
	cmake/public/cuda.cmake \
	cmake/Modules/FindOpenBLAS.cmake \
	cmake/Modules_CUDA_fix/FindCUDNN.cmake \
	aten/src/ATen/native/cuda/Activation.cu \
	aten/src/ATen/native/cuda/ReduceOpsKernel.cu \
	aten/src/ATen/native/sparse/cuda/SparseCUDABlas.cu \
	aten/src/THCUNN/LogSigmoid.cu \
	tools/setup_helpers/cmake.py
patch -p1 < ${SDIR}/../patches/torch.v1.4.0.patch
sed -i -e '/CMAKE_INSTALL_PREFIX/a\            "CMAKE_VERBOSE_MAKEFILE": "ON",' tools/setup_helpers/cmake.py

CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
python3 -m pip install --upgrade -r requirements.txt

	if [ ${buildDEBUG} -ge 1 ]; then
		rm -rf build
		CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
			BUILD_TYPE=Debug DEBUG=ON REL_WITH_DEB_INFO=ON USE_GFLAGS=ON \
			MAX_JOBS=48 VERBOSE=1 USE_NATIVE_ARCH=ON \
			USE_CUDA=ON CUDA_USE_STATIC_CUDA_RUNTIME=OFF \
			USE_CUDNN=ON USE_STATIC_CUDNN=OFF CUDNN_STATIC=OFF \
			USE_NCCL=ON USE_STATIC_NCCL=OFF USE_SYSTEM_NCCL=ON \
			USE_FBGEMM=OFF USE_NUMPY=ON \
			USE_NNPACK=ON USE_QNNPACK=ON \
			USE_DISTRIBUTED=ON USE_MPI=ON USE_GLOO=OFF \
			BUILD_CAFFE2_OPS=ON CAFFE2_STATIC_LINK_CUDA=OFF \
			USE_OPENMP=ON USE_FFMPEG=OFF DISABLE_NUMA=ON \
			TORCH_CUDA_ARCH_LIST="7.5" \
			TORCH_NVCC_FLAGS="-ccbin $(basename ${MocCXX})" \
			BLAS=MKL USE_MKL=ON USE_MKLDNN=ON MKL_THREADING=OMP USE_MKLDNN_CBLAS=ON \
			USE_PROF=ON BUILD_TEST=OFF BUILD_NAMEDTENSOR=OFF USE_STATIC_DISPATCH=OFF \
			CUDA_HOME=${CUDA_TOOLKIT_ROOT_DIR} \
			CUDNN_INCLUDE_DIR=${CUDNN_ROOT}/include CUDNN_LIB_DIR=${CUDNN_ROOT}/lib64 \
		python3 setup.py bdist_wheel 2>&1 | tee comp_debug
			#TORCH_CUDA_ARCH_LIST="6.1;7.5" \  -> 7.5 runs on RTX 20?0 versions
		mkdir -p debug_dist ; mv dist/torch-*.whl debug_dist/
	fi

	if [ ${buildRELEASE} -ge 1 ]; then
		rm -rf build
		CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
			BUILD_TYPE=Release DEBUG=OFF REL_WITH_DEB_INFO=OFF USE_GFLAGS=OFF \
			MAX_JOBS=48 VERBOSE=1 USE_NATIVE_ARCH=ON \
			USE_CUDA=ON CUDA_USE_STATIC_CUDA_RUNTIME=OFF \
			USE_CUDNN=ON USE_STATIC_CUDNN=OFF CUDNN_STATIC=OFF \
			USE_NCCL=ON USE_STATIC_NCCL=OFF USE_SYSTEM_NCCL=ON \
			USE_FBGEMM=OFF USE_NUMPY=ON \
			USE_NNPACK=ON USE_QNNPACK=ON \
			USE_DISTRIBUTED=ON USE_MPI=ON USE_GLOO=OFF \
			BUILD_CAFFE2_OPS=ON CAFFE2_STATIC_LINK_CUDA=OFF \
			USE_OPENMP=ON USE_FFMPEG=OFF DISABLE_NUMA=ON \
			TORCH_CUDA_ARCH_LIST="7.5" \
			TORCH_NVCC_FLAGS="-ccbin $(basename ${MocCXX})" \
			BLAS=MKL USE_MKL=ON USE_MKLDNN=ON MKL_THREADING=OMP USE_MKLDNN_CBLAS=ON \
			USE_PROF=ON BUILD_TEST=OFF BUILD_NAMEDTENSOR=OFF USE_STATIC_DISPATCH=OFF \
			CUDA_HOME=${CUDA_TOOLKIT_ROOT_DIR} \
			CUDNN_INCLUDE_DIR=${CUDNN_ROOT}/include CUDNN_LIB_DIR=${CUDNN_ROOT}/lib64 \
		python3 setup.py bdist_wheel 2>&1 | tee comp_release
			#TORCH_CUDA_ARCH_LIST="6.1;7.5" \  -> 7.5 runs on RTX 20?0 versions
	fi


cd "${SDIR}"/	# step outside build dir to prevent strange pip issues
if ! python3 -m pip list | grep torch >/dev/null 2>&1 ; then
	python3 -m pip install --upgrade "${TORCHDIR}"/dist/torch-*.whl
else
	python3 -m pip install --upgrade --force-reinstall --no-deps "${TORCHDIR}"/dist/torch-*.whl
fi

cat <<EOF > ${TORCHDIR}/../torch.env
export TORCH_BUILD_ROOT=${TORCHDIR}
EOF






exit





export CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-10.0
export PATH=${CUDA_TOOLKIT_ROOT_DIR}/bin:${PATH}
export LD_LIBRARY_PATH=${CUDA_TOOLKIT_ROOT_DIR}/lib64:${LD_LIBRARY_PATH}
export CC=$(which gcc) ; export CXX=$(which g++) ; export NVCC=${CUDA_TOOLKIT_ROOT_DIR}/bin/nvcc

export CUDNN_ROOT=/work/opt/cuda/cudnn-10.0-linux-x64-v7.6.5.32
export CUDNN_INCLUDE_DIR=$CUDNN_ROOT/include
export CUDNN_LIB_DIR=$CUDNN_ROOT/lib64
export LD_LIBRARY_PATH=$CUDNN_LIB_DIR:$LD_LIBRARY_PATH

#export SCOREP_TOTAL_MEMORY=4089446400
#export SCOREP_ENABLE_PROFILING=true
#export SCOREP_ENABLE_TRACING=false

export ARCH_OPT_FLAGS="-march=native -O3 -Wno-deprecated -fvisibility-inlines-hidden -fdiagnostics-color=always -fno-math-errno -fno-trapping-math"
export CMAKE_C_FLAGS="$ARCH_OPT_FLAGS"
export CMAKE_CXX_FLAGS="$CMAKE_C_FLAGS -faligned-new"
export CFLAGS="$CMAKE_C_FLAGS"

# set CAFFE2_STATIC_LINK_CUDA to ON in CMakeLists.txt
# for x in ./aten/src/ATen/CMakeLists.txt ./cmake/public/cuda.cmake ./torch/share/cmake/Caffe2/public/cuda.cmake ; do sed -i -e 's/libcufft_static\.a/libcufft_static_nocallback.a/g' $x; done
BLAS=MKL BUILD_NAMEDTENSOR=OFF BUILD_TYPE=${buildTYPE} DISABLE_NUMA=1 \
	PERF_WITH_AVX=1 PERF_WITH_AVX2=1 PERF_WITH_AVX512=1 \
	USE_CUDA=ON USE_EXCEPTION_PTR=1 USE_GFLAGS=OFF USE_GLOG=OFF USE_MKL=ON USE_MKLDNN=ON \
	USE_MPI=OFF USE_NCCL=OFF USE_NNPACK=ON USE_OPENMP=ON USE_STATIC_DISPATCH=OFF \
	MAGMA_HOME=/home/jens/magma-2.5.2 USE_STATIC_NCCL=0 CUDA_USE_STATIC_CUDA_RUNTIME=1 CUDNN_STATIC=1 \
	CAFFE2_STATIC_LINK_CUDA=1 USE_STATIC_CUDNN=1 VERBOSE=1 BUILD_TEST=0 NO_DISTRIBUTED=1 \
	python3 setup.py bdist_wheel 2>&1 | tee comp

rm -rf build
export NCCL_ROOT=/work/opt/cuda/nccl_2.5.6-1+cuda10.0_x86_64 ; export NCCL_ROOT_DIR=${NCCL_ROOT}
export NCCL_INCLUDE_DIR=${NCCL_ROOT}/include ; export NCCL_LIB_DIR=${NCCL_ROOT}/lib
export LD_LIBRARY_PATH=${NCCL_LIB_DIR}:${LD_LIBRARY_PATH}
BLAS=MKL BUILD_NAMEDTENSOR=OFF BUILD_TYPE=${buildTYPE} DISABLE_NUMA=1 \
	PERF_WITH_AVX=1 PERF_WITH_AVX2=1 PERF_WITH_AVX512=1 \
	USE_CUDA=ON USE_EXCEPTION_PTR=1 USE_GFLAGS=OFF USE_GLOG=OFF USE_MKL=ON USE_MKLDNN=ON \
	USE_MPI=ON USE_NCCL=ON USE_NNPACK=ON USE_OPENMP=ON USE_STATIC_DISPATCH=OFF \
	USE_STATIC_NCCL=OFF CUDA_USE_STATIC_CUDA_RUNTIME=OFF CUDNN_STATIC=OFF CAFFE2_STATIC_LINK_CUDA=OFF \
	USE_STATIC_CUDNN=OFF VERBOSE=1 BUILD_TEST=0 USE_DISTRIBUTED=ON \
	TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5" MAX_JOBS=48 \
	python3 setup.py bdist_wheel 2>&1 | tee comp
	python3 -m pip install --user --upgrade ~/pytorch/dist/torch-1.4.0a0+7f73f1d-cp36-cp36m-linux_x86_64.whl

	HOROVOD_WITH_PYTORCH=1 HOROVOD_WITHOUT_TENSORFLOW=1 HOROVOD_WITHOUT_MXNET=1 HOROVOD_WITHOUT_GLOO=1 \
		HOROVOD_WITH_MPI=1 HOROVOD_GPU=CUDA \
		HOROVOD_GPU_ALLREDUCE=MPI HOROVOD_GPU_ALLGATHER=MPI \
		HOROVOD_GPU_BROADCAST=MPI HOROVOD_CPU_OPERATIONS=MPI \
		python3 setup.py bdist_wheel 2>&1 | tee comp
			python3 -m pip install --user --upgrade ~/horovod/dist/horovod-0.19.0-cp36-cp36m-linux_x86_64.whl

