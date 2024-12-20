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
yum install python3-devel.x86_64 -y
yum install -y wget
cd /tmp

BOOST_VERSION_UNDERSCORES=$(echo $BOOST_VERSION | sed 's/\./_/g')
wget https://boostorg.jfrog.io/artifactory/main/release/$BOOST_VERSION/source/boost_$BOOST_VERSION_UNDERSCORES.tar.bz2 --no-check-certificate > /dev/null
python_exec=$(which python$1)
$python_exec -m venv myvenv
source ./myvenv/bin/activate
pip install numpy==1.26.4
pip install pybind11[global]

PYTHON_DEV_HEADERS_DIR=$(rpm -ql python3-devel.x86_64 | grep '\.h$' | head -n 1 | xargs dirname)
NUMPY_INCLUDE_PATH=$(find /tmp -type d -path "*site-packages/numpy/core/include")
PYTHON_INCLUDE_PATH=$(python -c "from sysconfig import get_paths; print(get_paths()['include'])")
python_root=$(python -c "import sys; print(sys.prefix)")
python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
python_version_no_dots="$(echo "${python_version//\./}")"
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$python_exec : {g['include']} : {g['stdlib']} ;\")")"

echo "Found dev headers $PYTHON_DEV_HEADERS_DIR"
echo "Found numpy include path $NUMPY_INCLUDE_PATH"
echo "Found python include path $PYTHON_INCLUDE_PATH"
echo "Found python root $python_root"

tar xf boost_$BOOST_VERSION_UNDERSCORES.tar.bz2
cd boost_$BOOST_VERSION_UNDERSCORES

echo "python_exec=$python_exec" >> /github/workspace/trace/env
echo "PYTHON_DEV_HEADERS_DIR=$PYTHON_DEV_HEADERS_DIR" >> /github/workspace/trace/env
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

EIGEN_CMAKE_PATH=dakota-$DAKOTA_VERSION-public-src-cli/packages/external/eigen3/share/eigen3/cmake

# resolve issue where tar (v6.19) could contain corrupt Eigen3Config.cmake file
if [ ! -f $EIGEN_CMAKE_PATH/Eigen3Config.cmake ]; then
  mkdir temp_dakota
  cd temp_dakota
  wget --quiet --no-check-certificate \
    https://github.com/snl-dakota/dakota/releases/download/v$DAKOTA_VERSION/dakota-$DAKOTA_VERSION-public-src-cli.zip

  # extract file from zip archive only
  unzip dakota-$DAKOTA_VERSION-public-src-cli.zip
  cp $EIGEN_CMAKE_PATH/Eigen3Config.cmake ..
  cd ..
  rm -rf temp_dakota

  # replace the offending file
  rm $EIGEN_CMAKE_PATH/EIGEN3Config.cmake
  cp Eigen3Config.cmake $EIGEN_CMAKE_PATH
fi

cd dakota-$DAKOTA_VERSION-public-src-cli

patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/CMakeLists.txt.patch
patch -p1 < $CAROLINA_DIR/dakota_manylinux_install_files/DakotaFindPython.cmake.patch

mkdir build
cd build

export PATH=/tmp/INSTALL_DIR/bin:$PATH
export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_PATH $PYTHON_DEV_HEADERS_DIR /tmp/INSTALL_DIR/lib"
export PYTHON_EXECUTABLE=$(which python)
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:/usr/local/lib:$PYTHON_INCLUDE_PATH:$NUMPY_INCLUDE_PATH:$NUMPY_INCLUDE_PATH/numpy:$PYTHON_DEV_HEADERS_DIR:/tmp/INSTALL_DIR/lib:$LD_LIBRARY_PATH"

echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIRS=$PYTHON_INCLUDE_DIRS" >> /github/workspace/trace/env
echo "export PYTHON_EXECUTABLE=$PYTHON_EXECUTABLE" >> /github/workspace/trace/env

export BOOST_PYTHON="boost_python$python_version_no_dots"
export BOOST_ROOT=$INSTALL_DIR
export PATH="$PATH:$INSTALL_DIR/bin"

# More stable approach: Go via python
numpy_lib_dir=$(find /tmp/myvenv/ -name numpy.libs)
export LD_LIBRARY_PATH="/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin:$numpy_lib_dir:$NUMPY_INCLUDE_PATH"
export CMAKE_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed 's/::/:/g' | sed 's/:/;/g')
export PYTHON_LIBRARIES="/usr/lib64/"
export PYTHON_INCLUDE_DIR="/opt/_internal/cpython-3.7.17/include/python3.7m"
export CMAKE_LINK_OPTS="-Wl,--copy-dt-needed-entries,-l pthread"

echo "export BOOST_PYTHON=$BOOST_PYTHON" >> /github/workspace/trace/env
echo "export BOOST_ROOT=$BOOST_ROOT" >> /github/workspace/trace/env
echo "export PATH=$PATH" >> /github/workspace/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /github/workspace/trace/env
echo "export CMAKE_LIBRARY_PATH=\"$CMAKE_LIBRARY_PATH\"" >> /github/workspace/trace/env
echo "export PYTHON_LIBRARIES=\"$PYTHON_LIBRARIES\"" >> /github/workspace/trace/env
echo "export PYTHON_INCLUDE_DIR=\"$PYTHON_INCLUDE_DIR\"" >> /github/workspace/trace/env

cmake_command="""
cmake \
      -DCMAKE_CXX_STANDARD=14 \
      -DBUILD_SHARED_LIBS=ON \
      -DDAKOTA_PYTHON=ON \
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
      -DCMAKE_LINK_OPTIONS=\"$CMAKE_LINK_OPTS\" \
      .. &> "$INSTALL_DIR/dakota_bootstrap.log"

"""
echo "# $cmake_command" >> /github/workspace/trace/env

echo "Boostrapping Dakota ..."
$($cmake_command &> /github/workspace/trace/dakota_bootstrap.log)

echo "# make --debug=b -j8 install" >> /github/workspace/trace/env
echo "Building Dakota ..."
#make --debug=b -j8 install &> /github/workspace/trace/dakota_install.log
make --debug=b -j8 install

DEPS_BUILD=/github/workspace/deps_build

mkdir -p $DEPS_BUILD

cp -r $INSTALL_DIR/bin $DEPS_BUILD
cp -r $INSTALL_DIR/lib $DEPS_BUILD
cp -r $INSTALL_DIR/include $DEPS_BUILD
