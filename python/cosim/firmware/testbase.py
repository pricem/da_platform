""" Base classes for MyHDL testing framework. """

from myhdl import now, intbv

#   These functions print list/dictionary combinations but replace integers with
#   their hexadecimal equivalents.
def format_list(l):
    #   If the items are intbvs, concatenate them together and print the whole thing in hex. 
    if type(l[0]) == intbv:
        accum_result = 0
        accum_bits = 0
        for i in range(len(l)):
            item = l[len(l) - i - 1]
            accum_result += (item << accum_bits)
            accum_bits += item._nrbits
        format_str = '0x%%0%dX' % ((accum_bits - 1) / 4 + 1)
        return format_str % accum_result

    #   Otherwise treat it as a list.
    result = '['
    for i in range(len(l)):
        item = l[i]
        if type(item) is list:
            result += format_list(item)
        elif type(item) is dict:
            result += format_dict(item)
        elif (type(item) is intbv):
            bits = item._nrbits
            format_str = '0x%%0%dX' % ((bits - 1) / 4 + 1)
            result += format_str % item
        else:
            result += str(item)
        if i != len(l) - 1:
            result += ', '
    result += ']'
    return result

def format_dict(d):
    result = '{'
    keys = d.keys()
    for i in range(len(keys)):
        key = keys[i]
        item = d[key]
        result += '%s: ' % key
        if type(item) is list:
            result += format_list(item)
        elif type(item) is dict:
            result += format_dict(item)
        elif (type(item) is intbv):
            bits = item._nrbits
            format_str = '0x%%0%dx' % ((bits - 1) / 4 + 1)
            result += format_str % item
        else:
            result += unicode(item)
        if i != len(keys) - 1:
            result += ', '
        
    result += '}'
    return result    
    

class Event(object):
    def __init__(self, event_type, params, *args, **kwargs):
        self.time = now()
        self.event_type = event_type
        self.params = params
        
    def __unicode__(self):
        return 'T = %8d %s: %s' % (self.time, self.event_type, format_dict(self.params))

class Action(object):
    def __init__(self, time, action, *args, **kwargs):
        self.time = time
        self.action = action
        self.args = args
        self.kwargs = kwargs
        
    def execute(self):
        self.action(*self.args, **self.kwargs)
        
class RecurrentAction(Action):
    def __init__(self, period, *args, **kwargs):
        super(RecurrentAction, self).__init__(*args, **kwargs)
        self.period = period

    def execute(self, *args, **kwargs):
        super(RecurrentAction, self).execute(*args, **kwargs)
        self.time = self.time + self.period
        

class TestBase(object):
    def __init__(self, *args, **kwargs):
        self.parent = None
        if 'parent' in kwargs:
            self.parent = kwargs['parent']
            
    def log(self, message):
        if hasattr(self, 'parent'):
            self.parent.log(message)
        else:
            print message

    def handle_event(self, event):
        if hasattr(self, 'parent'):
            self.parent.handle_event(event)

