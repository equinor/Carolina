yum install lapack-devel -y
yum install python3-devel.x86_64 -y
yum install -y wget
wget https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.bz2 --no-check-certificate

python_exec=$(which python3.10)

$python_exec -m venv myvenv
source ./myvenv/bin/activate
pip install numpy
pip install pybind11[global]

PYTHON_DEV_HEADERS_DIR=$(rpm -ql python3-devel.x86_64 | grep '\.h$' | head -n 1 | xargs dirname)
NUMPY_INCLUDE_PATH=$(find /tmp -type d -path "*site-packages/numpy/core/include") # $(python -c "import numpy; print(numpy.get_include())")
PYTHON_INCLUDE_PATH=$(python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
python_root=$(python -c "import sys; print(sys.prefix)")
python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
python_version_no_dots="$(echo "${python_version//\./}")"
python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$python_exec : {g['include']} : {g['stdlib']} ;\")")"

echo "Found dev headers $PYTHON_DEV_HEADERS_DIR"
echo "Found numpy include path $NUMPY_INCLUDE_PATH"
echo "Found python include path $PYTHON_INCLUDE_PATH"
echo "Found python root $python_root"

INSTALL_DIR=/tmp/INSTALL_DIR

mkdir -p $INSTALL_DIR
mkdir -p /tmp/trace
touch /tmp/trace/boost_boostrap.log
touch /tmp/trace/boost_install.log
touch /tmp/trace/dakota_bootstrap.log
touch /tmp/trace/dakota_install.log
touch /tmp/trace/env

tar xf boost_1_82_0.tar.bz2
cd boost_1_82_0

echo "python_exec=$python_exec" > /tmp/trace/env
echo "PYTHON_DEV_HEADERS_DIR=$PYTHON_DEV_HEADERS_DIR" >> /tmp/trace/env
echo "NUMPY_INCLUDE_PATH=$NUMPY_INCLUDE_PATH" >> /tmp/trace/env
echo "PYTHON_INCLUDE_PATH=$PYTHON_INCLUDE_PATH" >> /tmp/trace/env
echo "python_root=$python_root" >> /tmp/trace/env
echo "python_version=$python_version" >> /tmp/trace/env
echo "python_version_no_dots=$python_version_no_dots" >> /tmp/trace/env
echo "python_bin_include_lib=$python_bin_include_lib" >> /tmp/trace/env
echo "bootstrap_cmd=./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$(which python) --with-python-root=$python_root &> "/tmp/trace/boost_boostrap.log"" >> /tmp/trace/env

./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$(which python) --with-python-root="$python_root" &> "/tmp/trace/boost_boostrap.log"
#./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python-version=$python_version --with-python-root="$python_root"
sed -i -e "s|.*using python.*|$python_bin_include_lib|" project-config.jam
echo "sed -i -e \"s|.*using python.*|$python_bin_include_lib|\" project-config.jam" >> /tmp/trace/env

./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" &> /tmp/trace/boost_install.log
echo "./b2 install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR" &> /tmp/trace/boost_install.log" >> /tmp/trace/env

cd $INSTALL_DIR
DAKOTA_INSTALL_DIR=/tmp/INSTALL_DIR/dakota
mkdir -p $DAKOTA_INSTALL_DIR
echo "DAKOTA_INSTALL_DIR=$DAKOTA_INSTALL_DIR" >> /tmp/trace/env

wget https://github.com/snl-dakota/dakota/releases/download/v6.18.0/dakota-6.18.0-public-src-cli.tar.gz
tar xf dakota-6.18.0-public-src-cli.tar.gz

rm -f dakota-6.18.0-public-src-cli/CMakeLists.txt
cp ../CMakeLists.txt dakota-6.18.0-public-src-cli/CMakeLists.txt

cd dakota-6.18.0-public-src-cli
mkdir build
cd build

export PATH=/tmp/INSTALL_DIR/bin:$PATH
export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_PATH $PYTHON_DEV_HEADERS_DIR /tmp/INSTALL_DIR/lib"
export PYTHON_EXECUTABLE=$(which python)
export LD_LIBRARY_PATH="$PYTHON_INCLUDE_PATH:$NUMPY_INCLUDE_PATH:$NUMPY_INCLUDE_PATH/numpy:$PYTHON_DEV_HEADERS_DIR:/tmp/INSTALL_DIR/lib:$LD_LIBRARY_PATH"

echo "export PATH=$PATH" >> /tmp/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /tmp/trace/env
echo "export PYTHON_INCLUDE_DIRS=$PYTHON_INCLUDE_DIRS" >> /tmp/trace/env
echo "export PYTHON_EXECUTABLE=$PYTHON_EXECUTABLE" >> /tmp/trace/env

export BOOST_PYTHON="boost_python$python_version_no_dots"
export BOOST_ROOT=$INSTALL_DIR
export PATH="$PATH:$INSTALL_DIR/bin"

# More stable approach: Go via python
numpy_lib_dir=$(realpath $(dirname $(find . -name libgfortran*.so*)))
export LD_LIBRARY_PATH="/usr/lib:/usr/lib64:$INSTALL_DIR/lib:$INSTALL_DIR/bin:$numpy_lib_dir:$NUMPY_INCLUDE_PATH"
export CMAKE_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed 's/:/;/g')

echo "export BOOST_PYTHON=$BOOST_PYTHON" >> /tmp/trace/env
echo "export BOOST_ROOT=$BOOST_ROOT" >> /tmp/trace/env
echo "export PATH=$PATH" >> /tmp/trace/env
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /tmp/trace/env
echo "export CMAKE_LIBRARY_PATH=$CMAKE_LIBRARY_PATH" >> /tmp/trace/env

cmake_command="""
cmake \
      -DCMAKE_CXX_STANDARD=14 \
      -DBUILD_SHARED_LIBS=ON \
      -DDAKOTA_DLL_API=OFF \
      -DPython_EXECUTABLE=$(which python) \
      -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
      -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
      -DDAKOTA
      -DHAVE_X_GRAPHICS=OFF \
      -DDAKOTA_ENABLE_TESTS=OFF \
      -DDAKOTA_ENABLE_TPL_TESTS=OFF \
      -DCMAKE_BUILD_TYPE="Release" \
      -DDAKOTA_PYTHON_SURROGATES:BOOL=TRUE \
      -DDAKOTA_PYBIND11:BOOL=TRUE \
      -DPYTHON_EXECUTABLE=$(which python) \
      -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
      -DPython_NumPy_INCLUDE_DIRS=\"$NUMPY_INCLUDE_PATH\" \
      -DPython_INCLUDE_DIRS=\"$PYTHON_INCLUDE_DIRS\" \
      -DLINK_DIRECTORIES="/usr/lib64" \
      ..
"""
echo $cmake_command >> /tmp/trace/env

$($cmake_command &> /tmp/trace/dakota_bootstrap.log)

make --debug=b -j8 install &> /tmp/trace/dakota_install.log
echo "make --debug=b -j8 install" >> /tmp/trace/env

cd $INSTALL_DIR/..



git clone https://usr:token@github.com/equinor/Carolina.git
cd Carolina
pip install .

pip wheel . -w wheelhouse
auditwheel repair wheelhouse/* -w dist

# TODO Test that wheel works, and upload dist stuff to pypi
