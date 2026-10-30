#!/usr/bin/env python3
"""Retrieve only screenshot names explicitly reported by this Hypium run."""
from pathlib import Path
import re
import subprocess
import sys

hdc, target, report, directory = sys.argv[1:]
output = Path(directory)
names = sorted(set(re.findall(
    r'^UI_SCREENSHOT /data/storage/el2/base/cache/(elvacos-[A-Za-z0-9_.-]+\.png)\s*$',
    Path(report).read_text(), re.MULTILINE)))
if names:
    output.mkdir(parents=True, exist_ok=True)
for name in names:
    result = subprocess.run([
        hdc, '-t', target, 'file', 'recv',
        '/data/app/el2/100/base/top.rayawa.elvacos/cache/' + name,
        str(output / name)
    ], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        timeout=45, check=True)
    if 'FileTransfer finish' not in result.stdout or not (output / name).is_file():
        raise RuntimeError('Screenshot retrieval failed: ' + name + ': ' + result.stdout)
print(f'Retrieved {len(names)} explicitly reported screenshots')
