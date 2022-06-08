#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"
source "${SDIR}/../dep/python.env"

cd ${SDIR}/../dep/benchmarker
BENCHDIR=$(pwd)

git submodule update --init --recursive
git checkout -- \
	./requirements.txt \
	./benchmarker/modules/do_pytorch.py \
	./benchmarker/modules/do_numpy.py \
	./benchmarker/modules/do_torch.py \
	./benchmarker/modules/problems/bert/data.py \
	./benchmarker/modules/problems/bert_custom/data.py \
	./benchmarker/modules/problems/cnn2d_toy/chainer.py \
	./benchmarker/modules/problems/gru/data.py \
	./benchmarker/modules/problems/lstm/data.py \
	./benchmarker/modules/problems/lstm_char1/data.py \
	./benchmarker/modules/problems/lstm_char1/keras.py \
	./benchmarker/modules/problems/images_randomized.py \
	./benchmarker/util/data/__init__.py \
	./benchmarker/util/data/cifar10.py \
	./benchmarker/util/data/cubes.py \
	./benchmarker/util/data/synthetic/conv.py \
	./benchmarker/util/data/synthetic/helpers.py \
	./benchmarker/util/data/synthetic/img_224_segmentation.py \
	./benchmarker/benchmarker.py

sed -i -e 's/params\["device"\] = params\["platform"\]\["gpus"\]\[0\]\["brand"\]/params["device"] = "moccuda"/' ./benchmarker/benchmarker.py

#need some repeatability
sed -i -e '/^import torch$/a\torch.manual_seed(0)' ./benchmarker/modules/do_pytorch.py
for FILE in $(/bin/grep -r 'import numpy' benchmarker | cut -d ':' -f1 | sort -u); do
	sed -i -e '/^import numpy as np/a\np.random.seed(0)' $FILE
done
#bound the loss a bit to avoid mess
sed -i -e 's/model.parameters(), lr=0.001/model.parameters(), lr=0.0001/g' ./benchmarker/modules/do_pytorch.py
sed -i -e 's/shape).astype(np.float32)$/shape).astype(np.float32) - 0.5/g' ./benchmarker/util/data/synthetic/helpers.py

	sed -i -e 's/cpu, hdd, ram, swap/all/g' requirements.txt
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	python3 -m pip install --upgrade -r requirements.txt
	#CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	#python3 -m pip install --upgrade -r requirements_gpu.txt
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	python3 -m pip install --upgrade pip
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	python3 -m pip install --upgrade pillow
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	python3 -m pip install --upgrade --no-deps torchvision==0.5.0
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	python3 -m pip install --upgrade transformers
	#some bug...
	sed -i -e '/assert/i\    if isinstance(raw_value, int): raw_value=str(raw_value)' ${VENV_SITEPACKAGES}/system_query/cpu_info.py
	#and some more bugs
	CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
	python3 -m pip install --upgrade pycuda==2020.1

cat <<EOF > ${SDIR}/../dep/benchmarker.env
export BENCHMARKER_ROOT=${BENCHDIR}
EOF
if [ -n "${JPEG_ROOT}" ]; then
cat <<EOF >> ${SDIR}/../dep/benchmarker.env
export LD_LIBRARY_PATH="\${LD_LIBRARY_PATH}:${JPEG_ROOT}/lib"
EOF
fi

#LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SDIR}/../dep/pytorch/ssl2/lib:${SDIR}/../dep/install/jpeg/lib" OMP_NUM_THREADS=1 KMP_WARNINGS=0 python3 -m benchmarker --mode=training --framework=pytorch --problem=resnet50 --problem_size=32 --batch_size=4 --backend=native
#echo LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SDIR}/../dep/pytorch/ssl2/lib:${SDIR}/../dep/install/jpeg/lib" OMP_NUM_THREADS=1 python3 -m benchmarker.benchmarker --mode=training --framework=pytorch --problem=resnet50 --problem_size=32 --batch_size=4 --backend=native  >./a.sh ; chmod +x ./a.sh ; echo -e 'run\nbacktrace\n' >cmd.f ; rm -rf ./gdbx ; mpiexec -gdbx "$(pwd)/cmd.f" -fjdbg-out-dir "$(pwd)" -n 1 bash -c ./a.sh
#LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SDIR}/../dep/pytorch/ssl2/lib:${SDIR}/../dep/install/jpeg/lib" OMP_NUM_THREADS=1 python3 -m benchmarker.benchmarker --problem=gemm --problem_size=128 --framework=torch
#LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SDIR}/../dep/pytorch/ssl2/lib:${SDIR}/../dep/install/jpeg/lib" LD_PRELOAD=$HOME/fake_a64fx_cuda/lib/libMocCUDA.so OMP_NUM_THREADS=48 python3 -m benchmarker --mode=training --framework=pytorch --problem=resnet50 --problem_size=32 --batch_size=4 --gpu 0
#LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${TORCH_BUILD_ROOT}/ssl2/lib:${TORCH_BUILD_ROOT}/../install/jpeg/lib" LD_PRELOAD=$HOME/fake_a64fx_cuda/lib/libMocCUDA_seqdebug.so OMP_NUM_THREADS=48 KMP_WARNINGS=0 python3 -m benchmarker --mode=training --framework=pytorch --problem=resnet50 --problem_size=32 --batch_size=4 --gpu 0
