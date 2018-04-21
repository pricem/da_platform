#!/usr/bin/env python

"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    main.py: RPC controller for DA platform.
    Current function:
    - Volume control - set gain in dB from -100 to 0
    Assumes synchronous, single-threaded operation. 
       
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
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
