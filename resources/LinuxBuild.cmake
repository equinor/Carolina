set( CTEST_BUILD_NAME "dakota_pgin" )
set( DAKOTA_CTEST_PROJECT_TAG "Continuous" )
set( CTEST_BUILD_CONFIGURATION RelWithDebInfo )

set( DAKOTA_CTEST_REGEXP "dakota_*" )
set( DAKOTA_DEBUG OFF CACHE BOOL "debug OFF" FORCE)

# turn python on!
set (DAKOTA_PYTHON ON CACHE BOOL "python interface on" FORCE)

# Stop being in debug mode please - does nothing
# DO NOT ENABLE!!! set (MPI_DEBUG OFF CACHE BOOL "mpi debug off" FORCE)

### no mpi
set( DAKOTA_HAVE_MPI FALSE
     CACHE BOOL "Build WITHOUT MPI enabled" FORCE)
set( CMAKE_C_COMPILER "gcc"
     CACHE FILEPATH "Do NOT USE MPI compiler wrapper" FORCE)
set( CMAKE_CXX_COMPILER "g++"
     CACHE FILEPATH "Do NOT USE MPI compiler wrapper" FORCE)
set( CMAKE_Fortran_COMPILER "gfortran"
     CACHE FILEPATH "Do NOT USE MPI Fortran compiler wrapper" FORCE)

### Force static
set( BUILD_STATIC_LIBS OFF 
     CACHE BOOL "Set to OFF to build static libraries" FORCE)

set( BUILD_SHARED_LIBS ON 
     CACHE BOOL "Set to ON to build DSO libraries" FORCE)

option(DAKOTA_DLL_API "Enable DAKOTA DLL API." OFF)


# Disable optional X graphics
set(HAVE_X_GRAPHICS OFF CACHE BOOL "Disable dependency on X libraries" FORCE)

##############################################################################
set ( CMAKE_CXX_FLAGS "-fPIC" CACHE STRING "compile CXX flags" FORCE)
set ( CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} -fPIC" CACHE STRING "compile C flags" FORCE)
set ( CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fPIC" CACHE STRING "compile fortran flags" FORCE)
set ( LIBCXX -stdlib=libc++)
set ( LIBSTDCXX -stdlib=libstdc++)
set ( Boost_COMPILER "g++" )

##########################################################################
# Set up Internal CMake paths first. Then call automated build file.
# DO NOT CHANGE!!
##########################################################################
#include( ${CTEST_SCRIPT_DIRECTORY}/utilities/DakotaSetupBuildEnv.cmake )
#include( common_build )
##########################################################################
