#ifdef DAKOTA_HAVE_MPI
#include <mpi.h>

static void sayhello(MPI_Comm comm)
{
  if (comm == MPI_COMM_NULL) {
    std::cout << "You passed MPI_COMM_NULL !!!" << std::endl;
    return;
  }
  int size;
  MPI_Comm_size(comm, &size);
  int rank;
  MPI_Comm_rank(comm, &rank);
  int plen; char pname[MPI_MAX_PROCESSOR_NAME];
  MPI_Get_processor_name(pname, &plen);
  std::cout <<
    "Hello, World! " <<
    "I am process "  << rank  <<
    " of "           << size  <<
    " on  "          << pname <<
    "."              << std::endl;
}

#include <mpi4py/mpi4py.h>

#endif

#include <iostream>
#include "dakface.hpp"
#include <boost/python.hpp>
namespace bp = boost::python;
namespace bpn = boost::python::numeric;

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

int run_dakota(char *infile, char *outfile, char *errfile, bp::object exc, int restart, bool throw_on_error)
{

  MAKE_ARGV
  if (restart==1){
    argv[argc++] = const_cast<char*>("-r"); \
    argv[argc++] = const_cast<char*>("dakota.rst");
  }

  void *tmp_exc = NULL;
  if (exc)
    tmp_exc = &exc;

  return all_but_actual_main(argc, argv, tmp_exc, throw_on_error);
}

#ifdef DAKOTA_HAVE_MPI
int run_dakota_mpi(char *infile, bp::object py_comm, char *outfile, char *errfile, bp::object exc, int restart, bool throw_on_error)
{
  MPI_Comm comm = MPI_COMM_WORLD;
  if (py_comm) {
  PyObject* py_obj = py_comm.ptr();
  MPI_Comm *comm_p = PyMPIComm_Get(py_obj);
  if (comm_p == NULL) bp::throw_error_already_set();
  //sayhello(*comm_p);
  MPI_Comm comm = * comm_p ;
  }

  MAKE_ARGV
  if (restart==1){
    argv[argc++] = const_cast<char*>("-r"); \
    argv[argc++] = const_cast<char*>("dakota.rst");
  }

  void *tmp_exc = NULL;
  if (exc)
    tmp_exc = &exc;

  return all_but_actual_main_mpi(argc, argv, comm, tmp_exc, throw_on_error);
}
#endif

void translator(const int& exc)
{
  if (!PyErr_Occurred()) {
    // No exception recorded yet.
    //     PyErr_SetString(PyExc_RuntimeError, "DAKOTA run failed");
  }
}


#include <boost/python.hpp>
#include <numpy/arrayobject.h>
using namespace boost::python;
BOOST_PYTHON_MODULE(carolina)
{
  using namespace bpn;

#ifdef DAKOTA_HAVE_MPI
  if (import_mpi4py() < 0) return;
#endif

  import_array();
  array::set_module_and_type("numpy", "ndarray");

  register_exception_translator<int>(&translator);

  def("run_dakota", run_dakota, "run dakota");

#ifdef DAKOTA_HAVE_MPI
    def("run_dakota_mpi", run_dakota_mpi);
#endif
}


/*
 * Local Variables:
 * mode: C++
 * End:
 */
