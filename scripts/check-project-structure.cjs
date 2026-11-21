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
const layers = ['ability', 'components', 'models', 'pages', 'services', 'ui', 'utils', 'viewmodels', 'views'];
const rootEntries = fs.readdirSync(root, { withFileTypes: true });
assert.deepEqual(rootEntries.filter(entry => entry.isFile()).map(entry => entry.name), ['index.ets']);
assert.deepEqual(rootEntries.filter(entry => entry.isDirectory()).map(entry => entry.name).sort(), layers);
for (const layer of layers) {
    const subdirectories = fs.readdirSync(path.join(root, layer), { withFileTypes: true })
        .filter(entry => entry.isDirectory()).map(entry => entry.name);
    assert.deepEqual(subdirectories, layer === 'services' ? ['storage'] : [], `${layer}: keep the ETS layout flat`);
}
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const mainPages = JSON.parse(fs.readFileSync(path.resolve(root, '../resources/base/profile/main_pages.json'), 'utf8'));
assert.deepEqual(mainPages.src, ['index']);
assert.match(read('ability/entry.ets'), /loadContent\('index',/);
assert.match(read('index.ets'), /^@Entry\b/m);
assert.match(read('index.ets'), /onBackPress\(\): boolean/);
assert.match(read('index.ets'), /handleSheetBack\(\)/);
assert.match(read('components/DetailDestination.ets'), /\.onBackPressed\(/);
assert.match(read('components/DetailDestination.ets'), /this\.foreground = false/);
assert.match(read('components/DetailDestination.ets'), /SUPPORTS_API_26/);
assert.match(read('components/HdsViewTabs.ets'), /HdsTabs\(/);
assert.match(read('index.ets'), /root-action-设置/);
assert(!read('components/SheetHeader.ets').includes('Text(this.hint)'), 'sheet titles must not stack a subtitle');
for (const name of ['ProjectDetailPage', 'CharacterDetailPage']) {
    const source = read('pages/' + name + '.ets');
    for (const match of source.matchAll(/EntryCollectionView\(\{([\s\S]*?)\}\)/g)) assert.match(match[1], /embedded:\s*true/, `${name}: do not mount an editor sheet inside an owner sheet`);
}
// Event's collection is a full-page view, so it owns an editor host only while
// the event's tool host is absent. Collections inside owner sheets stay embedded.
const event = read('pages/EventDetailPage.ets');
assert.match(event, /if \(!this\.route\.dayMode && this\.route\.section === 2 && !this\.nativeSheetVisible\(\)\) \{\s*EntryCollectionView\(\{ embedded: false/);
assert.match(event, /EntryCollectionView\(\{ embedded: true/);
assert.match(event, /\.bindSheet\(this\.nativeSheetVisible\(\),/);
const profile = fs.readFileSync(path.resolve(__dirname, '../build-profile.example.json5'), 'utf8');
assert.match(profile, /compatibleSdkVersion.*6\.0\.0\(20\)/);
assert.match(profile, /targetSdkVersion.*26\.0\.0/);
console.log(`PASS ${files.length} source files, ${imports} relative imports, directory ownership, native navigation, sheet and compatibility contracts`);
