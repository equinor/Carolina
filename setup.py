# Copyright 2013 National Renewable Energy Laboratory (NREL)
#
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
Build pyDAKOTA Python 'egg' for cygwin, darwin, linux, or win32 platforms.
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

import glob
import os.path
import subprocess
import sys

from distutils.spawn import find_executable
from pkg_resources import get_build_platform
from setuptools import setup, find_packages
from setuptools.extension import Extension

# Execute DAKOTA to get version.
try:
    proc = subprocess.Popen(['dakota', '-v'], universal_newlines=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()

except Exception, exc:
    print "Couldn't execute 'dakota -v':", exc
    sys.exit(1)

fields = stdout.split()
if len(fields) >= 3 and \
   fields[0].upper() == 'DAKOTA' and fields[1] == 'version':
    dakota_version = fields[2]
else:
    print "Can't parse version from DAKOTA output %r" % stdout
    print "    stderr output:", stderr
    sys.exit(1)

wrapper_version = '1'
egg_dir = 'pyDAKOTA-%s_%s-py%s-%s.egg' % (dakota_version, wrapper_version,
                                          sys.version[0:3], get_build_platform())

# Assuming standard prefix-based install.
dakota_install = os.path.dirname( os.path.dirname(find_executable('dakota')))
dakota_bin     = os.path.join(dakota_install, 'bin')
dakota_include = os.path.join(dakota_install, 'include')
dakota_lib     = os.path.join(dakota_install, 'lib')
if not os.path.exists(dakota_bin) or \
   not os.path.exists(dakota_include) or \
   not os.path.exists(dakota_lib):
    print "Can't find", dakota_bin, 'or', dakota_include, 'or', dakota_lib, ', bummer'
    sys.exit(1)

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

print "Dakota macros: \n"
print dakota_macros

# Set to a list of any special compiler flags required.
CXX_FLAGS = []

# Set to a list of any special linker flags required.
LD_FLAGS = []

# Set to directory with 'boost' subdirectory (or None if found by default).
BOOST_INCDIR = None

# Set to directory with Boost libraries (or None if found by default).
BOOST_LIBDIR = None

# Set this for formatting library names like 'boost_regex' to library names for
# the linker.
BOOST_LIBFMT = '%s'
BOOST_PYFMT = None  # Used to handle case when only boost_python was built
                    # as shared library on Windows (temporary hack).

# Set to directory with LAPACK and BLAS libraries (or None if found by default).
LAPACK_LIBDIR = None

# Set to directory with Fortran libraries (or None if found by default).
FORTRAN_LIBDIR = None

# Set this to a list of extra libraries required beyond DAKOTA and BOOST.
EXTRA_LIBS = []

# Set this to a list of libraries to be included in the egg.
EGG_LIBS = []

# Locate numpy include directory.
import numpy
numpy_include = os.path.join(os.path.dirname(numpy.__file__), os.path.join('core', 'include'))

include_dirs = [dakota_include, numpy_include]
library_dirs = [dakota_lib, dakota_bin]

BOOST_INCDIR = '/boost_install/include'
BOOST_LIBDIR = '/boost_install/lib'

LAPACK_LIBDIR="."
LD_FLAGS = ['-Wl,-z origin',
            '-Wl,-rpath=${ORIGIN}:${ORIGIN}/../' + egg_dir]
# EXTRA_LIBS = ['gfortran'
#             ] # 'SM', 'ICE', 'Xext', 'Xm', 'Xt', 'X11', 'Xpm', 'Xmu']

EGG_LIBS = glob.glob(os.path.join(dakota_lib, '*.so'))
EGG_LIBS.extend(glob.glob(os.path.join(dakota_bin, '*.so*')))
print "egg libraries: \n"
print (EGG_LIBS)

sources = ['src/dakface.cpp', 'src/dakota_python_binding.cpp']

if BOOST_INCDIR:
    include_dirs.append(BOOST_INCDIR)

# Drop '-D' from Dakota_DEFINES.
define_macros = [(name[2:], None) for name in dakota_macros['Dakota_DEFINES']]

# Some DAKOTA distributions (i.e. cygwin) put libraries in 'bin'.
if BOOST_LIBDIR:
    library_dirs.append(BOOST_LIBDIR)
if LAPACK_LIBDIR:
    library_dirs.append(LAPACK_LIBDIR)
if FORTRAN_LIBDIR:
    library_dirs.append(FORTRAN_LIBDIR)

# Drop '-l' from Dakota_LIBRARIES if necessary.
dakota_libs = dakota_macros['Dakota_LIBRARIES']
dakota_libs = [name[2:] if name.startswith('-l') else name for name in dakota_libs]

# From Makefile.export.Dakota Dakota_TPL_LIBRARIES.
external_libs = [
    'boost_regex', 'boost_filesystem', 'boost_serialization', 'boost_system',
    'boost_signals', 'boost_python']#, 'lapack', 'blas']

# Munge boost library names as necessary.
if BOOST_LIBFMT:
    for i, name in enumerate(external_libs):
        if name.startswith('boost_'):
            if name == 'boost_python' and BOOST_PYFMT:
                external_libs[i] = BOOST_PYFMT % name
            else:
                external_libs[i] = BOOST_LIBFMT % name

libraries = dakota_libs + external_libs + EXTRA_LIBS

# List extra files to be included in the egg.
data_files = []
if EGG_LIBS:
    with open('src/MANIFEST.in', 'w') as manifest:
        for lib in EGG_LIBS:
            manifest.write('include %s\n' % os.path.basename(lib))
    data_files = [('', EGG_LIBS)]


pyDAKOTA = Extension(name='pyDAKOTA',
                     sources=sources,
                     include_dirs=include_dirs,
                     define_macros=define_macros,
                     extra_compile_args=CXX_FLAGS,
                     extra_link_args=LD_FLAGS,
                     library_dirs=library_dirs,
                     libraries=libraries,
                     language='c++')

setup(name='pyDAKOTA',
      version='%s-%s' % (dakota_version, wrapper_version),
      description='A Python wrapper for DAKOTA',
      py_modules=['test_dakota'],
      ext_modules=[pyDAKOTA],
      packages=['dakota'],
      package_dir={'dakota':'src', 'test_dakota':'tests'},
      zip_safe=False,
      data_files=data_files)

