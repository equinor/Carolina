#
# CTest Automated Build Variables for Darwin
#
##############################################################################
# Julian Quick Summer 2015 
# 
# This is intended for building the DAKOTA library on the OSX system
# This was tested using the following C environment:
#
#      brew install gcc --without-multilib
#      brew install openmpi --C11 (layout=system)
#      export HOMEBREW_CC=gcc-4.9
#      export HOMEBREW_CXX=g++-4.9
#      brew install boost --C11 --with-mpi --withput-single (layout=system)
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
#      cd src
#      make  
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
set (DAKOTA_PYTHON ON)
set(PYTHON_INCLUDE_DIRS "/usr/local/Cellar/python/2.7.10_1/Frameworks/Python.framework/Versions/2.7/include/python2.7")
#set(PYTHON_LIBRARIES "/usr/local/Cellar/python/2.7.10/Frameworks/Python.framework/Versions/2.7/lib/libpython2.7.dylib")
set(PYTHON_LIBRARIES "/usr/local/Cellar/python/2.7.10_1/Frameworks/Python.framework/Versions/2.7/lib/python2.7")

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
    "/usr/local/opt/boost/1.58.0"
    CACHE PATH "Use non-standard Boost install" FORCE)

#set( Boost_NO_SYSTEM_PATHS TRUE
#     CACHE BOOL "Supress search paths other than BOOST_ROOT" FORCE)

set(BOOST_INCLUDEDIR
  "/usr/local/opt/boost/1.58.0/include"
  CACHE PATH "Use Boost installed here" FORCE)

set(BOOST_LIBRARYDIR
  "/usr/local/opt/boost/1.58.0/lib"
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

