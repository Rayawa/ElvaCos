#!/usr/bin/env python3
"""Measure only the isolated ElvaCos installed by device-validation.sh.

aa -W supplies native first-frame/foreground timings. The separate observed
data-ready duration includes HDC polling latency and is not a frame metric.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import time

hdc, target, directory = sys.argv[1:]
output = Path(directory)
bundle = 'top.rayawa.elvacos'


def command(*args):
    result = subprocess.run([hdc, '-t', target, 'shell', *args], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=45, check=True)
    return result.stdout


def data_ready():
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        processes = command('ps', '-A', '-o', 'PID,NAME')
        pid = next((row.split()[0] for row in processes.splitlines()
                    if len(row.split()) == 2 and row.split()[1] == bundle), None)
        if pid and pid.isdigit():
            message = command('hilog', '-x', '-P', pid, '-e', 'ElvaCosValidation')
            if 'data-ready' in message:
                return
        time.sleep(0.2)
    raise RuntimeError('Isolated app did not report data-ready within 45 seconds')


def launch(label):
    started = time.monotonic()
    text = command('aa', 'start', '-b', bundle, '-a', 'EntryAbility', '-W')
    (output / (label + '.txt')).write_text(text)
    timing = re.search(r'TotalTime\s*[:=]\s*(\d+)', text)
    mode = re.search(r'StartMode\s*[:=]\s*(\w+)', text)
    if not timing or not mode:
        raise RuntimeError('Missing native aa -W timing: ' + text)
    data_ready()
    return {'label': label, 'mode': mode[1], 'nativeTotalMs': int(timing[1]),
            'observedDataReadyMs': round((time.monotonic() - started) * 1000)}


# Finish fixture import before measuring process-cold starts of the same data.
command('aa', 'force-stop', bundle)
command('aa', 'start', '-b', bundle, '-a', 'EntryAbility')
data_ready()
samples = []
for index in range(3):
    command('aa', 'force-stop', bundle)
    samples.append(launch('startup-cold-' + str(index)))
    command('uitest', 'uiInput', 'keyEvent', 'Home')
    time.sleep(0.5)
    samples.append(launch('startup-hot-' + str(index)))
    time.sleep(0.7)
(output / 'startup-samples.json').write_text(json.dumps(samples, indent=2) + '\n')
print(json.dumps(samples))
