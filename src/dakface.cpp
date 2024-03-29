// Copyright 2013 National Renewable Energy Laboratory (NREL)
//           2023 Equinor ASA
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
// Peter Graf, 9/21/12
// Implementing a C++ interface for Dakota that will accept:
// 1) argc/argv for command-line arguents to use
// 2) an optional MPI comm to work with
// 3) a void * to a Python exception object

// Must be before system includes according to Python docs.
//#include <Python.h>
// Replaces Python.h according to boost_python docs.
#include <boost/python/detail/wrap_python.hpp>

#include <iostream>

#include "dakota_system_defs.hpp"
#include "ProgramOptions.hpp"
#include "LibraryEnvironment.hpp"
#include "ProblemDescDB.hpp"
#include "PRPMultiIndex.hpp"
#include "DakotaModel.hpp"
#include "DakotaInterface.hpp"
#include "PluginSerialDirectApplicInterface.hpp"
#include "dakota_global_defs.hpp"
#include "dakota_dll_api.h"
#include "LibraryEnvironment.hpp"

#include "dakface.hpp"

#include <boost/python/def.hpp>
namespace bp = boost::python;

#include <boost/system/system_error.hpp>
namespace Dakota {
  extern PRPCache data_pairs;
}
using namespace Dakota;

#ifdef HAVE_AMPL
/** Floating-point initialization from AMPL: switch to 53-bit rounding
    if appropriate, to eliminate some cross-platform differences. */
  extern "C" void fpinit_ASL();
#endif

static int _main(int argc, char* argv[], MPI_Comm *pcomm, void *exc, bool throw_on_error=false);

int all_but_actual_main(int argc, char* argv[], void *exc, bool throw_on_error=false)
{
  return _main(argc, argv, NULL, exc, throw_on_error);
}

static int _main(int argc, char* argv[], MPI_Comm *pcomm, void *exc, bool throw_on_error)
{
  static bool initialized = false;
  if (!initialized) 
 {

#ifdef HAVE_AMPL
    // Switch to 53-bit rounding if appropriate, to eliminate some
    // cross-platform differences.
    fpinit_ASL();
#endif

    // Tie signals to Dakota's abort_handler.
    // Dakota::register_signal_handlers();

    initialized = true;
  }

  // Parse input and construct Dakota LibraryEnvironment, performing
  // input data checks.  Assumes comm rank 0.
  //Dakota::ProgramOptions opts(argc, argv, 0);
  //Dakota::ParallelLibrary(argc, argv);
  Dakota::ProgramOptions opts(argc, argv, 0);

  if(throw_on_error)
     // Have Dakota throw an exception rather than aborting the process when error occurs
     opts.exit_mode("throw");

  Dakota::LibraryEnvironment* env = 0;
  Dakota::data_pairs.clear();
  if (pcomm) 
  {
    MPI_Comm comm = *pcomm;
    //MPI_Barrier(comm);
    //Dakota::ParallelLibrary();
    env = new Dakota::LibraryEnvironment(comm, opts);
  } 
  else 
  {
    env = new Dakota::LibraryEnvironment(opts);
  }

  // Execute the environment.
  int retval = 0;
  try 
  {
    Dakota::data_pairs.clear();
    env->execute();
    Dakota::data_pairs.clear();
  }
  catch (...) 
  {
    if (PyErr_Occurred()) {
      PyObject *type = NULL, *value = NULL, *traceback = NULL;
      PyErr_Fetch(&type, &value, &traceback);
      bp::object *tmp = (bp::object *)exc;
      PyObject_SetAttrString(tmp->ptr(), "type", type ? type : Py_None);
      PyObject_SetAttrString(tmp->ptr(), "value", value ? value : Py_None);
      PyObject_SetAttrString(tmp->ptr(), "traceback", traceback ? traceback : Py_None);
      PyErr_Clear();
    }
    retval = 1;
  }

  delete env;
  return retval;
}
