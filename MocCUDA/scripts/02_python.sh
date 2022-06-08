#!/bin/bash
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
source "${SDIR}/host.env"

cd ${SDIR}/../dep ; mkdir -p install
WDIR="$(pwd)"

cd ${WDIR}/install
rm -rf ./py3_venv
python3 -m venv py3_venv
source ./py3_venv/bin/activate

CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
python3 -m pip install --upgrade wheel
CC="${MocCC}" CFLAGS="${MocCFLAGS}" CXX="${MocCXX}" CXXFLAGS="${MocCXXFLAGS}" \
python3 -m pip install --upgrade cython

cat <<EOF > ${WDIR}/python.env
export PRELOADLIBS="${PRELOADLIBS}"
export VENV_ROOT=${WDIR}/install/py3_venv
source \${VENV_ROOT}/bin/activate
export VENV_SITEPACKAGES=\$(python -c 'import sys ; print([p for p in sys.path if "site-packages" in p][0])')
EOF
