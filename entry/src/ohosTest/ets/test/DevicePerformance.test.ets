import { captureScreenshot } from '../testability/UiEvidence';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { hidebug } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { describe, beforeAll, afterAll, afterEach, it, expect } from '@ohos/hypium';
import { getApplicationState } from '../../../main/ets/state/appState';
import { Asset } from '../../../main/ets/models/Entities';

interface ProcessResources {
    pssKb: number;
    nativeHeapBytes: number;
    cpuUsage: number;
}

@Concurrent
function processResources(): ProcessResources {
    return { pssKb: Number(hidebug.getPss()), nativeHeapBytes: Number(hidebug.getNativeHeapAllocatedSize()), cpuUsage: hidebug.getCpuUsage() };
}

function percentile(values: number[], fraction: number): number {
    const ordered = values.slice().sort((left: number, right: number): number => left - right);
    return ordered.length ? ordered[Math.min(ordered.length - 1, Math.floor(ordered.length * fraction))] : 0;
}

// Native layout/input timings are intentionally separate from automation wall time.
// FrameMetrics does not measure GPU completion or prove end-to-end frame pacing.
export default function devicePerformanceTest(started: number): void {
    describe('DevicePerformance', () => {
        const bundle = 'top.rayawa.elvacos';
        const profile = abilityDelegatorRegistry.getArguments().parameters['-s profile'] === 'true';
        let driver: Driver;
        let appWindow: window.Window;
        let previousKeepScreenOn = false;
        let originalScale = 1;
        let originalAppearance = '';
        let caseNumber = 0;
        let layout: number[] = [];
        let input: number[] = [];
        const measured = (frame: window.FrameMetrics): void => {
            layout.push(frame.layoutMeasureDuration / 1000000);
            input.push(frame.inputHandlingDuration / 1000000);
        };
        const resources = async (phase: string): Promise<void> => {
            const sample = await taskpool.execute(processResources) as ProcessResources;
            await abilityDelegatorRegistry.getAbilityDelegator().print('DEVICE_RESOURCES ' + JSON.stringify({
                phase: phase, scope: 'debug app with Hypium', pssKb: sample.pssKb,
                nativeHeapBytes: sample.nativeHeapBytes, cpuUsage: sample.cpuUsage
            }) + '\n');
        };
        const report = async (scenario: string): Promise<void> => {
            expect(layout.length > 0).assertTrue();
            await abilityDelegatorRegistry.getAbilityDelegator().print('DEVICE_FRAMES ' + JSON.stringify({
                scenario: scenario, api: deviceInfo.sdkApiVersion, device: deviceInfo.deviceType,
                samples: layout.length, layoutP50Ms: percentile(layout, 0.5), layoutP95Ms: percentile(layout, 0.95),
                layoutMaxMs: Math.max(...layout), inputP95Ms: percentile(input, 0.95),
                layoutOver16Ms: layout.filter((value: number): boolean => value > 16.67).length
            }) + '\n');
            layout = [];
            input = [];
        };
        const root = async (index: number): Promise<void> => {
            await (await driver.findWindow({ bundleName: bundle })).focus();
            await driver.triggerCombineKeys(KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_1 + index);
            await driver.delayMs(400);
            const actions: string[] = ['设置', '新建计划', '添加活动', '添加装备', '导入照片'];
            expect(!!await driver.waitForComponent(ON.id('root-action-' + actions[index]).inWindow(bundle), 3000)).assertTrue();
        };
        beforeAll(async () => {
            driver = Driver.create();
            for (let attempt = 0; attempt < 100 && !getApplicationState().ready; attempt++) {
                await driver.delayMs(100);
            }
            expect(getApplicationState().ready).assertTrue();
            const delegator = abilityDelegatorRegistry.getAbilityDelegator();
            const ability = await delegator.getCurrentTopAbility();
            appWindow = await window.getLastWindow(ability.context);
            previousKeepScreenOn = appWindow.getWindowProperties().isKeepScreenOn;
            await appWindow.setWindowKeepScreenOn(true);
            const info = display.getDefaultDisplaySync();
            await delegator.print('DEVICE_READY ' + JSON.stringify({
                automationReadyMs: Date.now() - started, model: deviceInfo.productModel,
                api: deviceInfo.sdkApiVersion, device: deviceInfo.deviceType,
                widthPx: info.width, heightPx: info.height, density: info.densityPixels,
                window: appWindow.getWindowProperties().windowRect
            }) + '\n');
            originalScale = ability.context.config.fontSizeScale || 1;
            originalAppearance = getApplicationState().settings.appearance;
            ability.context.getApplicationContext().setFontSizeScale(1);
            expect(await getApplicationState().updateSettings({ appearance: 'mist' })).assertTrue();
            await driver.delayMs(700);
            if (deviceInfo.sdkApiVersion < 22) {
                throw new Error('Native FrameMetrics requires API22; use system tracing on earlier APIs');
            }
            appWindow.on('frameMetricsMeasured', measured);
            await resources('ready');
        });
        afterAll(async () => {
            if (appWindow) {
                if (deviceInfo.sdkApiVersion >= 22) {
                    appWindow.off('frameMetricsMeasured', measured);
                }
                await appWindow.setWindowKeepScreenOn(previousKeepScreenOn);
                const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
                ability.context.getApplicationContext().setFontSizeScale(originalScale);
                await getApplicationState().updateSettings({ appearance: originalAppearance });
            }
        });
        afterEach(async () => {
            await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-performance-case-' + (++caseNumber) + '.png');
        });
        it('recordsNativeFramesAcrossRepeatedRootAndSheetNavigation', 0, async () => {
            if (profile) {
                hidebug.startJsCpuProfiling('elvacos-device-navigation');
            }
            try {
                for (let round = 0; round < 3; round++) {
                    for (let index = 0; index < 5; index++) {
                        await root(index);
                        if (round === 0 && (index > 0 || layout.length > 0)) {
                            await report('first-root-' + index);
                        }
                    }
                    if (round > 0) {
                        await report('cached-root-round-' + round);
                    }
                    await resources('root-round-' + round);
                }
            } finally {
                if (profile) {
                    hidebug.stopJsCpuProfiling();
                }
            }
            await root(1);
            layout = [];
            input = [];
            for (let index = 0; index < 8; index++) {
                await (await driver.findWindow({ bundleName: bundle })).focus();
                await driver.triggerCombineKeys(KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_N);
                expect(!!await driver.waitForComponent(ON.id('sheet-close').inWindow(bundle), 3000)).assertTrue();
                await driver.delayMs(700);
                expect(await driver.waitForIdle(700, 5000)).assertTrue();
                await driver.pressBack();
                await driver.delayMs(700);
                expect(await driver.waitForIdle(700, 5000)).assertTrue();
                expect(!!await driver.findComponent(ON.id('sheet-close').inWindow(bundle))).assertFalse();
            }
            await report('open-close-form-8');
            await resources('form-open-close-8');
        });
        it('recordsNativeLongListScrollWithoutWritingBusinessData', 0, async () => {
            const state = getApplicationState();
            const previous = state.assets;
            const assets: Asset[] = [];
            for (let index = 0; index < 1000; index++) {
                const asset = new Asset();
                asset.id = 'performance-asset-' + index;
                asset.name = '长列表装备 ' + index;
                asset.location = '测试收纳 ' + (index % 20);
                assets.push(asset);
            }
            try {
                state.assets = assets;
                await root(3);
                expect(!!await driver.waitForComponent(ON.id('wardrobe-asset:performance-asset-0').inWindow(bundle), 5000)).assertTrue();
                const bounds = await (await driver.findWindow({ bundleName: bundle })).getBounds();
                layout = [];
                input = [];
                for (let index = 0; index < 8; index++) {
                    await driver.swipe(Math.round(bounds.right * 0.4), Math.round(bounds.bottom * 0.74),
                        Math.round(bounds.right * 0.4), Math.round(bounds.bottom * 0.34), 1000);
                    await driver.delayMs(250);
                }
                await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-performance-1000-assets.png');
                await report('scroll-1000-assets-8');
                await resources('scroll-1000-assets');
            } finally {
                state.assets = previous;
                await root(0);
            }
        });
        it('recordsNativePhotoSelectionWithoutChangingPhotoStatuses', 0, async () => {
            const state = getApplicationState();
            const plan = state.albumSummary.plans.find((item): boolean => item.total >= 2);
            if (!plan) {
                throw new Error('Photo selection profiling requires a real fixture photo group');
            }
            const before = JSON.stringify(state.photos.map((photo): string => photo.id + ':' + photo.status));
            await root(4);
            const list = await driver.waitForComponent(ON.id('album-plan-list').inWindow(bundle), 5000);
            await list.scrollSearch(ON.id('album-plan:' + plan.id).inWindow(bundle), true, 350);
            await (await driver.findComponent(ON.id('album-plan:' + plan.id).inWindow(bundle))).click();
            expect(!!await driver.waitForComponent(ON.description('照片已加载').inWindow(bundle), 5000)).assertTrue();
            await driver.delayMs(700);
            layout = [];
            input = [];
            for (let index = 0; index < 4; index++) {
                await (await driver.waitForComponent(ON.id('root-action-批量选片').inWindow(bundle), 3000)).click();
                await driver.delayMs(350);
                await (await driver.waitForComponent(ON.id('root-action-全选当前筛选').inWindow(bundle), 3000)).click();
                await (await driver.findComponent(ON.id('photo-list').inWindow(bundle))).scrollToTop(600);
                await driver.delayMs(300);
                expect(!!await driver.waitForComponent(ON.text('已选 ' + plan.total + ' 张').inWindow(bundle), 3000)).assertTrue();
                if (index === 3) {
                    await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-performance-photo-selection.png');
                }
                await (await driver.waitForComponent(ON.id('root-action-取消选择').inWindow(bundle), 3000)).click();
                await driver.delayMs(350);
            }
            expect(JSON.stringify(state.photos.map((photo): string => photo.id + ':' + photo.status))).assertEqual(before);
            await report('select-all-cancel-' + plan.total + '-photos-4');
            await resources('photo-selection-4');
            await root(0);
        });
    });
}
