#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"

cd ${SDIR}/../
WDIR="$(pwd)"

source ${WDIR}/init.env
CC="${MocCC}"
CXX="${MocCXX}"

#if [[ "$(hostname -s)" = "kiev"* ]]; then
#
#	MocHOST=kiev
#
#elif [[ "$(hostname -s)" = "epyc"* ]]; then
#
#	MocHOST=epyc
#
#elif lscpu | grep 'sve' >/dev/null 2>&1; then
#
#	MocHOST=fugaku
#
#else echo 'Err: unknown system; config please' ; exit 1 ; fi

#RedirectCUDA="-DUSE_MocCUDA=0" DEBUG="-DDEBUG -O0 -g" \
#make -j$(nproc) -f Makefile.${MocHOST} -B
#mv lib/libMocCUDA.so lib/libMocCUDA_passthru.so
#
#GrandCentralDispatch="-DUSE_GCD=0"  DEBUG="-DDEBUG" \
#make -j$(nproc) -f Makefile.${MocHOST} -B
#mv lib/libMocCUDA.so lib/libMocCUDA_seqdebug.so
#
#DEBUG="-DFUNC_TIMINGS" \
#make -j$(nproc) -f Makefile.${MocHOST} -B
#mv lib/libMocCUDA.so lib/libMocCUDA_fntiming.so
#
#DEBUG="-DGEMM_TIMINGS" \
#make -j$(nproc) -f Makefile.${MocHOST} -B
#mv lib/libMocCUDA.so lib/libMocCUDA_gemmtiming.so
#
#DEBUG="-DGEMM_TIMINGS -DFUNC_TIMINGS" \
#make -j$(nproc) -f Makefile.${MocHOST} -B
#mv lib/libMocCUDA.so lib/libMocCUDA_gemmfntiming.so

make -j$(nproc) -f Makefile.${MocHOST} -B
