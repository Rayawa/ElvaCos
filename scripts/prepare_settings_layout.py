#!/usr/bin/env python3
"""Build-only replica host; never add a test ability to the production manifest."""
import json
from pathlib import Path
import shutil
import tempfile

source = Path(__file__).resolve().parent.parent
target = Path(tempfile.mkdtemp(prefix='elvacos-settings-layout-', dir='/private/tmp'))
ignored = shutil.ignore_patterns('build', 'oh_modules', 'node_modules', '.hvigor', '__pycache__')
for directory in ('AppScope', 'entry', 'scripts', 'hvigor'):
    shutil.copytree(source / directory, target / directory, ignore=ignored)
for path in source.iterdir():
    if path.is_file() and path.suffix in ('.json5', '.json', '.ts', '.properties'):
        shutil.copy2(path, target / path.name)
for dependency in ('oh_modules', 'node_modules', 'entry/oh_modules'):
    if (source / dependency).exists():
        shutil.copytree(source / dependency, target / dependency)

test_root = target / 'entry/src/ohosTest'
main_root = target / 'entry/src/main'
ability_directory = main_root / 'ets/testability'
ability_directory.mkdir()
shutil.copy2(test_root / 'ets/testability/SettingsLayoutAbility.ets', ability_directory)
(ability_directory / 'pages').mkdir()
page = (test_root / 'ets/testability/pages/SettingsLayout.ets').read_text()
(ability_directory / 'pages/SettingsLayout.ets').write_text(page.replace('../../../../main/ets/', '../../'))

manifest = main_root / 'module.json5'
ability = json.dumps({
    'name': 'SettingsLayoutAbility',
    'srcEntry': './ets/testability/SettingsLayoutAbility.ets',
    'icon': '$media:app_icon',
    'label': '$string:EntryAbility_label',
    'startWindowIcon': '$media:app_icon',
    'startWindowBackground': '$color:start_window_background',
    'exported': False,
}, ensure_ascii=False)
manifest_text = manifest.read_text()
ability_list = '\n    "abilities": ['
if manifest_text.count(ability_list) != 1:
    shutil.rmtree(target)
    raise SystemExit('Cannot identify the module ability list; leave production manifest unchanged.')
manifest.write_text(manifest_text.replace(ability_list, ability_list + ability + ',', 1))
pages_path = main_root / 'resources/base/profile/main_pages.json'
pages = json.loads(pages_path.read_text())
pages['src'].append('testability/pages/SettingsLayout')
pages_path.write_text(json.dumps(pages, ensure_ascii=False, indent=2) + '\n')

# The feature remains only a runner. ArkUI renders entry resources from the cloned main HAP.
test_manifest = test_root / 'module.json5'
test_module = json.loads(test_manifest.read_text())
for key in ('pages', 'abilities', 'mainElement'):
    test_module['module'].pop(key, None)
test_manifest.write_text(json.dumps(test_module, ensure_ascii=False, indent=2) + '\n')
print(target)
