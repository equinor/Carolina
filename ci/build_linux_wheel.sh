#!/bin/bash
set -euo pipefail

case "$1" in
    3.6) pyver=cp36-cp36m ;;
    3.7) pyver=cp37-cp37m ;;
    3.8) pyver=cp38-cp38 ;;
    3.9) pyver=cp39-cp39 ;;
    3.10) pyver=cp310-cp310 ;;
    *)
        echo "Unknown Python version $1"
        exit 1
        ;;
esac

git config --global --add safe.directory /github/workspace

# Install dependencies
yum install -y openmpi-devel lapack
export CFLAGS="-I/usr/include/openmpi-x86_64"
export CXXFLAGS="-I/usr/include/openmpi-x86_64"

# Install boost
yum install -y boost-devel boost-python36-devel boost169-devel

# Download dakota
dakota_ver=6.16.0
dakota_dir=dakota-${dakota_ver}-public-rhel7.Linux.x86_64-cli
curl -O https://dakota.sandia.gov/sites/default/files/distributions/public/${dakota_dir}.tar.gz
tar xf ${dakota_dir}.tar.gz
export PATH=$(realpath "${dakota_dir}/bin"):$PATH
export LD_LIBRARY_PATH=$(realpath "${dakota_dir}/lib")

# Build wheel
cd /github/workspace
/opt/python/$pyver/bin/pip wheel . --no-deps -w wheelhouse
auditwheel repair wheelhouse/* -w dist
