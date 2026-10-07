#!/usr/bin/env python3
"""Verify final Release archives against the current public source configuration.

This checks package contents; SDK verify-app separately verifies cryptographic
signatures and the signing Profile determines the distribution scope.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inspect_hap(data, source_app, source_module):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(archive.testzip() is None, 'HAP ZIP integrity failed')
        manifest = json.loads(archive.read('module.json'))
        app = manifest['app']
        module = manifest['module']
        for key in ['bundleName', 'vendor', 'versionName', 'versionCode', 'buildVersion']:
            require(app[key] == source_app[key], 'HAP/source mismatch: ' + key)
        require(app['buildMode'] == 'release' and app['debug'] is False,
                'Expected a Release HAP with debug=false')
        require(app['minAPIVersion'] == 60100023 and app['targetAPIVersion'] == 260000026,
                'Expected compatible API 23 / target API 26')
        for key in ['name', 'type', 'mainElement', 'deviceTypes', 'metadata']:
            require(module[key] == source_module[key], 'Module/source mismatch: ' + key)
        require(module['requestPermissions'] == source_module['requestPermissions'] or
                [{k: v for k, v in p.items() if k != 'reasonId'} for p in module['requestPermissions']]
                == source_module['requestPermissions'], 'Permission/source mismatch')
        require([a['name'] for a in module['abilities']] == ['EntryAbility'],
                'Unexpected production Ability')
        require([(a['name'], a['type'], a['exported']) for a in module['extensionAbilities']]
                == [('EntryBackupAbility', 'backup', False)], 'Unexpected extension Ability')
        names = archive.namelist()
        require(not any('ohosTest' in n or 'TestRunner' in n for n in names),
                'Test files found in production HAP')
        require(not any(n.endswith(('.p12', '.p7b', '.cer', '.pem', '.DS_Store')) or
                        'build-profile' in n for n in names), 'Private/local file found in HAP resources')
        for path in (ROOT / 'entry/src/main/resources/rawfile').rglob('*'):
            if path.is_file():
                name = 'resources/rawfile/' + str(path.relative_to(ROOT / 'entry/src/main/resources/rawfile'))
                require(archive.read(name) == path.read_bytes(), 'Raw resource/source mismatch: ' + name)
        require(len([n for n in names if n.startswith('resources/rawfile/demo/')]) == 34,
                'Expected demo JSON sources/dataset plus 32 JPEGs')
        return {'version': app['versionName'], 'build': app['versionCode'],
                'mode': app['buildMode'], 'debug': app['debug'],
                'compatible_api': 23, 'target_api': 26, 'demo_files': 34,
                'permissions': [p['name'] for p in module['requestPermissions']]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hap', type=Path, default=ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap')
    parser.add_argument('--app', type=Path, default=ROOT / 'build/outputs/default/ElvaCos-default-signed.app')
    args = parser.parse_args()
    # These two source manifests contain standard JSON, despite their json5 suffix.
    app = json.loads((ROOT / 'AppScope/app.json5').read_text())['app']
    module = json.loads((ROOT / 'entry/src/main/module.json5').read_text())['module']
    constants = (ROOT / 'entry/src/main/ets/common/constants.ets').read_text()
    require(re.search(r"APP_VERSION = '([^']+)'", constants)[1] == app['versionName'],
            'APP_VERSION/source mismatch')
    require(int(re.search(r'APP_BUILD_NUMBER = (\d+)', constants)[1]) == app['versionCode'],
            'APP_BUILD_NUMBER/source mismatch')
    require("date: '2026-10-08'" in constants, 'Beta release note date mismatch')
    result = inspect_hap(args.hap.read_bytes(), app, module)
    with zipfile.ZipFile(args.app) as archive:
        require(archive.testzip() is None, 'APP ZIP integrity failed')
        hap_names = [n for n in archive.namelist() if n.endswith('.hap')]
        require(hap_names == ['entry-default.hap'], 'Unexpected APP modules')
        require(inspect_hap(archive.read(hap_names[0]), app, module) == result,
                'APP embedded HAP differs from standalone HAP configuration')
    result['artifacts'] = [{'name': p.name, 'bytes': p.stat().st_size,
                            'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                           for p in [args.hap, args.app]]
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print('PASS: version, Release mode, APIs, permissions, abilities, raw resources and APP contents')


if __name__ == '__main__':
    main()
