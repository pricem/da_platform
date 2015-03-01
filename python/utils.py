import fl

USB_VIDPID = "1443:0005"

class FLDependentObject(object):
    def __init__(self):
        fl.flInitialise(0)

        if ( not fl.flIsDeviceAvailable(USB_VIDPID) ):
            print("Loading firmware...")
            fl.flLoadStandardFirmware(USB_VIDPID, USB_VIDPID)

            print("Awaiting...")
            fl.flAwaitDevice(USB_VIDPID, 600)

        self.handle = fl.flOpen(USB_VIDPID)
        print 'Obtained FPGALink handle for USB device %s' % USB_VIDPID

    def close(self):
        fl.flClose(self.handle)
