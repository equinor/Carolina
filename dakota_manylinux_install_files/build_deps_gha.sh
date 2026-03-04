#!/bin/bash
set -euo pipefail


if [ -z "${1:-}" ]; then
  echo "Please provide a Python version as an argument (e.g., 3.10)"
  exit 1
fi

PYTHON_VERSION_ARG="$1"

cd /tmp
INSTALL_DIR=/tmp/INSTALL_DIR

mkdir -p "$INSTALL_DIR"
mkdir -p /github/workspace/trace
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

if [ -z "${BOOST_VERSION:-}" ]; then
  echo "ERROR: BOOST_VERSION environment variable is not set"
  exit 1
fi
if [ -z "${DAKOTA_VERSION:-}" ]; then
  echo "ERROR: DAKOTA_VERSION environment variable is not set"
  exit 1
fi

BOOST_VERSION_UNDERSCORES=$(echo "$BOOST_VERSION" | sed 's/\./_/g')
wget --quiet "https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION_UNDERSCORES}.tar.bz2" --no-check-certificate > /dev/null

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install "$PYTHON_VERSION_ARG"

uv venv -p "$PYTHON_VERSION_ARG" myvenv
source ./myvenv/bin/activate
uv pip install numpy
uv pip install "pybind11[global]"
uv pip install "cmake<4"

PYTHON_INCLUDE_PATH=$(python -c "from sysconfig import get_paths; print(get_paths()['include'])")
python_root=$(python -c "import sys; print(sys.prefix)")
python_version=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
python_version_no_dots="$(echo "${python_version//\./}")"
python_exec=$(which python)
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$python_exec : {g['include']} : {g['stdlib']} ;\")")"
PYTHON_INCLUDE_DIR="$(python -c "from sysconfig import get_paths as gp; g=gp(); print(g['include'])")"

echo "Found python include path $PYTHON_INCLUDE_PATH"
echo "Found python root $python_root"
echo "Found PYTHON_INCLUDE_DIR $PYTHON_INCLUDE_DIR"

tar xf "boost_${BOOST_VERSION_UNDERSCORES}.tar.bz2"
cd "boost_${BOOST_VERSION_UNDERSCORES}"

echo "PYTHON_INCLUDE_PATH=$PYTHON_INCLUDE_PATH" >> /github/workspace/trace/env
echo "python_root=$python_root" >> /github/workspace/trace/env
echo "python_version=$python_version" >> /github/workspace/trace/env
echo "python_version_no_dots=$python_version_no_dots" >> /github/workspace/trace/env
echo "python_bin_include_lib=$python_bin_include_lib" >> /github/workspace/trace/env

./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python="$python_exec" --with-python-root="$python_root" 2>&1 | tee "$INSTALL_DIR/boost_bootstrap.log"
sed -i -e "s|.*using python.*|$python_bin_include_lib|" project-config.jam

./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" 2>&1 | tee /github/workspace/trace/boost_install.log
cd "$INSTALL_DIR"
DAKOTA_INSTALL_DIR=/tmp/INSTALL_DIR/dakota
mkdir -p "$DAKOTA_INSTALL_DIR"
echo "DAKOTA_INSTALL_DIR=$DAKOTA_INSTALL_DIR" >> /github/workspace/trace/env

wget "https://github.com/snl-dakota/dakota/releases/download/v${DAKOTA_VERSION}/dakota-${DAKOTA_VERSION}-public-src-cli.tar.gz" > /dev/null
tar xf "dakota-${DAKOTA_VERSION}-public-src-cli.tar.gz"

CAROLINA_DIR=/github/workspace
cd "dakota-${DAKOTA_VERSION}-public-src-cli"

echo "Applying patches ..."
patch -p1 < "$CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists.txt.patch"
patch -p1 < "$CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists_includes.patch"

mkdir build
cd build

export PATH="/tmp/INSTALL_DIR/bin:$PATH"
export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_PATH /tmp/INSTALL_DIR/lib"
export PYTHON_EXECUTABLE="$python_exec"

export BOOST_PYTHON="boost_python${python_version_no_dots}"
export BOOST_ROOT="$INSTALL_DIR"
export PATH="$PATH:$INSTALL_DIR/bin"

# More stable approach: Go via python
numpy_lib_dir=$(find /tmp/myvenv/ -name numpy.libs 2>/dev/null || echo "")
export PYTHON_LIBRARIES=$(python -c "import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")
export LD_LIBRARY_PATH="$PYTHON_LIBRARIES:/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin:/lib64${numpy_lib_dir:+:$numpy_lib_dir}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export CMAKE_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | sed 's/::/:/g' | sed 's/:/;/g')

echo "export BOOST_PYTHON=$BOOST_PYTHON" >> /github/workspace/trace/env
echo "export BOOST_ROOT=$BOOST_ROOT" >> /github/workspace/trace/env
echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /github/workspace/trace/env
echo "export CMAKE_LIBRARY_PATH=\"$CMAKE_LIBRARY_PATH\"" >> /github/workspace/trace/env
echo "export PYTHON_LIBRARIES=\"$PYTHON_LIBRARIES\"" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIR=\"$PYTHON_INCLUDE_DIR\"" >> /github/workspace/trace/env
echo "export PYTHON_EXECUTABLE=\"$PYTHON_EXECUTABLE\"" >> /github/workspace/trace/env

echo "Bootstrapping Dakota ..."
cmake \
  -DCMAKE_CXX_STANDARD=17 \
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
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DPYTHON_LIBRARIES="$PYTHON_LIBRARIES" \
  -DCMAKE_EXE_LINKER_FLAGS="-L${PYTHON_LIBRARIES} -lpython${PYTHON_VERSION_ARG} -lpthread" \
  -DTHREADS_PREFER_PTHREAD_FLAG=ON \
  .. 2>&1 | tee /github/workspace/trace/dakota_bootstrap.log

echo "Building Dakota ..."
make -j8 install 2>&1 | tee /github/workspace/trace/dakota_install.log

DEPS_BUILD=/github/workspace/deps_build

mkdir -p "$DEPS_BUILD"

cp -r "$INSTALL_DIR/bin" "$DEPS_BUILD"
cp -r "$INSTALL_DIR/lib" "$DEPS_BUILD"
cp -r "$INSTALL_DIR/include" "$DEPS_BUILD"


