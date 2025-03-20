#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Please provide a Python version as an argument (e.g., 3.10)"
  exit 1
fi

CAROLINA_DIR=$(pwd)
INSTALL_DIR=/github/workspace/deps_build

cd /tmp

python_exec=$(which python$1)
$python_exec -m venv myvenv
source ./myvenv/bin/activate

pip install pytest numpy
NUMPY_INCLUDE_PATH=$(find /tmp -type d -path "*site-packages/numpy/core/include")
numpy_lib_dir=$(find /tmp/myvenv/ -name numpy.libs)
yum install lapack-devel -y
yum install python3-devel.x86_64 -y

export PATH="$PATH:$INSTALL_DIR/bin"
export LD_LIBRARY_PATH="/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin:$numpy_lib_dir:$NUMPY_INCLUDE_PATH"

echo "-----"
ldd $INSTALL_DIR/bin/dakota
echo "-----"
ldd $INSTALL_DIR/lib/libdakota_src.so
echo "-----"
nm -gD $INSTALL_DIR/lib/libdakota_src.so | grep _PyThreadState_UncheckedGet
echo "-----"
nm -gD /usr/lib64/libpython3.6m.so.1.0 | grep _PyThreadState_UncheckedGet


cd $INSTALL_DIR/bin/
./dakota --version

cd $CAROLINA_DIR

pip install .
pip list | grep carolina

pytest tests

mkdir /tmp/wheels
mkdir /github/workspace/carolina_dist

pip wheel . -w wheelhouse
auditwheel repair wheelhouse/* -w /tmp/wheels

cp /tmp/wheels/carolina*whl /github/workspace/carolina_dist
ls -lah /github/workspace/carolina_dist

echo "Copied distributables and installation trace"
