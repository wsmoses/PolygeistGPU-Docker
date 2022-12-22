#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
BMSN="$( basename "${BASH_SOURCE[0]:-$0}" )"

source ${SDIR}/../init.env

if [[ "${BACKEND}" = *"moccuda"* ]]; then
	PRELOADLIBS="/root/MocCUDA/lib/libMocCUDA.so:/usr/local/lib/libomp.so:/usr/lib/x86_64-linux-gnu/libopenblas.so"
	PRELOG="${BACKEND}"
	RUNVERS="--type gpu"
elif [[ "${BACKEND}" = *"moccuda-no-polygeist"* ]]; then
	PRELOADLIBS="/root/MocCUDA/lib/libMocCUDA-no-polygeist.so:/usr/local/lib/libomp.so:/usr/lib/x86_64-linux-gnu/libopenblas.so"
	PRELOG="${BACKEND}"
	RUNVERS="--type gpu"
elif [[ "${BACKEND}" = *"dnnl"* ]]; then
	PRELOG="${BACKEND}"
	RUNVERS="--type cpu_mkl"
	#RUNVERS="--type cpu_mkltensor"
elif [[ "${BACKEND}" = *"native"* ]]; then
	PRELOG="${BACKEND}"
	RUNVERS="--type cpu_nomkl"
else
	echo "ERR: requested backend not supported or does not exist" ; exit 1
fi

if [ -n "${PRELOADLIBS}" ]; then	PRELOAD="LD_PRELOAD=\"${PRELOADLIBS}\""
else					PRELOAD=""
fi

POW6="$(for x in $(seq 0 6); do echo $((2**x)) ; done)"
POW8="$(for x in $(seq 0 8); do echo $((2**x)) ; done)"
FAC6_48="$(seq 6 6 48)"
FAC12_288="6 $(seq 12 12 288)"

TMPLOG="/dev/shm/`hostname -s`-${BASHPID}"
RUNINFO="Time:\|samples_per_second"
LOGDIR="${SDIR}/../log" ; mkdir -p "${LOGDIR}"

cd "${BENCHMARKER_ROOT}"/
N=0
#for OMP in `echo ${POW6} ${FAC6_48} | sed -e 's/ /\n/g' | sort -n`; do
for OMP in 1 2 4 8 16 32; do
	#for BS in `echo ${POW8} ${FAC12_288} | sed -e 's/ /\n/g' | sort -n`; do
	for BS in 1 2 4 6 8 12; do
		LOG="${LOGDIR}/${BMSN}_${PRELOG}_cmg$((1+$N))_omp${OMP}.log"
		export OMP_NUM_THREADS=${OMP}
		echo "batch size: ${BS}  problem size: $((4*${BS}))  numa: 0  omp: ${OMP}  backend: ${BACKEND}" | tee -a ${LOG}
		timeout --kill-after=30s 10m bash -c "${PRELOAD} python3 -m benchmarker --framework=pytorch --problem=resnet50 --mode=training --problem_size=$((4*${BS})) --batch_size=${BS} ${RUNVERS}" > ${TMPLOG} 2>&1
		if [ "x$?" = "x137" ] || [ "x$?" = "x124" ]; then echo "OOM/time killer, stop here" >> ${LOG}; break; fi
		grep "${RUNINFO}" ${TMPLOG} | tee -a ${LOG}
		sleep 1
	done
done
