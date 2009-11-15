
from myhdl import *
import unittest
from unittest import TestCase
from bin2gray import bin2gray, bin2gray_verilog

MAX_WIDTH = 8
USE_TRACE = True

def instantiate(module, *args, **kwargs):
    if USE_TRACE:
        return traceSignals(module, *args, **kwargs)
    else:
        return module(*args, **kwargs)

def nextLn(Ln):
    """ Return Gray code Ln+1, given Ln. """
    Ln0 = ['0' + codeword for codeword in Ln]
    Ln1 = ['1' + codeword for codeword in Ln]
    Ln1.reverse()
    return Ln0 + Ln1

class TestGrayCodeProperties(TestCase):

    def testSingleBitChange(self):
        """ Check that only one bit changes in successive codewords """
        def test(B, G, width):
            B.next = intbv(0)
            yield delay(10)
            for i in range(1, 2**width):
                G_Z.next = G
                B.next = intbv(i)
                yield delay(10)
                diffcode = bin(G ^ G_Z)
                self.assertEqual(diffcode.count('1'), 1)
            
        for width in range(1, MAX_WIDTH):
            B = Signal(intbv(-1))
            G = Signal(intbv(0))
            G_Z = Signal(intbv(0))
            dut = instantiate(bin2gray_verilog, B, G, width)
            check = test(B, G, width)
            sim = Simulation(dut, check)
            sim.run(quiet=1)


    def testUniqueCodeWords(self):
        """ Check that all codewords occur exactly once """
        def test(B, G, width):
            actual = []
            for i in range(2**width):
                B.next = intbv(i)
                yield delay(10)
                actual.append(int(G))
            actual.sort()
            expected = range(2**width)
            self.assertEqual(actual, expected)
            
        for width in range(1, MAX_WIDTH):
            B = Signal(intbv(-1))
            G = Signal(intbv(0))
            dut = instantiate(bin2gray_verilog, B, G, width)
            check = test(B, G, width)
            sim = Simulation(dut, check)
            sim.run(quiet=1)
            
    def testOriginalGrayCode(self):
        """ Check that the code is an original Gray code """
        Rn = []
        def stimulus(B, G, n):
            for i in range(2**n):
                B.next = intbv(i)
                yield delay(10)
                Rn.append(bin(G, width=n))
        
        Ln = ['0', '1'] # n == 1
        for n in range(2, MAX_WIDTH):
            Ln = nextLn(Ln)
            del Rn[:]
            B = Signal(intbv(-1))
            G = Signal(intbv(0))
            dut = instantiate(bin2gray_verilog, B, G, n)
            stim = stimulus(B, G, n)
            sim = Simulation(dut, stim)
            sim.run(quiet=1)
            self.assertEqual(Ln, Rn)


unittest.main()
