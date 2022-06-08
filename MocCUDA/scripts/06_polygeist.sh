#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"

set -e

cd ${SDIR}/../dep/Polygeist
POLTERDIR=$(pwd)


REBUILD=1
buildDEBUG=0
buildRELEASE=1
#XXX: skip for now on a64fx
if lscpu | grep 'sve' >/dev/null 2>&1; then REBUILD=0 ; buildDEBUG=0 ; buildRELEASE=0 ;fi

MLIRDBDIR="mlir-bdebug"
POLDBDIR="debug"
MLIRDIR="mlir-brelease"
POLDIR="release"

if [ ${buildDEBUG} -ge 1 ]; then
	## DEBUG build
	if [ ${REBUILD} -ge 1 ]; then rm -rf "${MLIRDBDIR}" ; mkdir "${MLIRDBDIR}" ; fi
	cd "${MLIRDBDIR}"/
	if [ ${REBUILD} -ge 1 ]; then
		cmake ../llvm-project/llvm -GNinja \
			-DLLVM_ENABLE_PROJECTS="llvm;clang;mlir;openmp" \
			-DCMAKE_BUILD_TYPE=Debug
	fi
	cmake --build .
	cd "${POLTERDIR}"/

	if [ ${REBUILD} -ge 1 ]; then rm -rf "${POLDBDIR}" ; mkdir "${POLDBDIR}" ; fi
	cd "${POLDBDIR}"/
	if [ ${REBUILD} -ge 1 ]; then
		cmake ../ -GNinja \
			-DMLIR_DIR=$(pwd)/../"${MLIRDBDIR}"/lib/cmake/mlir \
			-DLLVM_EXTERNAL_LIT=$(pwd)/../"${MLIRDBDIR}"/bin/llvm-lit \
			-DClang_DIR=$(pwd)/../"${MLIRDBDIR}"/lib/cmake/clang \
			-DCMAKE_BUILD_TYPE=Debug
	fi
	ninja mlir-clang
	cd "${POLTERDIR}"/
fi

if [ ${buildRELEASE} -ge 1 ]; then
	## RELEASE build
	if [ ${REBUILD} -ge 1 ]; then rm -rf "${MLIRDIR}" ; mkdir "${MLIRDIR}" ; fi
	cd "${MLIRDIR}"/
	if [ ${REBUILD} -ge 1 ]; then
		cmake ../llvm-project/llvm -GNinja \
			-DLLVM_ENABLE_PROJECTS="llvm;clang;mlir;openmp" \
			-DCMAKE_BUILD_TYPE=Release
	fi
	cmake --build .
	cd "${POLTERDIR}"/

	if [ ${REBUILD} -ge 1 ]; then rm -rf "${POLDIR}" ; mkdir "${POLDIR}" ; fi
	cd "${POLDIR}"/
	if [ ${REBUILD} -ge 1 ]; then
		cmake ../ -GNinja \
			-DMLIR_DIR=$(pwd)/../"${MLIRDIR}"/lib/cmake/mlir \
			-DLLVM_EXTERNAL_LIT=$(pwd)/../"${MLIRDIR}"/bin/llvm-lit \
			-DClang_DIR=$(pwd)/../"${MLIRDIR}"/lib/cmake/clang \
			-DCMAKE_BUILD_TYPE=Release
	fi
	ninja mlir-clang
	cd "${POLTERDIR}"/
fi

cat <<EOF > ${POLTERDIR}/../polygeist.env
export GCC_C_INCL="$(C_INCLUDE_PATH='' CPLUS_INCLUDE_PATH='' gcc -x c -E -v /dev/null 2>&1 | sed -n '/include.*search starts here/,/End of search list/{s#^ #-I#p}' | tr '\n' ' ')"
export GCC_CXX_INCL="$(C_INCLUDE_PATH='' CPLUS_INCLUDE_PATH='' gcc -x c++ -E -v /dev/null 2>&1 | sed -n '/include.*search starts here/,/End of search list/{s#^ #-I#p}' | tr '\n' ' ')"

export POLTER_DB_CCFLAGS=" \${GCC_CXX_INCL} -resource-dir=$(readlink -f ${POLTERDIR}/${MLIRDBDIR}/lib/clang/*) -I$(readlink -f ${POLTERDIR}/${MLIRDBDIR}/lib/clang/*)/include --cuda-lower --cuda-gpu-arch=sm_60 --cuda-path=\"\${CUDA_TOOLKIT_ROOT_DIR}\" -I\${CUDA_TOOLKIT_ROOT_DIR}/targets/x86_64-linux/include --function='*' "
#export POLTER_DB_LDFLAGS=" -L\${CUDA_TOOLKIT_ROOT_DIR}/lib64 -lcudart_static -ldl -lrt -lpthread -lm"
export POLTER_DB_LDFLAGS=" -L$HOME -l:libcpucudart.a -lstdc++ -L\${CUDA_TOOLKIT_ROOT_DIR}/lib64 -lcudart_static -ldl -lrt -lpthread -lm"
export POLTER_DB_CLANG="${POLTERDIR}/${POLDBDIR}/bin/mlir-clang"
export POLTER_DB_COMPILE="\${POLTER_DB_CLANG} \${POLTER_DB_CCFLAGS} \${POLTER_DB_LDFLAGS}"
export POLTER_DB_EMITLLVM="${POLTERDIR}/${MLIRDBDIR}/bin/clang -S -emit-llvm ${POLTER_DB_CCFLAGS} -I. -I${HOME}/pytorch/aten/src -I${HOME}/pytorch/torch/include "

export POLTER_CCFLAGS=" \${GCC_CXX_INCL} -resource-dir=$(readlink -f ${POLTERDIR}/${MLIRDIR}/lib/clang/*) -I\${CUDA_TOOLKIT_ROOT_DIR}/include -I\${CUDA_TOOLKIT_ROOT_DIR}/targets/x86_64-linux/include --function='*' "
export POLTER_LDFLAGS="\${POLTER_DB_LDFLAGS}"
export POLTER_CLANG="${POLTERDIR}/${POLDIR}/bin/mlir-clang"
export POLTER_COMPILE="\${POLTER_CLANG} \${POLTER_CCFLAGS} \${POLTER_LDFLAGS}"
export POLTER_EMITLLVM="${POLTERDIR}/${MLIRDIR}/bin/clang -S -emit-llvm ${POLTER_CCFLAGS} -I. -I${HOME}/pytorch/aten/src -I${HOME}/pytorch/torch/include "
export LLVM_SYMBOLIZER_PATH="${POLTERDIR}/${MLIRDIR}/bin/llvm-symbolizer"
export PCLANG_CC="${POLTERDIR}/${MLIRDIR}/bin/clang \${GCC_CXX_INCL} -resource-dir=$(readlink -f ${POLTERDIR}/${MLIRDIR}/lib/clang/*)"
export PCLANG_CXX="${POLTERDIR}/${MLIRDIR}/bin/clang++ \${GCC_CXX_INCL} -resource-dir=$(readlink -f ${POLTERDIR}/${MLIRDIR}/lib/clang/*)"
EOF
