#!/usr/bin/env python

"""
RPC controller for DA platform.
Current function:
- Volume control - set gain in dB from -100 to 0

Assumes synchronous, single-threaded operation.
"""

from bottle import route, request, run, get

import controls

@route('/volume')
def volume():
    return open('volume.html').read()

@route('/set_volume', method='POST')
def set_volume():
    assert 'volume' in request.forms
    val = float(request.forms.get('volume', '-100'))
    controls.set_volume(val)

@route('/get_volume')
def get_volume():
    return {'volume': controls.get_volume(),}

run(host = '192.168.0.198', port = '8080')
