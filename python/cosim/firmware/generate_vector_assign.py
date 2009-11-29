#!/usr/bin/python

#   Generate assign statements to convert a list of bit vectors into a single wide bit vector.
def print_statements(signal_name, width, num_items, reverse=False):
    lhs_str = "%(signal_name)s[%(item)d]"
    rhs_str = "%(signal_name)ss[%(msb)d:%(lsb)d]"
    base_str = "assign %s = %s;"
    for i in range(num_items):
        var_dict = {'signal_name': signal_name, 'item': i, 'msb': (i + 1) * width - 1, 'lsb': i * width}
        lhs = lhs_str % var_dict
        rhs = rhs_str % var_dict
        if reverse:
            print base_str % (rhs, lhs)
        else:
            print base_str % (lhs, rhs)

#   For memory_arbitrator
print '//  Automatically generated statements'
print_statements('write_in_addr', 11, 8)
print_statements('write_out_addr', 11, 8)
print_statements('write_read_data', 8, 8)
print_statements('read_in_addr', 11, 8)
print_statements('read_out_addr', 11, 8)
print_statements('read_write_data', 8, 8, reverse=True)
print_statements('write_fifo_byte_count', 32, 8)
print_statements('read_fifo_byte_count', 32, 8, reverse=True)

