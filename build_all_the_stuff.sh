yum install lapack-devel -y
yum install python3-devel.x86_64 -y
yum install -y wget
wget https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.bz2 --no-check-certificate

python_exec=$(which python3.10)

$python_exec -m venv myvenv
source ./myvenv/bin/activate
pip install numpy
pip install pybind11[global]

NUMPY_INCLUDE_PATH=$(python -c "import numpy; print(numpy.get_include())")
PYTHON_INCLUDE_PATH=$(python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
python_root=$(python -c "import sys; print(sys.prefix)")

echo "Found numpy include path $NUMPY_INCLUDE_PATH"
echo "Found python include path $PYTHON_INCLUDE_PATH"
echo "Found python root $python_root"

INSTALL_DIR=/tmp/INSTALL_DIR

mkdir -p $INSTALL_DIR

tar xf boost_1_82_0.tar.bz2
cd boost_1_82_0

python_root=$($python_exec -c "import sys; print(sys.prefix)")
python_version=$($python_exec --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
python_version_no_dots="$(echo "${python_version//\./}")"
python_bin_include_lib="    using python : $python_version : $($python_exec -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$python_exec : {g['include']} : {g['stdlib']} ;\")")"

#./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python=$(which python) --with-python-root="$python_root"
./bootstrap.sh --with-libraries=python,filesystem,program_options,regex,serialization,system --with-python-version=$python_version
sed -i -e "s|.*using python.*|$python_bin_include_lib|" project-config.jam

./b2 headers --with-python
./b2 --with-python install -j8 -a cxxflags="-std=c++17" --prefix="$INSTALL_DIR"

cd $INSTALL_DIR
DAKOTA_INSTALL_DIR=/tmp/INSTALL_DIR/dakota
mkdir -p $DAKOTA_INSTALL_DIR


wget https://github.com/snl-dakota/dakota/releases/download/v6.18.0/dakota-6.18.0-public-src-cli.tar.gz
tar xf dakota-6.18.0-public-src-cli.tar.gz

rm -f dakota-6.18.0-public-src-cli/CMakeLists.txt
cp ../CMakeLists.txt dakota-6.18.0-public-src-cli/CMakeLists.txt

cd dakota-6.18.0-public-src-cli
mkdir build
cd build

export PATH=/tmp/INSTALL_DIR/bin:$PATH
export LD_LIBRARY_PATH=/tmp/INSTALL_DIR/lib:$LD_LIBRARY_PATH


export PYTHON_INCLUDE_DIRS="$PYTHON_INCLUDE_PATH $NUMPY_INCLUDE_PATH $NUMPY_INCLUDE_PATH/numpy"
export PYTHON_EXECUTABLE=$(which python)

cmake \
      -DCMAKE_CXX_STANDARD=14 \
      -DBUILD_SHARED_LIBS=ON \
      -DDAKOTA_DLL_API=OFF \
      -DHAVE_X_GRAPHICS=OFF \
      -DDAKOTA_ENABLE_TESTS=OFF \
      -DDAKOTA_ENABLE_TPL_TESTS=OFF \
      -DCMAKE_BUILD_TYPE="Release" \
      -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
      -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
      ..

make -j8 install

cd $INSTALL_DIR/..

export BOOST_PYTHON="boost_python$python_version_no_dots"
export BOOST_ROOT=$INSTALL_DIR
export PATH="$PATH:$INSTALL_DIR/bin"

# More stable approach: Go via python
numpy_lib_dir=$(realpath $(dirname $(find . -name libgfortran*.so*)))
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:$INSTALL_DIR/bin:$numpy_lib_dir"

git clone https://usr:token@github.com/equinor/Carolina.git
cd Carolina
pip install .

pip wheel . -w wheelhouse
auditwheel repair wheelhouse/* -w dist

# TODO Test that wheel works, and upload dist stuff to pypi
