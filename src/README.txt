pyDAKOTA
========

pyDAKOTA is an interface to Sania's Design Analysis Kit for Optimization and Terascale Applications (DAKOTA) analysis suite. 

Allows for users to construct DAKOTA input, feed the input to DAKOTA, and for DAKOTA to call a python object with a "dakota_callback" function for function evaluations.

This allows for a light-weight custom python interace to DAKOTA.

Author: [RRD](mailto:nrel.wisdem@gmail.com)

## Prerequisites

General: NumPy, OpenMDAO, DAKOTA

## Dependencies:

Supporting python packages: mpi4py

## Installation

### Install DAKOTA
First, [download DAKOTA](https://github.com/WISDEM/JacketSE) and [install from source](LINK). Some CMAKE files are provided in the resources/ directory.

Find a cmake file which works for your system, then install DAKOTA with the following commands (this assumes an osx environment):

    $ wget https://dakota.sandia.gov/sites/default/files/distributions/public/dakota-6.2-public.src.tar.gz
    $ tar -zxvf dakota-6.2-public.src.tar.gz
    $ cd dakota-6.2.0.src/
    $ wget https://raw.githubusercontent.com/WISDEM/pyDAKOTA/master/resources/BuildDarwinPG.cmake # for osx
    $ <Add linux option>
    $ mkdir build
    $ cd build
    $ cmake -C ../BuildDarwinPG.cmake ../.
    $ make -j 4
    $ make install
    $ export DAK_INSTALL=/usr/local/dakota
    $ export PATH=$PATH:$DAK_INSTALL/bin:$DAK_INSTALL/test:$DAK_INSTALL/lib
    $ export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:$DAK_INSTALL/bin:$DAK_INSTALL/lib

### Install pyDAKOTA

    $ cd pyDAKOTA/src
    $ python setup.py install

## Run Unit Tests

To check if installation was successful try to run the pyDAKOTA test script

    $ python test_dakface.py

For software issues please use <https://github.com/WISDEM/pyDAKOTA/issues> or email nrel.wisdem@gmail.com. 

+++++++ Previous README +++++++

pyDAKOTA: a Python wrapper for DAKOTA
-------------------------------------

This is a generic Python wrapper for DAKOTA originally written by
Peter Graf, National Renewable Energy Lab, 2012. peter.graf@nrel.gov.
That code combined both the generic wrapper and an OpenMDAO 'driver'
which used the wrapper. For maintenance reasons, the code has been split
into this generic portion usable by any Python program, and a separate
OpenMDAO driver plugin.

The original code is at https://github.com/NREL/DAKOTA_plugin.
The file dakface.pdf provides some background on how the original code
was structured, and is generally valid with this updated version.

The OpenMDAO driver using this code is at
https://github.com/OpenMDAO-Plugins/dakota-driver.


This code provides:

1. An interface to DAKOTA, in "library mode", that supports passing to DAKOTA
argc/argv for the command-line, an optional MPI communicator, and a pointer
to a Python exception object. This is still in C++.

2. A Python wrapper for this interface, so, in Python, you can say
"import dakota", then "dakota.DakotaBase().run_dakota(mpi_comm=comm)".
"comm" will be used as the MPI communicator for DAKOTA, and
DakotaBase.dakota_callback() will be called by DAKOTA for function evaluations.

The deliverable is a Python 'egg'. If your environment is properly configured,
you can use this to build the egg:

    python setup.py bdist_egg -d .

To install the egg (easy_install is from setuptools):

    easy_install pyDAKOTA-6.0_1-py2.7-linux-x86_64.egg

To run a trivial test:

    python -m test_dakota

This has been tested on Linux and Windows. Cygwin has also been sucessfully
built in the past.


Requirements
------------

To build you'll need DAKOTA 6.0+ (svn trunk >= 2707).

To install, just use easy_install or pip to install the egg. All non-system
libraries are provided. DAKOTA graphics is disabled for both LInux and Windows.


License
-------
This software is licensed under the Apache 2.0 license.
See "Apache2.0License.txt" in this directory.


C++ source code:
----------------
dakface.cpp:  This is the library entry point.  It runs DAKOTA in 'sandwich'
mode where the caller provides input and DAKOTA calls-back to perform function
evaluations.

dakota_python_binding.cpp:  This is the boost wrapper that exposes the
functions in dakface.cpp to python.
