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
Generic DAKOTA driver.
This uses the standard version of DAKOTA as a library (libdakota_src.so).

:class:`DakotaInput` holds DAKOTA input strings and can write them to a file.

:meth:`run_dakota` runs dakota.

:meth:`dakota_callback` can be invoked by DAKOTA's Python interface to
evaluate the model.

There is no other information passed to DAKOTA, so DAKOTA otherwise acts like
the command line version, in particular, all other inputs go through the input
file (typically generated by :class:`DakotaInput`).

:class:`DakotaBase` ties these together for a basic 'driver'.
"""

from __future__ import with_statement
from __future__ import print_function

import logging
import os
import pyDAKOTA
import weakref

# This will hold a reference to the DakotaDriver instance or
# the user specified custom model instance
_USER_DATA = weakref.WeakValueDictionary()


class DakotaBase(object):
    """ Base class for a DAKOTA 'driver'. """

    def __init__(self, dakota_input):
        """
        The main constructor of the Base dakota driver. It sets the problem definition.
        :param dakota_input: The object that contains the problem definition and is the source of information
        for writing the configuration file for dakota
        :type dakota_input: DakotaInput
        """
        if dakota_input is None:
            raise RuntimeError("The problem definition is required - None value received")

        self.input = dakota_input

    def run_dakota(self, infile='dakota.in', stdout=None, stderr=None, restart=0):
        """
        This will create the configuration file for dakota,
        will set the driver instance that should handle dakota's requests and start dakota.

        This code expects that the DakotaInput instance stored as 'self.input' is properly initialized
        such that the callback Python based interface is used. If this is the case then dakota will call the
        'dakota.dakota_callback' function defined in this module.

        :param infile: The name used for the configuration file
        :type infile: str
        :param stdout: The stream to be used for redirecting the standard output
        :param stderr: The stream to be used for redirecting the standard error
        :param restart: A flag that instructs dakota whether to restart an experiment.
        This should be set to 1 if a restart is required.
        Set to 0 (the default value) means do not restart.
        If a restart is required dakota expects a restart file to be present
        in the working directory with the name 'dakota.rst'
        :type restart: int
        """

        # Write dakota config file and set the driver_instance to self
        self.input.write_input(infile, driver_instance=self)

        # Run dakota
        run_dakota(infile, stdout, stderr, restart=restart)

    def dakota_callback(self, **kwargs):
        """ Invoked from global :meth:`dakota_callback`, must be overridden. """
        raise NotImplementedError('dakota_callback')


class DakotaInput(object):
    """
    Simple mechanism where we store the strings that will go in each section
    of the DAKOTA input file.  The ``interface`` section defaults to a
    configuration that will use Python and set :meth:`dakota_callback` as driver.

    The :meth:'write' is expected to receive a reference
    to the actual driver instance that should handle the requests from dakota.

        # The problem definition is expected to be provided in the constructor as in the example:
        # e.g.: DakotaInput(method=["multidim_parameter_study",
        #                           "partitions = %d %d" % (nx, nx)])

    """

    def __init__(self, **kwargs):
        # Hard code the only acceptable interface
        self.interface = [
            "id_interface 'carolina'",
            "python",
            "  numpy",
            "  analysis_drivers = 'dakota:dakota_callback'",
            ]

        # Set all other sections
        for key in kwargs:
            if key == "interface":
                raise RuntimeError("It is not allowed to change the interface. "
                                   "This has been preset to the Python interface with dakota:dakota_callback as driver.")
            setattr(self, key, kwargs[key])

    def write_input(self, infile, driver_instance=None):
        """
        Write input file sections in standard order.

        Save the driver_instance for later use and write its id as ``analysis_components``.
        The invoked Python method should recover the original object using :meth:`fetch_data`.

        If the driver_instance is None raise exception.

        :param infile: The name of the file where to write the configuration for dakota
        :type infile: str
        :param driver_instance: The reference to the driver instance that will handle the requests from dakota
        :type driver_instance: DakotaBase

        """
        if driver_instance is None:
            raise RuntimeError("The driver instance is not set")

        # Store the reference to the driver instance
        ident = str(id(driver_instance))
        _USER_DATA[ident] = driver_instance

        # Write the configuration file
        with open(infile, 'w') as out:
            for section in ('environment', 'method', 'model', 'variables', 'interface', 'responses'):
                # Write the section and all its sub keywords
                out.write('%s\n' % section)
                for line in getattr(self, section):
                    out.write("\t%s\n" % line)

                # Write the driver instance id as analysis_components
                if section == 'interface':
                    # Check if there was already some other analysis component set
                    for line in getattr(self, section):
                        if 'analysis_components' in line:
                            raise RuntimeError('The analysis_components is only allowed to contain '
                                               'the id of the driver instance. Any additional data should be stored '
                                               'in the driver object.')

                    # Write the id of the driver instance to the interface section
                    out.write("\t  analysis_components = '%s'\n" % ident)


def fetch_data(ident, dat):
    """
    Return the user object recorded by :meth:`DakotaInput.write` as the driver.

    :param ident: The identifier of the object
    :type ident: str
    :rtype: DakotaBase
    """
    return dat[ident]


class _ExcInfo(object):
    """ Used to hold exception return information. """

    def __init__(self):
        self.type = None
        self.value = None
        self.traceback = None


def run_dakota(infile, stdout=None, stderr=None, restart=0):
    """
    Run DAKOTA with the configuration file as provided as first argument 'infile'.

    `stdout` and `stderr` can be used to direct their respective DAKOTA
    stream to a filename.

    Set dakota in restart mode if restart is equal to 1

    :param infile: The name of the configuration file
    :type infile: str
    :param stdout: The stream where to redirect standard output
    :param stderr: The stream where to redirect standard error
    :param restart: The flag that tells dakota whether to restart or not.
    If set to 1 than dakota will be started in restart mode. Dakota will
    expect in this case the restart file dakota.rst to be present in the working directory
    :type restart: int
    """

    # Checking for a Python exception via sys.exc_info() doesn't work, for
    # some reason it always returns (None, None, None).  So instead we pass
    # an object down and if an exception is thrown, the C++ level will fill
    # it with the exception information so we can re-raise it.
    err = 0
    exc = _ExcInfo()
    err = pyDAKOTA.run_dakota(infile, stdout, stderr, exc, restart)

    # Check for errors. We'll get here if Dakota::abort_mode has been set to
    # throw an exception rather than shut down the process.
    if err:
        if exc.type is None:
            raise RuntimeError('DAKOTA analysis failed')
        else:
            raise exc.type, exc.value, exc.traceback


def dakota_callback(**kwargs):
    """
    Generic callback from DAKOTA, forwards parameters to driver provided as
    the ``driver_instance`` argument to :meth:`DakotaInput.write`.

    The driver should return a responses dictionary based on the parameters.

    `kwargs` contains:

    =================== ==============================================
    Key                 Definition
    =================== ==============================================
    functions           number of functions (responses, constraints)
    ------------------- ----------------------------------------------
    variables           total number of variables
    ------------------- ----------------------------------------------
    cv                  list/array of continuous variable values
    ------------------- ----------------------------------------------
    div                 list/array of discrete integer variable values
    ------------------- ----------------------------------------------
    drv                 list/array of discrete real variable values
    ------------------- ----------------------------------------------
    av                  single list/array of all variable values
    ------------------- ----------------------------------------------
    cv_labels           continuous variable labels
    ------------------- ----------------------------------------------
    div_labels          discrete integer variable labels
    ------------------- ----------------------------------------------
    drv_labels          discrete real variable labels
    ------------------- ----------------------------------------------
    av_labels           all variable labels
    ------------------- ----------------------------------------------
    asv                 active set vector (bit1=f, bit2=df, bit3=d^2f)
    ------------------- ----------------------------------------------
    dvv                 derivative variables vector
    ------------------- ----------------------------------------------
    currEvalId          current evaluation ID number
    ------------------- ----------------------------------------------
    analysis_components one string that is assumed to be an identifier
                        for a driver object with
                        a dakota_callback method
    =================== ==============================================

    """
    acs = kwargs['analysis_components']
    if not acs:
        msg = 'dakota_callback (%s): No analysis_components' % os.getpid()
        logging.error(msg)
        raise RuntimeError(msg)

    # Get the instance of the driver - currently only a Python based driver is allowed
    try:
        driver = fetch_data(acs[0], _USER_DATA)

    except KeyError:
        msg = 'dakota_callback (%s): identifier %s not found in user data' % (os.getpid(), acs[0])
        logging.error(msg)
        raise RuntimeError(msg)

    return driver.dakota_callback(**kwargs)
