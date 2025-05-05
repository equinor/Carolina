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

yum install lapack-devel -y
yum install -y wget
cd /tmp

# Find Python directory - more flexible pattern matching
PYTHON_VERSION_NO_DOTS="${1//./}"
echo "Looking for Python version: $1 (cp${PYTHON_VERSION_NO_DOTS})"

# List available Python dirs to debug
echo "Available Python directories:"
ls -la /opt/python/

# Try more flexible pattern matching
PYTHON_DIR="/opt/python/cp${PYTHON_VERSION_NO_DOTS}-cp${PYTHON_VERSION_NO_DOTS}"
PYTHON_EXECUTABLE="$PYTHON_DIR/bin/python"

echo "Using Python from: $PYTHON_DIR"

BOOST_VERSION_UNDERSCORES=$(echo $BOOST_VERSION | sed 's/\./_/g')
wget --quiet https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION_UNDERSCORES}.tar.bz2 --no-check-certificate > /dev/null
python_exec="$PYTHON_DIR/bin/python"
$python_exec -m venv myvenv
source ./myvenv/bin/activate
pip install -U pip
pip install numpy
pip install pybind11[global]
pip install "cmake<4"

PYTHON_DEV_HEADERS_DIR=$(python -c "from sysconfig import get_paths; print(get_paths()['include'])")
NUMPY_INCLUDE_PATH=$(find /tmp -type d -path "*site-packages/numpy/core/include")
PYTHON_INCLUDE_PATH=$(python -c "from sysconfig import get_paths; print(get_paths()['include'])")
python_root=$(python -c "import sys; print(sys.prefix)")
python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
python_version_no_dots="$(echo "${python_version//\./}")"
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$python_exec : {g['include']} : {g['stdlib']} ;\")")"
PYTHON_INCLUDE_DIR="$(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"{g['include']} \")")"
PYTHON_LIB_DIR="$(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"{g['stdlib']} \")")"

tar xf boost_$BOOST_VERSION_UNDERSCORES.tar.bz2
cd boost_$BOOST_VERSION_UNDERSCORES

# Added: Specify the Python version for bootstrap
./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$(which python) --with-python-version=$1
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
export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_PATH $PYTHON_DEV_HEADERS_DIR /tmp/INSTALL_DIR/lib"
export PYTHON_EXECUTABLE=$(which python)

echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIRS=$PYTHON_INCLUDE_DIRS" >> /github/workspace/trace/env
echo "export PYTHON_EXECUTABLE=$PYTHON_EXECUTABLE" >> /github/workspace/trace/env


# Check for the non-free-threaded Boost Python library
if [ -f "$INSTALL_DIR/lib/libboost_python313.so" ]; then
    export BOOST_PYTHON="boost_python313"
elif [ -f "$INSTALL_DIR/lib/libboost_python3.so" ]; then
    export BOOST_PYTHON="boost_python3"
else
    # Fall back to the standard naming pattern
    export BOOST_PYTHON="boost_python$python_version_no_dots"
fi
echo "Using Boost Python library: $BOOST_PYTHON"

export BOOST_ROOT=$INSTALL_DIR
export PATH="$PATH:$INSTALL_DIR/bin"

# More stable approach: Go via python
numpy_lib_dir=$(find /tmp/myvenv/ -name numpy.libs)
export LD_LIBRARY_PATH="$PYTHON_LIB_DIR:/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin:$numpy_lib_dir:$NUMPY_INCLUDE_PATH:$PYTHON_DEV_HEADERS_DIR"
export CMAKE_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed 's/::/:/g' | sed 's/:/;/g')

PYTHON_LIBRARY=$(python -c "import sysconfig; import os; print(os.path.join(sysconfig.get_config_var('LIBDIR'), sysconfig.get_config_var('LDLIBRARY')))")
export PYTHON_LIBRARIES="$PYTHON_LIBRARY"
echo "PYTHON_LIBRARIES: $PYTHON_LIBRARIES"

PYTHON_LIB_DIR=$(dirname "$PYTHON_LIBRARIES")
PYTHON_LIB_NAME=$(basename "$PYTHON_LIBRARIES" | sed 's/^lib//' | sed 's/\.a$//' | sed 's/\.so$//')
echo "Using Python library: $PYTHON_LIB_NAME from $PYTHON_LIB_DIR"

export PYTHON_INCLUDE_DIR=$PYTHON_DEV_HEADERS_DIR


# Add Python library to linker flags
export CMAKE_LINK_OPTS="-Wl,--copy-dt-needed-entries -lpthread -L${PYTHON_LIB_DIR} -l${PYTHON_LIB_NAME}"

echo "export BOOST_PYTHON=$BOOST_PYTHON" >> /github/workspace/trace/env
echo "export BOOST_ROOT=$BOOST_ROOT" >> /github/workspace/trace/env
echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /github/workspace/trace/env
echo "export CMAKE_LIBRARY_PATH=\"$CMAKE_LIBRARY_PATH\"" >> /github/workspace/trace/env
echo "export PYTHON_LIBRARIES=\"$PYTHON_LIBRARIES\"" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIR=\"$PYTHON_INCLUDE_DIR\"" >> /github/workspace/trace/env
echo "export CMAKE_LINK_OPTS=\"$CMAKE_LINK_OPTS\"" >> /github/workspace/trace/env

# First check if we have the static library (common in manylinux containers)
python_lib_file="$PYTHON_LIBRARIES"  # Use what sysconfig already found

# Display info about what Python libraries are available
echo "Available Python libraries:"
find "$PYTHON_DIR" -name "libpython*.so*" -o -name "libpython*.a"
find "/opt/_internal" -name "libpython*.so*" -o -name "libpython*.a"

# If we don't have a shared library (.so), but we do have a static one (.a), use that
if [[ "$python_lib_file" == *".a" ]]; then
    echo "Found static Python library: $python_lib_file"
    # For static libraries, we need to ensure all symbols are included during linking
    export CMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} -Wl,--whole-archive ${python_lib_file} -Wl,--no-whole-archive"
    export CMAKE_SHARED_LINKER_FLAGS="${CMAKE_SHARED_LINKER_FLAGS} -Wl,--whole-archive ${python_lib_file} -Wl,--no-whole-archive"
else
    echo "Found shared Python library: $python_lib_file"
fi

# Make sure Python libraries are correctly defined
export PYTHON_LIBRARIES="$python_lib_file"

# Debug: verify Python info
echo "Verifying Python information:"
echo "Python version: $(python --version)"
echo "Python interpreter: ${PYTHON_EXECUTABLE}"
echo "Python library: ${PYTHON_LIBRARIES}"
echo "Python include dir: ${PYTHON_INCLUDE_DIR}"
echo "Boost Python: ${BOOST_PYTHON}"
ls -l "${PYTHON_LIB_DIR}"/*python*

# Define all required system libraries in one place
export REQUIRED_LIBS="-lm -lpthread -ldl -lutil -lrt -lz"

# Update linker flags to include these libraries
export CMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} ${REQUIRED_LIBS}"
export CMAKE_SHARED_LINKER_FLAGS="${CMAKE_SHARED_LINKER_FLAGS} ${REQUIRED_LIBS}"

export CMAKE_POSITION_INDEPENDENT_CODE=ON
export CFLAGS="$CFLAGS -fPIC"
export CXXFLAGS="$CXXFLAGS -fPIC"

echo "Boostrapping Dakota ..."
cmake \
      -DCMAKE_CXX_STANDARD=14 \
      -DBUILD_SHARED_LIBS=ON \
      -DCMAKE_CXX_FLAGS="-I$PYTHON_INCLUDE_DIR" \
      -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" \
      -DCMAKE_SHARED_LINKER_FLAGS="${CMAKE_SHARED_LINKER_FLAGS}" \
      -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
      -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
      -DDAKOTA_DLL_API=OFF \
      -DHAVE_X_GRAPHICS=OFF \
      -DDAKOTA_ENABLE_TESTS=OFF \
      -DDAKOTA_ENABLE_TPL_TESTS=OFF \
      -DCMAKE_BUILD_TYPE="Release" \
      -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
      -DTHREADS_PREFER_PTHREAD_FLAG=ON \
      -DPython_LIBRARY="${PYTHON_LIBRARIES}" \
      -DPython_EXECUTABLE="${PYTHON_EXECUTABLE}" \
      -DPython_INCLUDE_DIRS="${PYTHON_INCLUDE_DIR}" \
      -DTHREADS_HAVE_PTHREAD_ARG=ON \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      ..

echo "# make --debug=b -j8 install" >> /github/workspace/trace/env
echo "Building Dakota ..."
make -j4 install

# Verify linking
echo "Verifying linking of final binaries..."
ldd $INSTALL_DIR/bin/dakota | grep python

DEPS_BUILD=/github/workspace/deps_build

mkdir -p $DEPS_BUILD

cp -r $INSTALL_DIR/bin $DEPS_BUILD
cp -r $INSTALL_DIR/lib $DEPS_BUILD
cp -r $INSTALL_DIR/include $DEPS_BUILD
