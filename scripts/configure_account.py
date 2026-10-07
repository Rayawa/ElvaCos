#!/usr/bin/env python3
"""Apply public AGC identifiers only. Never accepts or stores a client secret."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True, type=Path)
args = parser.parse_args()
config = json.loads(args.config.read_text())
if set(config) not in ({'bundleName', 'clientId'}, {'bundleName', 'clientId', 'appId'}):
    raise SystemExit('Configuration requires bundleName and clientId; appId is optional. Do not supply secrets.')
for name, value in config.items():
    if not isinstance(value, str) or not value.strip() or value.startswith('YOUR_'):
        raise SystemExit('Replace example identifiers with actual AGC values.')
    if not re.fullmatch(r'[A-Za-z0-9._-]{1,255}', value):
        raise SystemExit('Invalid public identifier: ' + name)
root = Path(__file__).resolve().parent.parent
app_path = root / 'AppScope/app.json5'
module_path = root / 'entry/src/main/module.json5'
def read_json5(path):
    # These repository manifests use JSON with trailing commas, no JS expressions.
    return json.loads(re.sub(r',\s*([}\]])', r'\1', path.read_text()))
app = read_json5(app_path)
if app['app']['bundleName'] != config['bundleName']:
    raise SystemExit('AGC bundleName does not match this application. Nothing was modified.')
module = read_json5(module_path)
replaced_names = ['client_id'] + (['app_id'] if 'appId' in config else [])
metadata = [item for item in module['module'].get('metadata', []) if item['name'] not in replaced_names]
metadata.append({'name': 'client_id', 'value': config['clientId']})
if 'appId' in config:
    metadata.append({'name': 'app_id', 'value': config['appId']})
module['module']['metadata'] = metadata
permissions = module['module']['requestPermissions']
if not any(item['name'] == 'ohos.permission.INTERNET' for item in permissions):
    permissions.append({'name': 'ohos.permission.INTERNET'})
module_path.write_text(json.dumps(module, ensure_ascii=False, indent=2) + '\n')
print('Public account identifiers configured. Build and install with the certificate registered in AGC.')
