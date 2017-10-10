#!/usr/bin/env python
# Copyright 2013 National Renewable Energy Laboratory (NREL)
#           2017 Statoil ASA
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
# ++==++==++==++==++==++==++==++==++==++==
"""
Build carolina Python 'egg' for cygwin, darwin, linux, or win32 platforms.
Assumes DAKOTA has been installed.  The egg will include all libraries
included in the DAKOTA installation.

The cygwin platform is built using gcc.  It requires a cygwin Python.
This has only been tested on the build machine.

The darwin platform is built using mpicxx.  This currently has problems when
trying to load the egg.  It's probably related to DAKOTA delivering i386 only
and the machine attempting to run is x86_64 => Python executable attempting
to load is likely running as x86_64.

The linux platform is built using mpicxx.  Some linker magic is used to avoid
having to set LD_LIBRARY_PATH on the system the egg is installed on.
DAKOTA graphics has been disabled to reduce the number of library dependencies.
This is built on RHEL 6.4 to mimic the DAKOTA release, and has been tested on
RHEL 6.4 and Ubuntu 'pangolin'.

The win32 platform is built using VisualStudio C++ and Intel Fortran.
This has been tested on a 'vanilla' (no DAKOTA pre-installed) Windows machine.
"""

import os
import subprocess
import sys
import unittest

import numpy

from distutils.spawn import find_executable
from setuptools import setup
from setuptools.extension import Extension


CAROLINA_VERSION = '1.0'

# Assuming standard prefix-based install.
dakota_install = os.path.dirname(os.path.dirname(find_executable('dakota')))
dakota_bin = os.path.join(dakota_install, 'bin')
dakota_include = os.path.join(dakota_install, 'include')
dakota_lib = os.path.join(dakota_install, 'lib')
req = (dakota_bin, dakota_include, dakota_lib)
if not all(map(os.path.exists, req)):
    exit("Can't find %s or %s or %s, bummer" % req)

# Read make macros from `install_dir`/include/Makefile.export.Dakota.
dakota_macros = {}
with open(os.path.join(dakota_install, 'include',
                       'Makefile.export.Dakota'), 'rU') as inp:
    for line in inp:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        name, _, value = line.partition('=')
        dakota_macros[name.strip()] = value.strip().split()

# BOOST_ROOT is expected to be set if a certain boost build is required
BOOST_ROOT = os.getenv('BOOST_ROOT', None)
# Set boost include and lib directories (or None if found by default).
BOOST_INC_DIR = None
BOOST_LIB_DIR = None
if BOOST_ROOT:
    BOOST_INC_DIR = os.path.join(BOOST_ROOT, 'include')
    BOOST_LIB_DIR = os.path.join(BOOST_ROOT, 'lib')

# Set this for formatting library names like 'boost_regex' to library names for
# the linker.
BOOST_LIBFMT = '%s'
BOOST_PYFMT = None  # Used to handle case when only boost_python was built
# as shared library on Windows (temporary hack).

numpy_include = os.path.join(os.path.dirname(numpy.__file__),
                             os.path.join('core', 'include'))

include_dirs = [dakota_include, numpy_include]
library_dirs = [dakota_lib, dakota_bin]

sources = ['src/dakface.cpp', 'src/dakota_python_binding.cpp']

if BOOST_INC_DIR:
    include_dirs.append(BOOST_INC_DIR)

# Drop '-D' from Dakota_DEFINES.
define_macros = [(name[2:], None) for name in dakota_macros['Dakota_DEFINES']]

# Some DAKOTA distributions (i.e. cygwin) put libraries in 'bin'.
if BOOST_LIB_DIR:
    library_dirs.append(BOOST_LIB_DIR)
    library_dirs.append(BOOST_LIB_DIR+'64')


# Drop '-l' from Dakota_LIBRARIES if necessary.
dakota_libs = dakota_macros['Dakota_LIBRARIES']
dakota_libs = [name[2:] if name.startswith('-l') else name for name in dakota_libs]

# From Makefile.export.Dakota Dakota_TPL_LIBRARIES.
external_libs = [
    'boost_regex', 'boost_filesystem', 'boost_serialization', 'boost_system',
    'boost_signals', 'boost_python']  # , 'lapack', 'blas']

# Munge boost library names as necessary.
if BOOST_LIBFMT:
    for i, name in enumerate(external_libs):
        if name.startswith('boost_'):
            if name == 'boost_python' and BOOST_PYFMT:
                external_libs[i] = BOOST_PYFMT % name
            else:
                external_libs[i] = BOOST_LIBFMT % name

libraries = dakota_libs + external_libs

carolina = Extension(name='carolina',
                     sources=sources,
                     include_dirs=include_dirs,
                     define_macros=define_macros,
                     extra_link_args=['-Wl,-z origin'],
                     library_dirs=library_dirs,
                     libraries=libraries,
                     language='c++')


def carolina_test_suite():
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover(os.path.abspath('tests'),
                                      pattern='test_*.py')
    return test_suite

setup(name='carolina',
      version='%s' % CAROLINA_VERSION,
      description='A Python wrapper for DAKOTA',
      py_modules=['dakota'],
      ext_modules=[carolina],
      package_dir={'': 'src'},
      zip_safe=False,
      test_suite='setup.carolina_test_suite')
