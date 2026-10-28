#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const files = walk(root).filter(file => file.endsWith('.ets'));
let imports = 0;
for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    for (const match of source.matchAll(/from\s+['"](\.[^'"]+)['"]/g)) {
        const target = path.resolve(path.dirname(file), match[1]);
        assert(fs.existsSync(target + '.ets') || fs.existsSync(target + '.ts') || fs.existsSync(target), `${file}: missing ${match[1]}`);
        imports++;
    }
    assert((source.match(/\.bindSheet\(/g) || []).length <= 1, `${file}: combine native sheet content in one host`);
    assert(!source.includes('\t'), `${file}: use spaces for indentation`);
    source.split('\n').forEach((line, index) => {
        assert((line.match(/^ */)[0].length % 4) === 0, `${file}:${index + 1}: indentation must use four spaces`);
    });
}
for (const old of ['common', 'component', 'model', 'data', 'pages/more']) assert(!fs.existsSync(path.join(root, old)), `mixed directory remains: ${old}`);
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
assert.match(read('pages/Dashboard.ets'), /onBackPress\(\): boolean/);
assert.match(read('pages/Dashboard.ets'), /handleSheetBack\(\)/);
assert.match(read('components/navigation/DetailDestination.ets'), /\.onBackPressed\(/);
assert.match(read('components/navigation/DetailDestination.ets'), /this\.foreground = false/);
assert.match(read('components/navigation/DetailDestination.ets'), /SUPPORTS_API_26/);
assert.match(read('components/navigation/HdsViewTabs.ets'), /HdsTabs\(/);
assert.match(read('pages/Dashboard.ets'), /root-action-设置/);
assert(!read('components/common/SheetHeader.ets').includes('Text(this.hint)'), 'sheet titles must not stack a subtitle');
for (const name of ['ProjectDetailPage', 'CharacterDetailPage', 'EventDetailPage']) {
    const source = read('pages/detail/' + name + '.ets');
    for (const match of source.matchAll(/EntryCollectionView\(\{([\s\S]*?)\}\)/g)) assert.match(match[1], /embedded:\s*true/, `${name}: do not mount an editor sheet inside an owner sheet`);
}
const profile = fs.readFileSync(path.resolve(__dirname, '../build-profile.example.json5'), 'utf8');
assert.match(profile, /compatibleSdkVersion.*6\.0\.0\(20\)/);
assert.match(profile, /targetSdkVersion.*26\.0\.0/);
console.log(`PASS ${files.length} source files, ${imports} relative imports, directory ownership, native navigation, sheet and compatibility contracts`);
