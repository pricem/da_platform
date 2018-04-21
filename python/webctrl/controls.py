"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    controls.py: API for controlling runtime parameters of DA platform.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

import os.path
import sqlite3

DEFAULT_VOLUME = -40.0

DB_FILE = '%s/settings.db' % os.path.dirname(os.path.abspath(__file__))

conn = sqlite3.connect(DB_FILE)
cursor = conn.cursor()

def table_exists(tablename):
    statement = "SELECT name FROM sqlite_master WHERE type='table';"
    if (tablename,) in cursor.execute(statement).fetchall():
        return True
    else:
        return False

def init():
    if not table_exists('settings'):
        cursor.execute('CREATE TABLE IF NOT EXISTS settings (name VARCHAR(80) PRIMARY KEY, value VARCHAR(80))')
        cursor.execute('INSERT OR REPLACE INTO settings (name, value) VALUES ("volume", ?)', (DEFAULT_VOLUME,))
        conn.commit()

def set_volume(val):
    cursor.execute('UPDATE settings SET value = ? WHERE name = "volume"', (val,))
    conn.commit()

def get_volume():
    cursor.execute('SELECT value FROM settings WHERE name = "volume"')
    r = cursor.fetchone()
    return float(r[0])

if __name__ == '__main__':
    init()
    print get_volume()

