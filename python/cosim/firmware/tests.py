from myhdl import *
import unittest
from unittest import TestCase

from tracking_fifo_test import tracking_fifo_test
from usb_toplevel_test import usb_toplevel_test
from test_settings import *
from common import *

#current_test = tracking_fifo_test
current_test = usb_toplevel_test

class AllTests(TestCase):

    def testAll(self):
        sim = Simulation(instantiate(current_test))
        sim.run()

if USE_UNITTEST:
    unittest.main()
else:
    sim = Simulation(instantiate(current_test))
    sim.run()


