
from usbp import *
from time import *

c = USBP('ufo400')
c.LoadFxFirmware('usbp_v1.hex')
c.ConfigFPGA('usbp_myhdl_top.bit')

print 'Read from Data Stream'
Nbytes = 2**12
data  = c.CreateDataBucket(Nbytes)
rData = c.CreateDataBucket(Nbytes)

err = 0
while err == 0:
    err = c.ReadData(data)


c.WriteAddress(0x100, 0xFF)
c.WriteAddress(0x102, 0xFF)
c.WriteAddress(0x101, 0x01)

for i in range(1000):
    c.WriteAddress(0x103, 0xC3)
    sleep(0.1)
    c.WriteAddress(0x103, 0x3C)
    sleep(0.1)
