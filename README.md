# Carolina

Carolina is a [pyDAKOTA](https://github.com/wisdem/pyDAKOTA) fork maintained by Equinor.  Its raison d'être is to have easier building of a Python [Dakota](https://dakota.sandia.gov/) wrapper, without any MPI support. Carolina supports Python version 3.8, 3.9, 3.10, 3.11

## Installation
For Linux and MacOS: 

```pip install carolina```

Otherwise, build Carolina youself as described below.

## Building and installing Carolina
In order to build Carolina, [Boost](https://www.boost.org/), including Boost.Python, and [Dakota](https://dakota.sandia.gov/) must be installed. This requires [CMake](https://cmake.org/) and a C/C++ compiler. It is recommended to check the build scripts at `.github/workflows/bundle_with_dakota_*` where the full installation is described. The installation will likely vary across different operating systems. Roughly speaking, the following steps must be done:

1. Install CMAKE
2. Install Boost with correct python version (NOTE: you may need to edit the python version into the project-config.jam if on MacOS, see the excerpt from the MacOS install script below)

    ```bash
    python_version=$(python --version | sed -E 's/.*([0-9]+\.[0-9]+)\.([0-9]+).*/\1/')
    python_bin_include_lib="    using python : $python_version : $(python -c "from sysconfig import get_paths as gp; g=gp(); print(f\"$(which python) : {g['include']} : {g['stdlib']} ;\")")"
    sed -i '' "s|.*using python.*|$python_bin_include_lib|" project-config.jam
    ```
3. Install dakota
    * after downloading, replace `<DAKOTA_VERSION>` with the dakota version, for example 6.18 
    * In order to install Dakota to a specific folder, use `-DCMAKE_INSTALL_PREFIX="<INSTALL_DIR>"` as part of the cmake invocation.
    ```bash
    cd dakota-<DAKOTA_VERSION>-public-src-cli
    mkdir -p build
    cd build
    cmake \
        -DCMAKE_CXX_STANDARD=14 \
        -DBUILD_SHARED_LIBS=ON \
        -DDAKOTA_PYTHON_DIRECT_INTERFACE=ON \
        -DDAKOTA_PYTHON_DIRECT_INTERFACE_NUMPY=ON \
        -DDAKOTA_DLL_API=OFF \
        -DHAVE_X_GRAPHICS=OFF \
        -DDAKOTA_ENABLE_TESTS=OFF \
        -DDAKOTA_ENABLE_TPL_TESTS=OFF \
        -DCMAKE_BUILD_TYPE='Release' \
        -DDAKOTA_NO_FIND_TRILINOS:BOOL=TRUE \
        ..
    make -j4 install
    ```
    This step is the one that might be the most tricky to get working on your local OS. It expects a number of packages to be found, including `libgfortran`, `eigen`, `lapack`, `numpy`, and for the appropriate libraries to be on `LD_LIBRARY_PATH`(linux)/`DYLD_LIBRARY_PATH`(MacOS). Build errors often arise from (1) the package not being installed or (2) library folders/files of the installed package not being on the library path (`LD_LIBRARY_PATH` for linux  or `DYLD_LIBRARY_PATH` for MacOS).

4. After installing Dakota, it is possible to run `pip install .` as it will look for the following environment variables: 
* The `BOOST_ROOT` environment variable can be set to the location of the boost library containing the folders `include` and `lib`, if they are not already included globally.
* The `BOOST_PYTHON` can be set if a given version of `boost_python` is needed. For instance if Python 3.8 is to be used:

    ```bash
        export BOOST_PYTHON=boost_python38
    ```
    By default the installation script will try to guess the `boost_python` version from the minor version of Python, i.e. for Python 3.10, it will try `boost_python310`.

* It also expects `dakota` binary executable to be on the system `PATH`. To verify this, see if you can type `dakota` in the terminal and run it without errors. Then, try start up python and see if you can `import dakota`. If these two "tests" pass, you should be able to install Carolina.

Carolina can then be installed with:

```bash
    pip install .
```

The library can then be tested by entering the tests directory and execute:

```bash
    pytest
```

In the case of testing newer versions of Dakota, scripts can be found in the script folder.

Carolina requires Dakota 6.18, but will work with older versions as well.
Pathes can be reverted to allow for building against versions prior to 6.13 or 6.16.

From Dakota version 6.13 a different set of boost libraries is needed: instead of `boost_signals`, `boost_program_options` is used.
From Dakota version 6.16 a small change was made in the Python interface.
From Dakota version 6.18 a file was removed from the source and build script was altered.
