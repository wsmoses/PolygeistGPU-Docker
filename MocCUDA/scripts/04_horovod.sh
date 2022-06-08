#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"
source "${SDIR}/../dep/python.env"

cd ${SDIR}/../dep/horovod
HOROVODDIR=$(pwd)

buildDEBUG=0
buildRELEASE=1

python3 -m pip install --upgrade cffi==1.15.0	#XXX: update first, otherwise horovod tries and fails
python3 -m pip install --upgrade pytest==5.4.3
python3 -m pip install --upgrade mock==3.0.5

git submodule update --init --recursive
git checkout -- \
	./setup.py

if [ ${buildDEBUG} -ge 1 ]; then
	rm -rf build
	CC="${MocCC}" CFLAGS="-UNDEBUG -g -O2" CXX="${MocCXX}" CXXFLAGS="-UNDEBUG -g -O2" \
		HOROVOD_WITH_PYTORCH=1 HOROVOD_WITH_MPI=0 HOROVOD_WITHOUT_GLOO=1 \
		HOROVOD_WITHOUT_TENSORFLOW=1 HOROVOD_WITHOUT_MXNET=1 \
		HOROVOD_CUDA_HOME="${CUDA_TOOLKIT_ROOT_DIR}" HOROVOD_GPU=CUDA \
		python3 setup.py bdist_wheel 2>&1 | tee comp_debug
	mkdir -p debug_dist ; mv dist/horovod-*.whl debug_dist/
fi

if [ ${buildRELEASE} -ge 1 ]; then
	rm -rf build
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
		HOROVOD_WITH_PYTORCH=1 HOROVOD_WITH_MPI=0 HOROVOD_WITHOUT_GLOO=1 \
		HOROVOD_WITHOUT_TENSORFLOW=1 HOROVOD_WITHOUT_MXNET=1 \
		HOROVOD_CUDA_HOME="${CUDA_TOOLKIT_ROOT_DIR}" HOROVOD_GPU=CUDA \
		python3 setup.py bdist_wheel 2>&1 | tee comp_release
	#XXX: "if you have a proprietary MPI implementation with GPU support..." NO!!!
	#HOROVOD_GPU_ALLREDUCE=MPI HOROVOD_GPU_ALLGATHER=MPI \
		#HOROVOD_GPU_BROADCAST=MPI HOROVOD_CPU_OPERATIONS=MPI \
		fi

cd "${SDIR}"/   # step outside build dir to prevent strange pip issues
if ! python3 -m pip list | grep horovod >/dev/null 2>&1 ; then
	python3 -m pip install --upgrade "${HOROVODDIR}"/dist/horovod-*.whl
else
	python3 -m pip install --upgrade --force-reinstall --no-deps "${HOROVODDIR}"/dist/horovod-*.whl
fi

#from official repo:
# python3 -m pip install --upgrade pytest==5.4.3
# python3 -m pip install --upgrade mock==3.0.5
# HOROVOD_WITHOUT_GLOO=1 python3 -m pip install \
#	--upgrade --force-reinstall --no-deps --no-cache-dir 'horovod[pytorch]==0.19.5'
# mpirun -x PATH -x LD_LIBRARY_PATH -np 2 -mca btl ^openib \
#	pytest -v --capture=no ./dep/horovod/test/test_torch.py
# mpirun -x PATH -x LD_LIBRARY_PATH -H kiev2,kiev3 -np 2 \
#	pytest -v --capture=no ./dep/horovod/test/test_torch.py
