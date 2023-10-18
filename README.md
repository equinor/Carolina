# Carolina

Carolina is a [pyDAKOTA](https://github.com/wisdem/pyDAKOTA) fork maintained by Equinor.  Its raison d'être is to have easier building of a Python [Dakota](https://dakota.sandia.gov/) wrapper, without any MPI support. Carolina supports Python version 3.8, 3.9, 3.10

## Installation
For Linux: 

```pip install carolina```

If not on Linux, build Carolina youself as described below.

## Building and installing Carolina
In order to build Carolina, [Boost](https://www.boost.org/), including Boost.Python, and [Dakota](https://dakota.sandia.gov/) must be installed. This requires [CMake](https://cmake.org/) and a C/C++ compiler.

The `BOOST_ROOT` environment variable can be set to the location of the boost library, if not in a default location.

The `BOOST_PYTHON` can be set if a given version of `boost_python` is needed. For instance if Python 3.8 is to be used:

```bash
    export BOOST_PYTHON=boost_python38
```

By default the installation script will try to guess the `boost_python` version from the minor version of Python, i.e. for Python 3.10, it will try `boost_python310`.

Carolina can then be installed with:

```bash
    pip install .
```

The library can then be tested by entering the tests directory and execute:

```bash
    pytest
```

Carolina requires Dakota 6.18, but will work with older versions as well.
Pathes can be reverted to allow for building against versions prior to 6.13 or 6.16.

From Dakota version 6.13 a different set of boost libraries is needed: instead of `boost_signals`, `boost_program_options` is used.
From Dakota version 6.16 a small change was made in the Python interface.
From Dakota version 6.18 a file was removed from the source and build script was altered.
