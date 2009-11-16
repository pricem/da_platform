from myhdl import *
from test_settings import *

def instantiate(module, *args, **kwargs):
    if USE_TRACE:
        return traceSignals(module, *args, **kwargs)
    else:
        return module(*args, **kwargs)

