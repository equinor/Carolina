pyDAKOTA
========

pyDAKOTA is an interface to Sandia Laboratory's Design Analysis Kit for Optimization and Terascale Applications (DAKOTA) analysis suite. 

Allows for users to construct DAKOTA input, feed the input to DAKOTA, and for DAKOTA to call a python object with a "dakota_callback" function for function evaluations.

This allows for a light-weight custom python interace to DAKOTA.

Author: [RRD](mailto:nrel.wisdem@gmail.com)

## Prerequisites

General: NumPy, OpenMDAO, DAKOTA

## Dependencies:

Supporting python packages: mpi4py

## Installation

### Install DAKOTA
First, [download DAKOTA](https://github.com/WISDEM/JacketSE) and [install from source](https://dakota.sandia.gov/content/using-builddakotatemplatecmake-script). Some CMAKE files are provided in the resources/ directory.

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

## +++ other notes +++

Materials for openMDAO DAKOTA Driver object
-------------------------------------------

(Original author, Peter Graf, National Renewable Energy Lab, 2012. peter.graf@nrel.gov)

Overview
--------
This directory tree contains the materials for the initial version of an openMDAO "Driver" object that wraps
Sandia Lab's "DAKOTA" optimization and analysis code.  There are three different functionalities:

1. An interface to DAKOTA, in "library mode", that allows passing an MPI communicator and a "void *" object
to DAKOTA. This is still in C++.

2. A python wrapper for this interface, so, in python, you can say "import dakota", then "dakota.run_dakota(comm, object)".
"comm" will be used as the MPI communicator for DAKOTA, and "object" will be passed _back_ to the python routine
specified in your dakota input file.

3. An openMDAO Driver object that wraps all this functionality.  In particular, the "object" in 2. _is_ the driver, 
and a specific callback function is used that then calls this driver's "run_iteration" method.  Therefore, from the
user's point of view, DAKOTA is made to behave as if it were a normal openMDAO driver.

Further development by NASA/openMDAO
------------------------------------
The code in this directory is prototype code that was then handed off to the openMDAO team at NASA for further development.
Therefore, if you are interested in the above functionality, this code is _not_ the code you should use.
Instead, you should go to openmdao.org and find the "dakota driver" plugin.  This README file will be updated to refer
to the exact url when it is available.

License
-------
This software is licensed under the Apache 2.0 license.  See "Apache2.0License.txt" in this directory.


Peter Graf, 7/26/13
