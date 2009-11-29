#!/usr/bin/python

def print_concatenation(signal_name, width, num_items, start_item=0):
    result = '{'
    for i in range(num_items + start_item - 1, start_item - 1, -1):
        if width > 1:
            result += '%s[%d:%d]' % (signal_name, (i + 1) * width - 1, i * width)
        else:
            result += '%s[%d]' % (signal_name, i)
        if i > start_item:
            result += ', '
    result += '}'
    print result
    
    
#   For usb_toplevel instantiations
print_concatenation('ep2_port_write', 1, 4)
print_concatenation('ep6_port_data', 1, 4)
print_concatenation('ep6_port_read', 1, 4)

print_concatenation('write_read_data', 1, 4)
print_concatenation('write_read_data', 1, 4, 4)
print_concatenation('write_in_addr', 1, 4)
print_concatenation('write_in_addr', 1, 4, 4)
print_concatenation('write_out_addr', 1, 4)
print_concatenation('write_out_addr', 1, 4, 4)

print_concatenation('read_write_data', 1, 4)
print_concatenation('read_write_data', 1, 4, 4)
print_concatenation('read_in_addr', 1, 4)
print_concatenation('read_in_addr', 1, 4, 4)
print_concatenation('read_out_addr', 1, 4)
print_concatenation('read_out_addr', 1, 4, 4)


print_concatenation('slot_dac_fifo_data', 1, 4)
print_concatenation('slot_adc_fifo_data', 1, 4)
