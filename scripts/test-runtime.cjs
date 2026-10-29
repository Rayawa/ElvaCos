#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const studio = (process.env.DEVECO_HOME || path.join(process.env.HOME, 'Applications/DevEco-Studio.app')).replace(/\/Contents$/, '') + '/Contents';
const compilerPath = path.join(studio, 'tools/ohpm/node_modules/typescript');
const compiler = fs.existsSync(compilerPath) ? require(compilerPath) : require('./host-typescript.cjs');
const root = path.resolve(__dirname, '../entry/src/main/ets');
let api = 20;
let haptic = { open: 0, back: 0 };
const storage = new Map([['vibrationLevel', 1]]);
global.$r = value => value;
global.AppStorage = { get: key => storage.get(key) };
global.ObservedV2 = value => value;
global.canIUse = () => true;
global.SheetSize = { LARGE: 1 };
global.SheetType = { BOTTOM: 1 };
global.BlurStyle = { COMPONENT_ULTRA_THICK: 1 };
global.KeyType = { Down: 0, Up: 1 };
global.Color = { Transparent: '#00000000' };
Object.defineProperty(global, 'TabsCacheMode', { get() {
    assert(api >= 23, `API ${api} resolved the newer native tab cache enum`);
    return { CACHE_LATEST_SWITCHED: 1 };
} });
const originalLoad = Module._load;
Module._load = function(id, parent, isMain) {
    if (id === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion: api, distributionOSApiVersion: api >= 23 ? 60100 : 60000 } };
    if (id === '@kit.ArkUI') return { LengthMetrics: { vp: value => value } };
    if (id === '@kit.InputKit') return { KeyCode: { KEYCODE_1: 2001, KEYCODE_5: 2005, KEYCODE_F: 2022, KEYCODE_N: 2030, KEYCODE_COMMA: 2043, KEYCODE_ESCAPE: 2070 } };
    if (id === '@kit.ArkGraphics2D') return { uiEffect: { createFilter: () => ({ hdrBrightnessRatio(value) { assert(api >= 24); return { hdr: value }; } }) } };
    if (id === '@kit.UIDesignKit') {
        const effect = {};
        Object.defineProperties(effect, Object.fromEntries(['HdsEffectBuilder', 'PointLightIlluminatedType', 'PointLightSourceType'].map(key => [key, { get() {
            assert(api >= 23, `API ${api} resolved a newer HDS symbol: ${key}`);
            if (key === 'HdsEffectBuilder') return class { pointLight(value) { this.value = value; return this; } buildEffect() { return { light: this.value }; } };
            return { BORDER: 1, BORDER_CONTENT: 2, NONE: 0, SOFT: 1, BRIGHT: 2 };
        } }])));
        return { hdsEffect: effect, BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { GRADIENT_BLUR: 1 } };
    }
    if (id.endsWith('/Theme')) return { Theme: new Proxy({}, { get: (_target, key) => key }) };
    if (id.endsWith('/constants')) return { STORAGE_KEY_VISUAL_EFFECTS: 'effects', DEFAULT_LIGHT_FIELD_LEVEL: 1, STORAGE_KEY_LIGHT_FIELD_LEVEL: 'light', STORAGE_KEY_VIBRATION_LEVEL: 'vibrationLevel', HDS_TITLE_SIZE_SMALL: 0 };
    if (id.endsWith('/format')) return { displayName: value => value };
    // PhotoRows uses entity imports only as types; native model decorators are outside these host checks.
    if (id.endsWith('/Entities')) return {};
    if (id.endsWith('/motion')) return {};
    if (id.endsWith('/HapticService')) return { HapticService: { confirm: enabled => { if (enabled) haptic.open++; }, back: enabled => { if (enabled) haptic.back++; } } };
    return originalLoad.call(this, id, parent, isMain);
};
require.extensions['.ets'] = (module, filename) => module._compile(compiler.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: compiler.ModuleKind.CommonJS, target: compiler.ScriptTarget.ES2021 } }).outputText, filename);
const fresh = relative => {
    const filename = path.join(root, relative);
    delete require.cache[filename];
    return require(filename);
};
const flush = async () => { for (let i = 0; i < 10; i++) await Promise.resolve(); };
(async () => {
    for (api = 20; api <= 26; api++) {
        fresh('config/platformCompatibility.ets');
        const { CompatibleTabsStyle } = fresh('config/SystemCapability.ets');
        let calls = 0;
        new CompatibleTabsStyle(true, 1, 5).applyNormalAttribute({ barFloatingStyle() { calls++; }, blurStrategy() { calls++; }, cachedMaxCount(count, mode) { assert.equal(count, 5); assert.equal(mode, 1); calls++; } });
        assert.equal(calls, api >= 23 ? 3 : 0);
        const effects = fresh('ui/feedback/visualEffects.ets');
        const light = effects.pressVisualEffect(true, true);
        assert.equal(!!light, api >= 23);
        storage.set('light', 2);
        const filter = effects.pressLightFieldFilter(true);
        assert.equal('hdr' in filter, api >= 24);
        storage.delete('light');
        console.log(`PASS API ${api}: native tab material, light field and HDR access guards`);
    }
    const sheet = fresh('ui/sheet/sheet.ets');
    const entrance = { reset() {}, play() {}, finish() {} };
    let closed = 0, allow = false;
    const options = sheet.appSheetOptions(() => {}, entrance, {}, 1, async () => allow, () => closed++);
    options.onAppear();
    const sheetKey = (keyCode, modifiers = []) => ({ type: KeyType.Down, keyCode, metaKey: 0, getModifierKeyState: keys => keys.every(key => modifiers.includes(key)) });
    assert.equal(sheet.handleSheetKey(sheetKey(2030)), false, 'ordinary form input stays native');
    assert.equal(sheet.handleSheetKey(sheetKey(2070, ['Ctrl'])), false, 'modified Escape stays native');
    assert.equal(sheet.handleSheetKey(sheetKey(2070)), true);
    await flush();
    assert.equal(closed, 0, 'sheet Escape uses the same unsaved-edit guard');
    assert.equal(sheet.handleSheetBack(), true);
    await flush();
    assert.equal(closed, 0, 'hardware back preserves rejected edits');
    allow = true;
    assert.equal(sheet.handleSheetBack(), true);
    await flush();
    assert.equal(closed, 1);
    // A reactive options rebuild must release the same native host identity.
    const rebuilt = sheet.appSheetOptions(() => {}, entrance, {});
    rebuilt.onDisappear();
    assert.equal(sheet.handleSheetBack(), false);
    assert.equal(haptic.open, 1);
    assert.equal(haptic.back, 1);
    console.log('PASS sheet identity survives option rebuilds; hardware back respects unsaved-edit guards');
    let inlineClosed = 0, dismissed = 0;
    sheet.registerInlineSheetBack('editor', async () => { inlineClosed++; sheet.releaseInlineSheetBack('editor'); });
    await sheet.dismissSheet({ dismiss() { dismissed++; } });
    assert.equal(inlineClosed, 1);
    assert.equal(dismissed, 0, 'first gesture leaves the owner sheet mounted');
    await sheet.dismissSheet({ dismiss() { dismissed++; } }, async () => false);
    assert.equal(dismissed, 0);
    await sheet.dismissSheet({ dismiss() { dismissed++; } });
    assert.equal(dismissed, 1);
    console.log('PASS nested editor reuses owner sheet and closes before the owner');
    const { sdkProfile } = require('./configure_sdk.cjs');
    const profile = `{ // local signing stays local
 app: { signingConfigs: [{ name: 'local', password: 'keep-value' }], products: [{ targetSdkVersion: '25.0.0', compatibleSdkVersion: '6.1.0(23)' }] } }`;
    const updated = sdkProfile(profile);
    assert.match(updated, /targetSdkVersion: "26.0.0"/);
    assert.match(updated, /compatibleSdkVersion: "6.0.0\(20\)"/);
    assert.match(updated, /password: 'keep-value'/);
    assert.match(updated, /local signing stays local/);
    assert.equal(sdkProfile(updated), updated);
    assert.throws(() => sdkProfile('{}'), /missing targetSdkVersion/);
    console.log('PASS build profile applies API20/API26 without replacing local signing or product options');
    const { groupBy, indexById } = fresh('models/RecordIndex.ets');
    const records = Array.from({ length: 10000 }, (_, id) => ({ id: String(id), owner: String(id % 100) }));
    const groups = groupBy(records, item => item.owner);
    assert.equal(groups.size, 100);
    for (let owner = 0; owner < 100; owner++) assert.deepEqual(groups.get(String(owner)), records.filter(item => item.owner === String(owner)));
    const index = indexById(records, record => record.id);
    for (const record of records) assert.equal(index.get(record.id), record);
    assert.equal(index.get('missing'), undefined);
    console.log('PASS relation indexes preserve record identity, ordering and query results for 10,000 records');
    const responsive = fresh('config/responsive.ets');
    for (const [width, photos, cards] of [[320, 2, 1], [599, 2, 1], [600, 3, 2], [839, 3, 2], [840, 4, 2], [1440, 4, 2], [599, 2, 1]]) {
        assert.equal(responsive.photoColumnCount(width), photos);
        assert.equal(responsive.cardColumnCount(width), cards);
    }
    assert.equal(responsive.RESPONSIVE_BREAKPOINT_MEDIUM, '600vp');
    assert.equal(responsive.RESPONSIVE_BREAKPOINT_LARGE, '840vp');
    console.log('PASS dashboard breakpoint boundaries and shrink-back layouts at 320/599/600/839/840/1440vp');
    const { AppShortcut, resolveAppShortcut } = fresh('ui/input/shortcuts.ets');
    for (let index = 0; index < 5; index++) assert.equal(resolveAppShortcut(2001 + index, true, false, false, false), index);
    assert.equal(resolveAppShortcut(2022, true, false, false, false), AppShortcut.SEARCH);
    assert.equal(resolveAppShortcut(2030, true, false, false, false), AppShortcut.CREATE);
    assert.equal(resolveAppShortcut(2043, true, false, false, false), AppShortcut.SETTINGS);
    assert.equal(resolveAppShortcut(2070, false, false, false, false), AppShortcut.BACK);
    for (const code of [2001, 2022, 2030, 2043, 2049, 2050]) assert.equal(resolveAppShortcut(code, false, false, false, false), AppShortcut.NONE, 'ordinary input belongs to native controls');
    for (const modifiers of [[true, true, false, false], [true, false, true, false], [true, false, false, true]]) assert.equal(resolveAppShortcut(2022, ...modifiers), AppShortcut.NONE);
    console.log('PASS keyboard commands preserve ordinary input and modified system combinations');
    const { groupPhotoRows, indexPhotoRows, changedPhotoRows } = fresh('domain/photos/PhotoRows.ets');
    const photos = Array.from({ length: 10000 }, (_, index) => ({ id: String(index) }));
    for (const columns of [2, 3, 4]) {
        const rows = groupPhotoRows(photos, columns), positions = indexPhotoRows(rows);
        const changed = changedPhotoRows(positions, new Set(['1', '2', '9999']), new Set(['2', '3', 'missing']));
        const expected = [...new Set([Math.floor(1 / columns), Math.floor(3 / columns), Math.floor(9999 / columns)])];
        assert.deepEqual(changed.sort((a, b) => a - b), expected.sort((a, b) => a - b));
        assert.deepEqual(changedPhotoRows(positions, new Set(['2']), new Set(['2'])), []);
    }
    console.log('PASS selecting photos only invalidates changed rows across all three responsive column counts');
})().catch(error => { console.error(error); process.exitCode = 1; });
