#include <usb.h>
#include <iostream>

//  These are the IDs I made up off the top of my head.
//  Should match the firmware.
#define TARGET_VENDOR_ID  0x0144
#define TARGET_PRODUCT_ID 0x0281

//  The device only has 1 interface, so we use it.
#define INTERFACE_ID      0

struct usb_device* get_device()
{
    usb_bus* busses;
	usb_bus* curbus;

    usb_find_busses();
	usb_find_devices();

	busses = usb_get_busses();
    for (curbus = busses; curbus; curbus = curbus->next)
    {   		
        struct usb_device *dev;
		for (dev = curbus->devices; dev; dev = dev->next) {
			if ((dev->descriptor.idVendor == TARGET_VENDOR_ID)
			 && (dev->descriptor.idProduct == TARGET_PRODUCT_ID)) {
				//  Return device
				return dev;
			}
    	}

    }  
}

usb_dev_handle* get_handle(struct usb_device* device)
{
    int status;
    usb_dev_handle* handle = usb_open(device);
    
    status = usb_claim_interface(handle, INTERFACE_ID);
    if (status < 0)
    {
        std::cout << "Could not claim interface, error " << status << "." << std::endl;
        return NULL;
    }
    
    //  Reset the endpoints that we'll use (2, 4, 6, 8)
    for (int ep = 2; ep <= 8; ep += 2)
    {
        unsigned int ep_addr = ep;
        if (ep > 4)
        {
            //  Add appropriate bit mask for IN endpoint descriptors
            ep_addr += 0x80;        
        }
        status = usb_clear_halt(handle, ep_addr);
        if (status < 0)
        {
            std::cout << "Could not clear halt on endpoint " << ep << ", error " << status << "." << std::endl;
            usb_release_interface(handle, INTERFACE_ID);
            return NULL;
        }
    }
    
    return handle;
}

void drop_handle(usb_dev_handle* dev)
{
    if (dev)
    {
        usb_release_interface(dev, INTERFACE_ID);
        usb_close(dev);
    }
}

int main(void)
{
    int i = 0;
    struct usb_device* target_device = NULL;
    usb_dev_handle* target_handle = NULL;

	usb_init();
	target_device = get_device();
	
    if (target_device)
	{
	    //  Display some information about the device
	    std::cout << "Found device." << std::endl;
	    std::cout << "  " << std::endl;
	    
	    target_handle = get_handle(target_device);
	    if (target_handle)
	    {
	        std::cout << "Obtained a handle." << std::endl;
	    }
	    else
	    {
	        std::cout << "Could not obtain a handle." << std::endl;
	    }
	}
	else
	{
	    std::cout << "No device found." << std::endl;
	}

    drop_handle(target_handle);

	return 0;
}

