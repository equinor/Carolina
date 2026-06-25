#!/bin/bash
set -eu

# The manylinux container runs as a different user than the host that owns
# /github/workspace. Without this, git (and setuptools_scm) refuses to operate.
git config --global --add safe.directory /github/workspace

if [ -z "${1:-}" ]; then
  echo "Please provide a Python version as an argument (e.g., 3.12)"
  exit 1
fi

PYTHON_VERSION_ARG="$1"

CAROLINA_DIR=$(pwd)
INSTALL_DIR=/github/workspace/deps_build

cd /tmp

python_exec=$(which "python${PYTHON_VERSION_ARG}")
"$python_exec" -m venv myvenv
source ./myvenv/bin/activate

pip install -U pip
pip install auditwheel
pip install pytest numpy
numpy_lib_dir=$(find /tmp/myvenv/ -name numpy.libs 2>/dev/null || echo "")
yum install lapack-devel -y

export PATH="$PATH:$INSTALL_DIR/bin"
export LD_LIBRARY_PATH="/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin${numpy_lib_dir:+:$numpy_lib_dir}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$CAROLINA_DIR"

pip install .
pip list | grep carolina

mkdir -p /tmp/wheels
mkdir -p /github/workspace/carolina_dist

pip wheel . -w wheelhouse
auditwheel repair wheelhouse/* -w /tmp/wheels

cp /tmp/wheels/carolina*whl /github/workspace/carolina_dist
ls -lah /github/workspace/carolina_dist

echo "Copied distributables and installation trace"
