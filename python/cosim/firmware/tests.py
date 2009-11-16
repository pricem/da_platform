from myhdl import *
import unittest
from unittest import TestCase

from tracking_fifo_test import tracking_fifo_test
from test_settings import *
from common import *

class AllTests(TestCase):

    def testAll(self):
        sim = Simulation(instantiate(tracking_fifo_test))
        sim.run()

if USE_UNITTEST:
    unittest.main()
else:
    sim = Simulation(instantiate(tracking_fifo_test))
    sim.run()


