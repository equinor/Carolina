#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Please provide a Python version as an argument (e.g., 3.13)"
  exit 1
fi

# Set up environment
INSTALL_DIR=/github/workspace/deps_build

# Create directories and log files
mkdir -p $INSTALL_DIR
mkdir -p /github/workspace/trace
touch /github/workspace/trace/boost_bootstrap.log
touch /github/workspace/trace/boost_install.log
touch /github/workspace/trace/dakota_bootstrap.log
touch /github/workspace/trace/dakota_install.log
touch /github/workspace/trace/env

# VERY IMPORTANT: extract python dev headers,
# more info: https://github.com/pypa/manylinux/pull/1250
pushd /opt/_internal && tar -xJf static-libs-for-embedding-only.tar.xz && popd

# Install dependencies
yum install -y lapack-devel wget gcc-c++ gcc
yum install -y glibc-devel libstdc++-devel

# Set up Python environment
python_exec=$(which python$1)
echo "Using Python executable: $python_exec"
$python_exec -m venv /tmp/myvenv
source /tmp/myvenv/bin/activate

# Install Python dependencies
pip install -U pip
pip install numpy
pip install pybind11[global]
pip install "cmake<3.25"  # More stable CMake version

# Build Boost
cd /tmp
BOOST_VERSION_UNDERSCORES=$(echo $BOOST_VERSION | sed 's/\./_/g')
wget --quiet https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION_UNDERSCORES}.tar.bz2 --no-check-certificate
tar xf boost_${BOOST_VERSION_UNDERSCORES}.tar.bz2
cd boost_${BOOST_VERSION_UNDERSCORES}

# Get Python paths using Python itself - more reliable
PYTHON_EXECUTABLE=$(which python)
PYTHON_VERSION=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
PYTHON_VERSION_NODOTS=${PYTHON_VERSION//./}
PYTHON_INCLUDE_DIR=$(python -c "from sysconfig import get_paths as gp; print(gp()['include'])")
PYTHON_STDLIB_DIR=$(python -c "from sysconfig import get_paths as gp; print(gp()['stdlib'])")
NUMPY_INCLUDE_PATH=$(python -c "import numpy; print(numpy.get_include())")

echo "Python executable: $PYTHON_EXECUTABLE"
echo "Python version: $PYTHON_VERSION"
echo "Python include directory: $PYTHON_INCLUDE_DIR"
echo "Python stdlib directory: $PYTHON_STDLIB_DIR"
echo "NumPy include path: $NUMPY_INCLUDE_PATH"

# Configure Boost with Python
python_bin_include_lib="    using python : $PYTHON_VERSION : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$PYTHON_EXECUTABLE : {g['include']} : {g['stdlib']} ;\")")"
./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$PYTHON_EXECUTABLE &> /github/workspace/trace/boost_bootstrap.log

# Update the Boost Python configuration
sed -i -e "s|.*using python.*|$python_bin_include_lib|" project-config.jam
./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" &> /github/workspace/trace/boost_install.log

# Download and build Dakota
cd /tmp
wget --quiet https://github.com/snl-dakota/dakota/releases/download/v$DAKOTA_VERSION/dakota-$DAKOTA_VERSION-public-src-cli.tar.gz
tar xf dakota-$DAKOTA_VERSION-public-src-cli.tar.gz

# Apply patches
cd dakota-$DAKOTA_VERSION-public-src-cli
CAROLINA_DIR=/github/workspace
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists.txt.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/DakotaFindPython.cmake.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/workdirhelper_boost_filesystem.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists_includes.patch

# Create build directory
mkdir -p build
cd build

# Set up environment variables for build
export PATH="$INSTALL_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PYTHON_STDLIB_DIR:/usr/lib:/usr/lib64:$INSTALL_DIR/lib"
export BOOST_ROOT="$INSTALL_DIR"
export BOOST_PYTHON="boost_python$PYTHON_VERSION_NODOTS"
export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_DIR"

export PYTHON_EMBEDDING_LDFLAGS=$(python -c "import sysconfig; print(sysconfig.get_config_var('LDFLAGS') or '')")
export PYTHON_EMBEDDING_CFLAGS=$(python -c "import sysconfig; print(sysconfig.get_config_var('CFLAGS') or '')")
PYTHON_LINK_FLAGS="-Wl,-Bstatic -lpython${PYTHON_VERSION} -Wl,-Bdynamic"

set +e
# Clean CMake command with proper Python detection
cmake \
  -DCMAKE_CXX_STANDARD=14 \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_CXX_FLAGS="-I$PYTHON_INCLUDE_DIR -pthread -fPIC" \
  -DCMAKE_EXE_LINKER_FLAGS="-Wall -pthread -lutil $PYTHON_LINK_FLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wall -pthread -lutil $PYTHON_LINK_FLAGS" \
  -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
  -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
  -DDAKOTA_DLL_API=OFF \
  -DHAVE_X_GRAPHICS=OFF \
  -DDAKOTA_ENABLE_TESTS=OFF \
  -DDAKOTA_ENABLE_TPL_TESTS=OFF \
  -DCMAKE_BUILD_TYPE="Release" \
  -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DPYTHON_EXECUTABLE="$PYTHON_EXECUTABLE" \
  -DPYTHON_INCLUDE_DIR="$PYTHON_INCLUDE_DIR" \
  -DTHREADS_PREFER_PTHREAD_FLAG=ON \
  ..

if [ $? -ne 0 ]; then
  echo "CMake configuration failed. Printing error logs:"
  cat CMakeFiles/CMakeError.log
  cat CMakeFiles/CMakeOutput.log
  exit 1
fi

# Build and install Dakota
echo "Building Dakota..."
make -j8 install

if [ $? -ne 0 ]; then
  echo "Make failed. Printing last 200 lines of build log:"
  tail -n 200 /github/workspace/trace/dakota_install.log
  exit 1
fi

echo "Build completed successfully!"
