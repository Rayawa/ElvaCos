#!/usr/bin/env python3
"""Create a build-only UI validation replica with isolated persistence.

Uses the real EntryAbility, pages and services. Install the normal HAP again
after testing; never launch the personal-data build during this session.
"""
from pathlib import Path
import re
import shutil
import tempfile

source = Path(__file__).resolve().parent.parent
target = Path(tempfile.mkdtemp(prefix='elvacos-device-validation-', dir='/private/tmp'))
namespace = 'verification-ui-' + target.name.removeprefix('elvacos-device-validation-')
ignored = shutil.ignore_patterns('build', 'oh_modules', 'node_modules', '.hvigor', '__pycache__')
for directory in ('AppScope', 'entry', 'scripts', 'hvigor'):
    shutil.copytree(source / directory, target / directory, ignore=ignored)
for path in source.iterdir():
    if path.is_file() and path.suffix in ('.json5', '.json', '.ts', '.properties'):
        shutil.copy2(path, target / path.name)
for dependency in ('oh_modules', 'node_modules', 'entry/oh_modules'):
    if (source / dependency).exists():
        shutil.copytree(source / dependency, target / dependency)


def replace_once(relative, old, new):
    path = target / relative
    text = path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f'Isolation boundary changed: {relative}: {old}')
    path.write_text(text.replace(old, new))


root = 'entry/src/main/ets/'
try:
    replace_once(root + 'services/storage/database/Database.ets',
                 "constructor(name: string = 'personal.db')",
                 f"constructor(name: string = '{namespace}.db')")
    replace_once(root + 'services/media/MediaRepository.ets',
                 "testRoot || context.filesDir + '/media'",
                 f"testRoot || context.filesDir + '/{namespace}-media'")
    # Also isolate legacy migration reads, account, drafts and every setting.
    constants = target / root / 'config/constants.ets'
    text = constants.read_text()
    pattern = r"(export const (?:LEGACY_APP_SETTINGS_FILE_NAME|LEGACY_PROFILE_FILE_NAME|LEGACY_SETTINGS_FILE_NAME|STORAGE_FILE_NAME) = )'([^']+)';"
    text, count = re.subn(pattern, lambda match: match[1] + "'" + namespace + "-" + match[2] + "';", text)
    if count != 4:
        raise RuntimeError('Expected all four preference file boundaries')
    constants.write_text(text)
    replace_once(root + 'services/settings/storage.ets',
                 "getDiskStorageInstance('settings', ctx)",
                 f"getDiskStorageInstance('{namespace}-settings', ctx)")
    replace_once(root + 'pages/Dashboard.ets',
                 'await this.state.start(this.getUIContext().getHostContext() as common.UIAbilityContext);',
                 'await this.state.start(this.getUIContext().getHostContext() as common.UIAbilityContext);\n'
                 "            if (this.state.ready) { console.info('[ElvaCosValidation] data-ready'); }")
except Exception:
    shutil.rmtree(target)
    raise
print(target)
