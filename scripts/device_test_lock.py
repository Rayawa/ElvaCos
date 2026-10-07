#!/usr/bin/env python3
"""Serialize device tests sharing this bundle; another suite must not be force-stopped."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import time

with Path('/private/tmp/elvacos-device-tests.lock').open('a') as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print('Waiting for the current ElvaCos device test to finish.', flush=True)
        fcntl.flock(lock, fcntl.LOCK_EX)
    # Also respect a suite launched before the shared lock was introduced.
    deadline = time.monotonic() + 600
    while subprocess.run(['pgrep', '-f', '/toolchains/[h]dc .*shell aa test'], stdout=subprocess.DEVNULL).returncode == 0:
        if time.monotonic() > deadline:
            raise SystemExit('A device test is still active; leave it running and retry later.')
        time.sleep(2)
    env = dict(os.environ)
    env['ELVACOS_DEVICE_TEST_LOCKED'] = '1'
    raise SystemExit(subprocess.run(sys.argv[1:], env=env).returncode)
