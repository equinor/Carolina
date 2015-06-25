// Copyright 2013 National Renewable Energy Laboratory (NREL)
// 
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
// 
//        http://www.apache.org/licenses/LICENSE-2.0
// 
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
// 
// ++==++==++==++==++==++==++==++==++==++==

/* dakota_python_interface.cpp

This file implements a simple boost based python binding for the dakota library.

   Goal is to be able to simply say:

   import dakota
   dakota.run()

   and have dakota do its thing

   In actual fact we implement 3 ways:
   1) run_dakota(file) -- no args, just run it as if from the comnand line, with input file "file"
   2) run_dakota_data(file, data) -- "data" is any python object, it is passed back to your interface function
   3) run_dakota_mpi_data(file, comm, data) -- "comm" is an mpi_communicator over which the work is divided
   
*/

#include "string.h"

#include "dakface.hpp"

//#ifdef DAKOTA_HAVE_MPI
//#include <boost/mpi.hpp>
//#endif

#ifdef WINDOWS
#include <windows.h>
#endif

#include <Python.h>

#include <numpy/arrayobject.h>


#define MAKE_ARGV \
  char *argv[10]; \
  int argc = 0; \
  argv[argc++] = const_cast<char*>("dakota"); \
  argv[argc++] = const_cast<char*>("-i"); \
  argv[argc++] = infile; \
  if (outfile && strlen(outfile)) { \
    argv[argc++] = const_cast<char*>("-o"); \
    argv[argc++] = outfile; \
  } \
  if (errfile && strlen(errfile)) { \
    argv[argc++] = const_cast<char*>("-e"); \
    argv[argc++] = errfile; \
  }

int run_dakota(char *infile, char *outfile, char *errfile, PyObject *exc)
{
  MAKE_ARGV

  void *tmp_exc = NULL;
  if (PyBool_Check(exc))
    tmp_exc = &exc;

  return all_but_actual_main(argc, argv, tmp_exc);
}

#ifdef DAKOTA_HAVE_MPI
int run_dakota_mpi(char *infile, MPI_Comm &_mpi,
#else
int run_dakota_mpi(char *infile, int &_mpi,
#endif
                   char *outfile, char *errfile, PyObject *exc)
{
  MAKE_ARGV
  MPI_Comm comm = MPI_COMM_WORLD;
  if (_mpi) 
    comm = _mpi;

  void *tmp_exc = NULL;
  if (PyBool_Check(exc))
    tmp_exc = &exc;

  return all_but_actual_main_mpi(argc, argv, comm, tmp_exc);
}

// When DAKOTA fails it throws an int (if the process isn't aborted).
// Normally Python model errors will have already recorded an exception.
// If not, we record one here.
void translator(const int& exc)
{
  if (!PyErr_Occurred()) {
    // No exception recorded yet.
    PyErr_SetString(PyExc_RuntimeError, "DAKOTA run failed");
  }
}

//#include <boost/python.hpp>
//using namespace boost::python;
//BOOST_PYTHON_MODULE(pyDAKOTA)
//{
//  using namespace bpn;
//  import_array();
//  array::set_module_and_type("numpy", "ndarray");
//
//  register_exception_translator<int>(&translator);
//
//  def("run_dakota", run_dakota, "run dakota");
//  def("run_dakota_mpi", run_dakota_mpi, "run dakota mpi");
//}
////////
static PyObject * wrap_dak_mpi(PyObject *, PyObject *args)
{

   #ifdef DAKOTA_HAVE_MPI
   char parslings[6] = "sOssO";
   char *infile; MPI_Comm &_mpi;
   #else
   char parslings[7] = "sissO";
   char *infile; int &_mpi;
   #endif
       char *outfile, *errfile; PyObject *exc;

    if(!PyArg_ParseTuple(args, parslings, &infile, &_mpi, &outfile, &errfile, &exc))
        return NULL;
    return Py_BuildValue("i", run_dakota_with_mpi(infile, _mpi, outfile, errfile, exc));
}

static PyObject * wrap_dak(PyObject *, PyObject *args) 
{
    char *infile, char *outfile, *errfile;
    PyObject *exc;
    if(!PyArg_ParseTuple(args, "sssO", &infile, &outfile, &errfile, &exc))
        return NULL;
    return Py_BuildValue("i", run_dakota(infile, outfile, errfile, exc));
}

static PyMethodDef dak_methods[] = 
{
    {"run_dakota", (PyCFunction) wrap_dak, METH_VARARGS},
    {"run_dakota_mpi", (PyCFunction) wrap_dak_mpi, METH_VARARGS},
    {NULL, NULL}
};

extern "C" void initpyDAKOTA(void)
{
    (void) Py_Init("pyDAKOTA", dak_methods);
}
