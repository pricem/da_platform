#include <usb.h>
#include <cstdio>
#include <iostream>
#include <string>

//  These are the IDs I made up off the top of my head.
//  Should match the firmware.
#define TARGET_VENDOR_ID  0x0144
#define TARGET_PRODUCT_ID 0x0281

//  The device only has 1 interface, so we use it.
#define INTERFACE_ID      0

#define TIMEOUT_MS        100

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

unsigned int get_endpoint_addr(unsigned int endpoint)
{
    unsigned int ep_addr = endpoint;
    if (endpoint > 4)
    {
        //  Add appropriate bit mask for IN endpoint descriptors
        ep_addr += 0x80;        
    }
    return ep_addr;
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
        status = usb_clear_halt(handle, get_endpoint_addr(ep));
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

char get_msg()
{
    unsigned char result = 0;
    bool result_valid = false;
    std::string entered_info;
    
    while (!result_valid)
    {
        result = 0;
        result_valid = true;
        std::cout << "Enter your message in 1-byte hexadecimal form (e.g. 5C): \n  0x";
        std::cin >> entered_info;
        
        for (int j = 0; j < 2; j++)
        {
            //  Check number
            if ((entered_info[j] >= '0') && (entered_info[j] <= '9'))
            {
                result += ((entered_info[j] - '0') << (1 - j));
            }
            else if ((entered_info[j] >= 'a') && (entered_info[j] <= 'f'))
            {
                result += ((entered_info[j] - 'a' + 10) << (1 - j));
            }
            else if ((entered_info[j] >= 'A') && (entered_info[j] <= 'F'))
            {
                result += ((entered_info[j] - 'A' + 10) << (1 - j));
            }
            else
            {
                std::cout << "Invalid character: " << entered_info[j] << std::endl;
                result_valid = false;
                break;
            }
        }
    }
    std::cout << "Got message: " << (unsigned int)result << std::endl;
    
    return result;
}

void main_loop(usb_dev_handle* dev)
{
    char receive_buffer[256];
    char display_buffer[512];
    char msg = ' ';
    char choice = ' ';
    int status = 0;
    while (choice != 'q')
    {
        std::cout << "Choose one:\n  2 - send to EP2\n  4 - send to EP4\n";
        std::cout << "  6 - print EP6 data\n  8 - print EP8 data\n  q - quit" << std::endl;
        std::cout << "Enter choice here --> ";
        std::cin.get(choice);
        switch (choice)
        {
        case '2':   
            msg = get_msg();
            status = usb_bulk_write(dev, get_endpoint_addr(2), &msg, 1, TIMEOUT_MS);
            if (status < 0)
            {
                std::cout << "Bulk write error (endpoint 2): " << status << std::endl;
                return;
            }
            else
            {
                std::cout << status << " bytes written." << std::endl;
            }
        case '4':   
            msg = get_msg();
            status = usb_bulk_write(dev, get_endpoint_addr(4), &msg, 1, TIMEOUT_MS);
            if (status < 0)
            {
                std::cout << "Bulk write error (endpoint 4): " << status << std::endl;
                return;
            }
            else
            {
                std::cout << status << " bytes written." << std::endl;
            }
        case '6':
            status = usb_bulk_read(dev, get_endpoint_addr(6), receive_buffer, 256, TIMEOUT_MS);
            if (status == 0)
                std::cout << "No data available on endpoint 6." << std::endl;
            else if (status < 0)
            {
                std::cout << "Bulk read error (endpoint 6): " << status << std::endl;
                return;
            }
            else
            {
                sprintf(display_buffer, "");
                for (int i = 0; i < status; i++)
                    sprintf(display_buffer + i * 2, "%x", receive_buffer[i]);
                std::cout << "Message from endpoint 6 (" << status << " bytes): " << display_buffer << std::endl;
            }
        case '8':
            status = usb_bulk_read(dev, get_endpoint_addr(8), receive_buffer, 256, TIMEOUT_MS);
            if (status == 0)
                std::cout << "No data available on endpoint 8." << std::endl;
            else if (status < 0)
            {
                std::cout << "Bulk read error (endpoint 8): " << status << std::endl;
                return;
            }
            else
            {
                sprintf(display_buffer, "");
                for (int i = 0; i < status; i++)
                    sprintf(display_buffer + i * 2, "%x", receive_buffer[i]);
                std::cout << "Message from endpoint 8 (" << status << " bytes): " << display_buffer << std::endl;
            }
        case 'q':
            return;
            break;
        default:
            std::cout << "Unrecognized command" << std::endl;
            break;
        }
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
	        
	        //  Enter a loop sending and receiving 1-byte messages
	        main_loop(target_handle);
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

