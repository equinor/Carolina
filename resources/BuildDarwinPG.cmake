#
# CTest Automated Build Variables for Darwin
#
##############################################################################
#
# This is intended for building the DAKOTA library on the OSX system
# This was tested using the following C environment:
#
#      brew install gcc --without-multilib
#      export HOMEBREW_CC=gcc-5             (DAKOTA is not clang compatable)
#      export HOMEBREW_CXX=g++-5
#      brew install boost --c++11 --with-mpi --withput-single (`brew edit boost` -> layout=system)
#      brew install lapack                                                                         |
#      brew install openmotif (if this formula is still not available you can use the one I found \|/)

#                              brew install https://gist.githubusercontent.com/steakknife/60a39a32ae84e12238a2/raw/openmotif.rb
#      brew install boost155 --with-mpi --with-python --without-single    (this is so you can import boost mpi in python)
#      now append this to ~/.bash_profile: export PYTHONPATH="$PYTHONPATH:/usr/local/Cellar/boost155/1.55.0_1/lib"
#
#      unset HOMEBREW_CC
#      unset HOMEBREW_CXX
#      brew install boost-python --c++11
#
#
#   INSTRUCTIONS
#   ------------
# Use this file to build DAKOTA from source: https://dakota.sandia.gov/download.html
# Download and decompress the source file, cd into that directory,
# then cp <this file> into this directory. Copy and paste the following commands to build DAKOTA.
#
#      mkdir build
#      cd build
#      cmake -C ../BuildDarwinPG.cmake -C ../FindNumpy.cmake ../. -DCMAKE_CXX_FLAGS=-DBOOST_SIGNALS_NO_DEPRECATION_WARNING
#      make
#      make install
#
#      now install carolina, changing the mpicxx compiler in /usr/local/Cellar/open-mpi/1.10.2/share/openmpi/mpicxx-wrapper-data.txt to clang++
#      now install dakota_driver and you're done
##############################################################################

set( CTEST_BUILD_NAME "dakota_mac" )

set( DAKOTA_CMAKE_PLATFORM "Darwin.cmake")
set( DAKOTA_CMAKE_BUILD_TYPE "DakotaDistro.cmake")

#********* MUST SET CORRECTLY!!! *********** #
# TODO: comment or test and error
#set( CTEST_DASHBOARD_ROOT
#     "$ENV{HOME}/dakota-devel" )
#set( CTEST_SOURCE_DIRECTORY
#     "${CTEST_DASHBOARD_ROOT}/dakota")
#******************************************* #

set( DAKOTA_CTEST_PROJECT_TAG "Continuous" )
set( CTEST_BUILD_CONFIGURATION RelWithDebInfo )

set( DAKOTA_CTEST_REGEXP "dakota_*" )
set( DAKOTA_DEBUG ON )

# turn python on!
set (DAKOTA_PYTHON ON CACHE BOOL "python interface on" FORCE)
set(PYTHON_INCLUDE_DIRS "/usr/local/Cellar/python/2.7.10_2/Frameworks/Python.framework/Versions/2.7/include/python2.7" CACHE FILEPATH  "py inc" FORCE)
set(PYTHON_INCLUDE_PATH "/usr/local/Cellar/python/2.7.10_2/Frameworks/Python.framework/Versions/2.7/include/python2.7" CACHE FILEPATH  "py inc" FORCE)
#set(PYTHON_LIBRARIES "/usr/local/Cellar/python/2.7.10/Frameworks/Python.framework/Versions/2.7/lib/libpython2.7.dylib")
set(PYTHON_LIBRARIES "/usr/local/Cellar/python/2.7.10_2/Frameworks/Python.framework/Versions/2.7/lib/libpython2.7.dylib" CACHE FILEPATH "py libs" FORCE)
set(PYTHON_LIBRARY "/usr/local/Cellar/python/2.7.10_2/Frameworks/Python.framework/Versions/2.7/lib/libpython2.7.dylib" CACHE FILEPATH "py libs" FORCE)

### no mpi:
#set( DAKOTA_HAVE_MPI OFF
#     CACHE BOOL "Always build with MPI enabled" FORCE)
#set( CMAKE_C_COMPILER "gcc-mp-4.5"
#     CACHE FILEPATH "Use MPI compiler wrapper" FORCE)
#set( CMAKE_CXX_COMPILER "g++-mp-4.5"
#     CACHE FILEPATH "Use MPI compiler wrapper" FORCE)
#set( CMAKE_Fortran_COMPILER "gfortran-mp-4.5"
#     CACHE FILEPATH "Use MPI compiler wrapper" FORCE)


### yes mpi
set( CMAKE_C_COMPILER "mpicc"
     CACHE FILEPATH "Use MPI compiler wrapper" FORCE)
set( DAKOTA_HAVE_MPI ON
     CACHE BOOL "Always build with MPI enabled" FORCE)
set( CMAKE_CXX_COMPILER "mpic++"
     CACHE FILEPATH "Use MPI compiler wrapper" FORCE)

# Location where cmake first looks for cmake modules.
#message("got here 1")
#set(CMAKE_MODULE_PATH
#  ${CMAKE_CURRENT_SOURCE_DIR}/../cmake
#  ${CMAKE_CURRENT_SOURCE_DIR}/../cmake/semsCMake
#  ${CMAKE_MODULE_PATH}
#  )
#include(DakotaHaveMPI)
#DakotaHaveMPI()

#message("got here 2")

set( CMAKE_Fortran_COMPILER "mpif90"
     CACHE FILEPATH "MPI Fortran compiler wrapper" FORCE)
set( MPI_LIBRARY
     #"/Users/pgraf/root/mpich/lib/libmpich.a"
     "/usr/local/Cellar/open-mpi/1.8.6/lib"
     CACHE FILEPATH "Use installed MPI library" FORCE)


# Disable optional X graphics
#-DHAVE_X_GRAPHICS:BOOL=FALSE
set(HAVE_X_GRAPHICS OFF CACHE BOOL "Disable dependency on X libraries" FORCE)

##############################################################################

set( CMAKE_INSTALL_PREFIX
     "/usr/local/dakota"
     CACHE PATH "Path to Dakota installation" )

##############################################################################
# Define Boost directory and library paths
#
# If CMake Boost probe does not work, uncomment the following lines and
# define appropriate paths.
##############################################################################
set(BOOST_ROOT
    "/usr/local/opt/boost"
    CACHE PATH "Use non-standard Boost install" FORCE)

#set( Boost_NO_SYSTEM_PATHS TRUE
#     CACHE BOOL "Supress search paths other than BOOST_ROOT" FORCE)

set(BOOST_INCLUDEDIR
  "/usr/local/opt/boost/include"
  CACHE PATH "Use Boost installed here" FORCE)

set(BOOST_LIBRARYDIR
  "/usr/local/opt/boost/lib"
  CACHE PATH "Use Boost installed here" FORCE)

# boost patches
SET ( CMAKE_CXX_FLAGS "-arch x86_64 -libstdc=libc++ -stdlib=libc++" )
set(LIBCXX -stdlib=libc++)
set (LIBSTDCXX -stdlib=libstdc++)


#add_definitions ( -DBOOST_SIGNALS_NO_DEPRECATION_WARNING )
set ( Boost_COMPILER "mpic++" )

##########################################################################
# Set up Internal CMake paths first. Then call automated build file.
# DO NOT CHANGE!!
##########################################################################
#include( ${CTEST_SCRIPT_DIRECTORY}/utilities/DakotaSetupBuildEnv.cmake )
#include( common_build )
##########################################################################
