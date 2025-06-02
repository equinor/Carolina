#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Please provide a Python version as an argument (e.g., 3.10)"
  exit 1
fi

cd /tmp
INSTALL_DIR=/tmp/INSTALL_DIR

mkdir -p $INSTALL_DIR
mkdir /github/workspace/trace
touch /github/workspace/trace/boost_bootstrap.log
touch /github/workspace/trace/boost_install.log
touch /github/workspace/trace/dakota_bootstrap.log
touch /github/workspace/trace/dakota_install.log
touch /github/workspace/trace/env

# VERY IMPORTANT: extract python dev headers,
# more info: https://github.com/pypa/manylinux/pull/1250
pushd /opt/_internal && tar -xJf static-libs-for-embedding-only.tar.xz && popd

echo "pushd /opt/_internal && tar -xJf static-libs-for-embedding-only.tar.xz && popd" >> /github/workspace/trace/env
echo "INSTALL_DIR=$INSTALL_DIR" >> /github/workspace/trace/env

yum install lapack-devel wget -y
cd /tmp

BOOST_VERSION_UNDERSCORES=$(echo $BOOST_VERSION | sed 's/\./_/g')
wget --quiet https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION_UNDERSCORES}.tar.bz2 --no-check-certificate > /dev/null

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install $1

uv venv -p $1 myvenv
source ./myvenv/bin/activate
uv pip install numpy
uv pip install pybind11[global]
uv pip install "cmake<4"

NUMPY_INCLUDE_PATH=$(python3 -c "import numpy; print(numpy.get_include())")
PYTHON_INCLUDE_PATH=$(python -c "from sysconfig import get_paths; print(get_paths()['include'])")
python_root=$(python -c "import sys; print(sys.prefix)")
python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
python_version_no_dots="$(echo "${python_version//\./}")"
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$python_exec : {g['include']} : {g['stdlib']} ;\")")"
PYTHON_INCLUDE_DIR="$(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"{g['include']} \")")"

echo "Found dev headers $PYTHON_DEV_HEADERS_DIR"
echo "Found numpy include path $NUMPY_INCLUDE_PATH"
echo "Found python include path $PYTHON_INCLUDE_PATH"
echo "Found python root $python_root"
echo "Found PYTHON_INCLUDE_DIR $PYTHON_INCLUDE_DIR"

tar xf boost_$BOOST_VERSION_UNDERSCORES.tar.bz2
cd boost_$BOOST_VERSION_UNDERSCORES

echo "NUMPY_INCLUDE_PATH=$NUMPY_INCLUDE_PATH" >> /github/workspace/trace/env
echo "PYTHON_INCLUDE_PATH=$PYTHON_INCLUDE_PATH" >> /github/workspace/trace/env
echo "python_root=$python_root" >> /github/workspace/trace/env
echo "python_version=$python_version" >> /github/workspace/trace/env
echo "python_version_no_dots=$python_version_no_dots" >> /github/workspace/trace/env
echo "python_bin_include_lib=$python_bin_include_lib" >> /github/workspace/trace/env
echo "bootstrap_cmd=./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$(which python) --with-python-root=$python_root &> "$INSTALL_DIR/boost_bootstrap.log"" >> /github/workspace/trace/env

./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$(which python) --with-python-root="$python_root" &> "$INSTALL_DIR/boost_bootstrap.log"
sed -i -e "s|.*using python.*|$python_bin_include_lib|" project-config.jam
echo "# sed -i -e \"s|.*using python.*|$python_bin_include_lib|\" project-config.jam" >> /github/workspace/trace/env

./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" &> /github/workspace/trace/boost_install.log
echo "# ./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" &> /github/workspace/trace/boost_install.log" >> /github/workspace/trace/env

cd $INSTALL_DIR
DAKOTA_INSTALL_DIR=/tmp/INSTALL_DIR/dakota
mkdir -p $DAKOTA_INSTALL_DIR
echo "DAKOTA_INSTALL_DIR=$DAKOTA_INSTALL_DIR" >> /github/workspace/trace/env

wget https://github.com/snl-dakota/dakota/releases/download/v$DAKOTA_VERSION/dakota-$DAKOTA_VERSION-public-src-cli.tar.gz > /dev/null
tar xf dakota-$DAKOTA_VERSION-public-src-cli.tar.gz

CAROLINA_DIR=/github/workspace
cd dakota-$DAKOTA_VERSION-public-src-cli

patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists.txt.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/DakotaFindPython.cmake.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/workdirhelper_boost_filesystem.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists_includes.patch
mkdir build
cd build

export PATH=/tmp/INSTALL_DIR/bin:$PATH
export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_PATH /tmp/INSTALL_DIR/lib"
export PYTHON_EXECUTABLE=$(which python)

echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIRS=$PYTHON_INCLUDE_DIRS" >> /github/workspace/trace/env
echo "export PYTHON_EXECUTABLE=$PYTHON_EXECUTABLE" >> /github/workspace/trace/env

export BOOST_PYTHON="boost_python$python_version_no_dots"
export BOOST_ROOT=$INSTALL_DIR
export PATH="$PATH:$INSTALL_DIR/bin"

# More stable approach: Go via python
numpy_lib_dir=$(find /tmp/myvenv/ -name numpy.libs)
export PYTHON_LIBRARIES=$(python3 -c "import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")
export LD_LIBRARY_PATH="$PYTHON_LIBRARIES:/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin:/lib64:$numpy_lib_dir:$NUMPY_INCLUDE_PATH:$LD_LIBRARY_PATH"
export CMAKE_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed 's/::/:/g' | sed 's/:/;/g')
export CMAKE_LINK_OPTS="-Wl,--copy-dt-needed-entries, -lpthread"


echo "export BOOST_PYTHON=$BOOST_PYTHON" >> /github/workspace/trace/env
echo "export BOOST_ROOT=$BOOST_ROOT" >> /github/workspace/trace/env
echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /github/workspace/trace/env
echo "export CMAKE_LIBRARY_PATH=\"$CMAKE_LIBRARY_PATH\"" >> /github/workspace/trace/env
echo "export PYTHON_LIBRARIES=\"$PYTHON_LIBRARIES\"" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIR=\"$PYTHON_INCLUDE_DIR\"" >> /github/workspace/trace/env
echo "export CMAKE_LINK_OPTS=\"$CMAKE_LINK_OPTS\"" >> /github/workspace/trace/env

echo "Bootstrapping Dakota ..."
cmake \
  -DCMAKE_CXX_STANDARD=14 \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_CXX_FLAGS="-I$PYTHON_INCLUDE_DIR" \
  -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
  -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
  -DDAKOTA_DLL_API=OFF \
  -DHAVE_X_GRAPHICS=OFF \
  -DDAKOTA_ENABLE_TESTS=OFF \
  -DDAKOTA_ENABLE_TPL_TESTS=OFF \
  -DCMAKE_BUILD_TYPE="Release" \
  -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DPYTHON_LIBRARIES=$PYTHON_LIBRARIES \
  -DCMAKE_LINK_OPTIONS="$CMAKE_LINK_OPTS" \
  -DCMAKE_EXE_LINKER_FLAGS="-L${PYTHON_LIBRARIES} -lpython$1" \
  -DTHREADS_PREFER_PTHREAD_FLAG=ON \
  .. &> /github/workspace/trace/dakota_bootstrap.log

echo "# make --debug=b -j8 install" >> /github/workspace/trace/env
echo "Building Dakota ..."
make --debug=b -j8 install &> /github/workspace/trace/dakota_install.log


DEPS_BUILD=/github/workspace/deps_build

mkdir -p $DEPS_BUILD

cp -r $INSTALL_DIR/bin $DEPS_BUILD
cp -r $INSTALL_DIR/lib $DEPS_BUILD
cp -r $INSTALL_DIR/include $DEPS_BUILD
