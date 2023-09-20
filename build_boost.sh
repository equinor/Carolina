#!/bin/bash

INSTALL_DIR=/tmp/INSTALL_DIR

mkdir -p $INSTALL_DIR

yum install -y wget
wget https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.bz2 --no-check-certificate
tar xf boost_1_82_0.tar.bz2
cd boost_1_82_0

./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=/opt/python/cp311-cp311/bin/python3 --with-python-root=/opt/python/cp311-cp311/

./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR"

