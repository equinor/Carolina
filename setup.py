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
"""Build carolina Python 'egg' for linux, assuming DAKOTA has been installed.

The linux platform is built using mpicxx.

DAKOTA graphics has been disabled to reduce the number of library dependencies.
This is built on RHEL 6.4 to mimic the DAKOTA release, and has been tested on
RHEL 6.4 and Ubuntu 'pangolin'.

"""

import os
import glob
import subprocess
import sys
import unittest
from distutils.spawn import find_executable

import numpy

from setuptools import setup
from setuptools.extension import Extension


CAROLINA_VERSION = '1.0'
DAKOTA_EXEC = find_executable('dakota')
if not DAKOTA_EXEC:
    exit('Unable to find dakota executable.')


def get_default_boost_python():
    if sys.version_info < (3,):
        return "boost_python"
    else:
        return "boost_python3"


def get_numpy_include():
    """Return path to numpy/core/include."""
    return os.path.join(os.path.dirname(numpy.__file__),
                        os.path.join('core', 'include'))


def find_dakota_paths():
    """Assuming standard prefix-based install."""
    dakota_install = os.path.dirname(os.path.dirname(DAKOTA_EXEC))
    dakota_bin = os.path.join(dakota_install, 'bin')
    dakota_include = os.path.join(dakota_install, 'include')
    dakota_lib = os.path.join(dakota_install, 'lib')
    req = (dakota_bin, dakota_include, dakota_lib)
    if not all(map(os.path.exists, req)):
        exit("Can't find %s or %s or %s, bummer" % req)
    return dakota_install, dakota_bin, dakota_include, dakota_lib


def read_dakota_macros(install_path):
    """Read make macros from `install_path`/include/Makefile.export.Dakota."""
    dakota_macros = {}
    with open(os.path.join(install_path, 'include',
                           'Makefile.export.Dakota'), 'rU') as inp:
        for line in inp:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            name, _, value = line.partition('=')
            dakota_macros[name.strip()] = value.strip().split()
    return dakota_macros


def get_dakota_libs(macros):
    """Drop '-l' from Dakota_LIBRARIES if necessary."""
    libs = macros['Dakota_LIBRARIES']
    libs = [name[2:] if name.startswith('-l') else name for name in libs]
    return libs


def get_define_macros(macros):
    """Drop '-D' from Dakota_DEFINES."""
    define_macros = [(name[2:], None) for name in macros['Dakota_DEFINES']]
    return define_macros

def get_boost_inc_lib():
    """BOOST_ROOT is expected to be set if a certain boost build is required.

    Set boost include and lib directories (or None if found by default).

    BOOST_PYTHON is expected to be set if a certain python version of boost_python build is required.

    """

    boost_root = os.getenv('BOOST_ROOT', None)

    boost_inc_dir = None
    boost_lib_dir = None
    if boost_root:
        boost_inc_dir = os.path.join(boost_root, 'include')
        boost_lib_dir = os.path.join(boost_root, 'lib')

    boost_python = os.getenv('BOOST_PYTHON', get_default_boost_python())

    if not boost_lib_dir:
        return boost_inc_dir, None, None, boost_python

    return boost_inc_dir, boost_lib_dir, boost_lib_dir+'64', boost_python


def get_macros_include_library():
    """Get the dakota macros, include and library dirs."""
    dakota_install, dakota_bin, dakota_include, dakota_lib = find_dakota_paths()
    dakota_macros = read_dakota_macros(dakota_install)

    inc = [dakota_include, get_numpy_include()]
    lib = [dakota_lib, dakota_bin]
    return dakota_macros, inc, lib

def get_carolina_extension():
    """Setup everything and make an Extension for Carolina!

    """

    dakota_macros, include_dirs, library_dirs = get_macros_include_library()

    boost_inc, boost_lib, boost_lib64, boost_python = get_boost_inc_lib()
    if boost_inc:
        include_dirs.append(boost_inc)
    if boost_lib:
        library_dirs.append(boost_lib)
        library_dirs.append(boost_lib64)


    sources = ['src/dakface.cpp', 'src/dakota_python_binding.cpp']
    
     
    external_libs = ['boost_regex', 'boost_filesystem', 'boost_serialization',
                     'boost_system', 'boost_signals', boost_python]

    print(boost_python)

    dakota_libs = get_dakota_libs(dakota_macros)
    libraries = dakota_libs + external_libs

    define_macros = get_define_macros(dakota_macros)

    carolina = Extension(name='carolina',
                         sources=sources,
                         include_dirs=include_dirs,
                         define_macros=define_macros,
                         extra_link_args=['-Wl,-z origin'],
                         extra_compile_args=['-std=c++11'],
                         library_dirs=library_dirs,
                         libraries=libraries,
                         language='c++')
    return carolina


def carolina_test_suite():
    """Discover and return test files as test_suite."""
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover(os.path.abspath('tests'),
                                      pattern='test_*.py')
    return test_suite


CAROLINA = get_carolina_extension()

setup(name='carolina',
      version='%s' % CAROLINA_VERSION,
      description='A Python wrapper for DAKOTA',
      py_modules=['dakota'],
      ext_modules=[CAROLINA],
      package_dir={'': 'src'},
      zip_safe=False,
      test_suite='setup.carolina_test_suite')
