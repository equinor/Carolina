"""Build carolina Python 'egg' for linux, assuming DAKOTA has been installed.

The linux platform is built using mpicxx.

DAKOTA graphics has been disabled to reduce the number of library dependencies.
This is built on RHEL 6.4 to mimic the DAKOTA release, and has been tested on
RHEL 6.4 and Ubuntu 'pangolin'.

"""

import os
import platform
import sys
import shutil

import numpy

from setuptools import setup
from setuptools.extension import Extension


CAROLINA_VERSION = '1.0'
DAKOTA_EXEC = shutil.which("dakota")
if not DAKOTA_EXEC:
    exit('Unable to find dakota executable.')


def get_default_boost_python():
    return f"boost_python3{sys.version_info.minor}"


def get_numpy_include():
    """Return path to numpy/core/include."""
    return numpy.get_include()


def find_dakota_paths():
    """Assuming standard prefix-based install."""
    dakota_install = os.path.dirname(os.path.dirname(DAKOTA_EXEC))
    dakota_bin = os.path.join(dakota_install, 'bin')
    dakota_include = os.path.join(dakota_install, 'include')
    dakota_lib = os.path.join(dakota_install, 'lib')
    eigen_include = os.path.join(dakota_include, 'eigen3')
    req = (dakota_bin, dakota_include, dakota_lib)
    if not all(map(os.path.exists, req)):
        exit("Can't find %s or %s or %s, bummer" % req)
    return dakota_install, dakota_bin, dakota_include, dakota_lib, eigen_include


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
    dakota_install, dakota_bin, dakota_include, dakota_lib, eigen_include = find_dakota_paths()
    dakota_macros = read_dakota_macros(dakota_install)

    inc = [dakota_include, eigen_include, get_numpy_include()]
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
                     'boost_system', 'boost_program_options', boost_python]

    print(boost_python)

    dakota_libs = get_dakota_libs(dakota_macros)
    libraries = dakota_libs + external_libs

    define_macros = get_define_macros(dakota_macros)

    # macOS linker does not support this flag
    extra_link_args = [] if "Darwin" in platform.system() else ['-Wl,-z origin']

    carolina = Extension(name='carolina',
                         sources=sources,
                         include_dirs=include_dirs,
                         define_macros=define_macros,
                         extra_link_args=extra_link_args,
                         extra_compile_args=['-std=c++17'],
                         library_dirs=library_dirs,
                         libraries=libraries,
                         language='c++')
    return carolina


CAROLINA = get_carolina_extension()

setup(
    name="carolina",
    version="%s" % CAROLINA_VERSION,
    description="A Python wrapper for DAKOTA",
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    py_modules=["dakota"],
    ext_modules=[CAROLINA],
    package_dir={"": "src"},
    zip_safe=False,
    install_requires=["numpy"],
)
