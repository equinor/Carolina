# Carolina

Carolina is a [pyDAKOTA](https://github.com/wisdem/pyDAKOTA) fork maintained by Equinor and TNO.  Its raison d'être is to have easier building of a Python [Dakota](https://dakota.sandia.gov/) wrapper, without any MPI support.

## Installation

Python version: Carolina supports Python version 3.6, 3.7, 3.8, 3.10

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

### Installation for Dakota version 6.13 or above

From Dakota version 6.13 a different set of boost libraries is needed: instead of `boost_signals`, `boost_program_options` is used. The Carolina setup script has not yet been updated to detect the Dakota version and use the correct library. Until then, apply the following patch to use Carolina with Dakota 6.13 and above:

```bash
    git apply dakota-6.13.patch
```

### Installation for Dakota version 6.16 or above

From Dakota version 6.16 a small change was made in the Python interface. To
support this, apply the following patches to use Carolina with Dakota 6.16 and
above:

```bash
    git apply dakota-6.13.patch
    git apply dakota-6.16.patch
```

### Installation for Dakota version 6.18 or above

From Dakota version 6.18 a file was removed from the source and build script was altered.
To support this, apply the following patches to use Carolina with Dakota 6.18 and
above:

```bash
    git apply dakota-6.13.patch
    git apply dakota-6.16.patch
    git apply dakota-6.18.patch
```
