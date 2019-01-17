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
Trivial carolina test which runs an optimization on a 'model' which is the
Rosenbrock function.
"""

from __future__ import print_function
from numpy import array
from traceback import print_exc
import unittest

from dakota import DakotaBase, DakotaInput


class TestDriver(DakotaBase):

    def __init__(self, force_exception=False):
        # Create a dakota input template - this is not complete since it does not contain yet
        # the optimization problem specific information such as variables, constraints, etc.
        dakota_input = DakotaInput(
            environment=[
                "tabular_graphics_data",
                "output_precision = 8", ],
            method=[],
            model=[
                "single", ],
            variables=[],
            responses=[
                "num_objective_functions = 1",
                "analytic_gradients",
                "no_hessians", ]
        )
        super(TestDriver, self).__init__(dakota_input)

        self.force_exception = force_exception

        self.input.method = [
            "conmin_frcg", #"optpp_newton",
            "  max_iterations = 50",
            "  convergence_tolerance = 1e-4",
        ]
        self.input.variables = [
            "continuous_design = 2",
            "  cdv_initial_point  -1.2  1.0",
            "  cdv_lower_bounds   -2.0 -2.0",
            "  cdv_upper_bounds    2.0  2.0",
            "  cdv_descriptor      'x1' 'x2'",
        ]
        self.input.responses = [
            "num_objective_functions = 1",
            "analytic_gradients",
            "analytic_hessians",
        ]

    def dakota_callback(self, **kwargs):
        """
        Return responses from parameters.  `kwargs` contains:

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
        analysis_components str(id(self))
        =================== ==============================================

        """
        print('dakota_callback:')
        cv = kwargs['cv']
        asv = kwargs['asv']
        print('    cv', cv)
        print('    asv', asv)

        # Rosenbrock function.
        x = cv
        f0 = x[1]-x[0]*x[0]
        f1 = 1-x[0]

        retval = dict()
        try:
            if asv[0] & 1:
                f = [100*f0*f0+f1*f1]
                retval['fns'] = array(f)

            if asv[0] & 2:
                g = [[-400*f0*x[0] - 2*f1, 200*f0]]
                retval['fnGrads'] = array(g)

            if asv[0] & 4:
                fx = x[1]-3*x[0]*x[0]
                h = [[[-400*fx + 2, -400*x[0]],
                            [-400*x[0],    200     ]]]
                retval['fnHessians'] = array(h)

            if self.force_exception:
                raise RuntimeError('Forced exception')

        except Exception as exc:
            print('    caught', exc)
            raise

        print('    returning', retval)
        return retval


class TestCase(unittest.TestCase):

    def test_dakota(self):
        # To exercise recovery from exceptions, all tests are run within this.
        driver = TestDriver()

        print('\n### Check normal run.')
        driver.run_dakota()

    def test_dakota_exception(self):
        # To exercise recovery from exceptions, all tests are run within this.
        driver = TestDriver(force_exception=True)

        print('\n### Check run into exception.')
        self.assertRaises(RuntimeError, driver.run_dakota)


if __name__ == '__main__':
    unittest.main()

