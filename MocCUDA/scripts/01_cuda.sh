#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"

cd ${SDIR}/../dep ; mkdir -p install
WDIR="$(pwd)"

cd ${WDIR}/install
ln -s ${CUDA_TOOLKIT_ROOT_DIR} cuda
#ln -s ${CUDNN_ROOT} cudnn
#ln -s ${NCCL_ROOT} nccl

