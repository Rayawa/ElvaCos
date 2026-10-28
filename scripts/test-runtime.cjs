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
const originalLoad = Module._load;
Module._load = function(id, parent, isMain) {
    if (id === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion: api, distributionOSApiVersion: api >= 23 ? 60100 : 60000 } };
    if (id === '@kit.ArkUI') return { LengthMetrics: { vp: value => value } };
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
        new CompatibleTabsStyle(true, 1).applyNormalAttribute({ barFloatingStyle() { calls++; }, blurStrategy() { calls++; } });
        assert.equal(calls, api >= 23 ? 2 : 0);
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
})().catch(error => { console.error(error); process.exitCode = 1; });
