import { captureScreenshot } from '../testability/UiEvidence';
import { abilityDelegatorRegistry, Driver, ON, Rect, WindowMode } from '@kit.TestKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { describe, beforeAll, beforeEach, afterAll, afterEach, it, expect } from '@ohos/hypium';
import { getApplicationState } from '../../../main/ets/state/appState';

// 在每个真实设备类型上分别执行；2in1 还必须实际跨越窗口断点，不能以手机画布代替。
export default function responsiveInputTest(): void {
    describe('ResponsiveInput', () => {
        const bundle = 'top.rayawa.elvacos';
        const parameters = abilityDelegatorRegistry.getArguments().parameters;
        const expectedDevice = parameters['-s expectedDeviceType'] as string;
        let driver: Driver;
        let caseNumber = 0;
        const inside = (rect: Rect, window: Rect): void => {
            expect(rect.right > rect.left && rect.bottom > rect.top).assertTrue();
            expect(rect.left >= window.left && rect.right <= window.right).assertTrue();
            expect(rect.top >= window.top && rect.bottom <= window.bottom).assertTrue();
        };
        const clickId = async (id: string): Promise<void> => {
            const component = await driver.waitForComponent(ON.id(id).inWindow(bundle), 5000);
            if (!component) {
                throw new Error('Missing visible control: ' + id);
            }
            inside(await component.getBounds(), await (await driver.findWindow({ bundleName: bundle })).getBounds());
            await component.click();
            await driver.delayMs(500);
        };
        const combination = async (key: KeyCode): Promise<void> => {
            await (await driver.findWindow({ bundleName: bundle })).focus();
            await driver.triggerCombineKeys(KeyCode.KEYCODE_CTRL_LEFT, key);
            await driver.delayMs(500);
        };
        const escape = async (): Promise<void> => {
            await driver.triggerKey(KeyCode.KEYCODE_ESCAPE);
            await driver.delayMs(500);
        };
        beforeAll(async () => {
            if (!['phone', 'tablet', '2in1'].includes(expectedDevice)) {
                throw new Error('Set expectedDeviceType explicitly to phone, tablet or 2in1');
            }
            driver = Driver.create();
            for (let attempt = 0; attempt < 150 && (!getApplicationState().ready || getApplicationState().busy); attempt++) {
                await driver.delayMs(200);
            }
            if (!getApplicationState().ready || getApplicationState().busy) {
                throw new Error('Application data did not finish loading before input acceptance');
            }
            if (!(await driver.waitForComponent(ON.id('main-tabs').inWindow(bundle), 30000))) {
                throw new Error('Application main tabs did not become visible');
            }
            await (await driver.findWindow({ bundleName: bundle })).focus();
        });
        afterAll(async () => {
            if (driver && await driver.findWindow({ bundleName: bundle })) {
                await combination(KeyCode.KEYCODE_1);
            }
        });
        beforeEach(async () => {
            await (await driver.findWindow({ bundleName: bundle })).focus();
            for (let attempt = 0; attempt < 10; attempt++) {
                let root = false;
                for (const action of ['设置', '新建计划', '添加活动', '添加装备', '导入照片']) {
                    root = root || !!await driver.findComponent(ON.id('root-action-' + action).inWindow(bundle));
                }
                if (root && !await driver.findComponent(ON.id('sheet-close').inWindow(bundle))) {
                    return;
                }
                const discard = await driver.findComponent(ON.text('放弃修改').inWindow(bundle));
                if (discard) {
                    await discard.click();
                } else {
                    await driver.triggerKey(KeyCode.KEYCODE_ESCAPE);
                }
                await driver.delayMs(700);
            }
            throw new Error('Cannot restore the root before input acceptance');
        });
        afterEach(async () => {
            caseNumber++;
            if (deviceInfo.sdkApiVersion >= 26) {
                await driver.dumpLayout('/data/storage/el2/base/cache/elvacos-responsive-' + caseNumber + '.json');
            }
            await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-responsive-' + caseNumber + '.png');
        });
        it('runsOnTheRequestedDeviceFamily', 0, async () => {
            expect(deviceInfo.deviceType).assertEqual(expectedDevice);
            const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
            inside(await (await driver.findComponent(ON.id('main-tabs').inWindow(bundle))).getBounds(), window);
            const panel = display.getDefaultDisplaySync();
            await abilityDelegatorRegistry.getAbilityDelegator().print('RESPONSIVE_DEVICE ' + JSON.stringify({
                model: deviceInfo.productModel, device: deviceInfo.deviceType, api: deviceInfo.sdkApiVersion,
                widthPx: panel.width, heightPx: panel.height, density: panel.densityPixels, window: window
            }) + '\n');
        });
        it('clickAndKeyboardNavigationReachAllFiveRoots', 0, async () => {
            const labels: string[] = ['首页', '计划', '日程', '衣柜', '相册'];
            const actions: string[] = ['设置', '新建计划', '添加活动', '添加装备', '导入照片'];
            for (let index = 0; index < labels.length; index++) {
                const tabs = await driver.findComponents(ON.type('Column').text(labels[index]).inWindow(bundle));
                if (!tabs.length) {
                    throw new Error('Missing root tab: ' + labels[index]);
                }
                await tabs[tabs.length - 1].click();
                await driver.delayMs(500);
                expect(!!(await driver.waitForComponent(ON.id('root-action-' + actions[index]).inWindow(bundle), 5000))).assertTrue();
                await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-' + expectedDevice + '-root-' + index + '.png');
            }
            for (let index = labels.length - 1; index >= 0; index--) {
                await combination(KeyCode.KEYCODE_1 + index);
                expect(!!(await driver.waitForComponent(ON.id('root-action-' + actions[index]).inWindow(bundle), 5000))).assertTrue();
            }
        });
        it('searchInputSettingsAndEscapeKeepNativeKeyboardBehavior', 0, async () => {
            await combination(KeyCode.KEYCODE_F);
            const input = await driver.waitForComponent(ON.type('SearchField').within(ON.id('global-search-input')).inWindow(bundle), 5000);
            if (!input) {
                throw new Error('Ctrl+F did not open global search');
            }
            await input.click();
            await driver.delayMs(300);
            await input.inputText('layout', { paste: true });
            expect(await input.getText()).assertEqual('layout');
            await driver.triggerKey(KeyCode.KEYCODE_N);
            // Desktop IMEs can retain Latin keys as composition until Enter.
            await driver.triggerKey(KeyCode.KEYCODE_ENTER);
            await driver.delayMs(300);
            expect((await input.getText()).toLowerCase().includes('n')).assertTrue();
            await combination(KeyCode.KEYCODE_F);
            await driver.triggerKey(KeyCode.KEYCODE_TAB);
            expect((await driver.findComponents(ON.focused(true).inWindow(bundle))).length > 0).assertTrue();
            await escape();
            expect(!!(await driver.waitForComponent(ON.id('root-action-设置').inWindow(bundle), 5000))).assertTrue();
            await combination(KeyCode.KEYCODE_COMMA);
            expect(!!(await driver.waitForComponent(ON.text('偏好与交互').inWindow(bundle), 5000))).assertTrue();
            await escape();
            await clickId('root-action-设置');
            expect(!!(await driver.waitForComponent(ON.text('偏好与交互').inWindow(bundle), 5000))).assertTrue();
            await escape();
        });
        it('nativeButtonsAndUnsavedFormsRespectKeyboardActivation', 0, async () => {
            await combination(KeyCode.KEYCODE_1);
            const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
            const appWindow = await window.getLastWindow(ability.context);
            for (const key of [KeyCode.KEYCODE_ENTER, KeyCode.KEYCODE_SPACE]) {
                await driver.triggerKey(KeyCode.KEYCODE_TAB);
                appWindow.getUIContext().getFocusController().requestFocus('root-action-设置');
                expect(!!await driver.waitForComponent(ON.id('root-action-设置').focused(true).inWindow(bundle), 2000)).assertTrue();
                await driver.triggerKey(key);
                expect(!!await driver.waitForComponent(ON.text('偏好与交互').inWindow(bundle), 5000)).assertTrue();
                await escape();
                expect(await driver.waitForIdle(700, 5000)).assertTrue();
            }
            await combination(KeyCode.KEYCODE_2);
            await combination(KeyCode.KEYCODE_N);
            const name = await driver.waitForComponent(ON.id('form-input:name').inWindow(bundle), 5000);
            expect(!!name).assertTrue();
            expect(await driver.waitForIdle(700, 5000)).assertTrue();
            const recovery = await driver.findComponent(ON.id('form-discard-draft').inWindow(bundle));
            if (recovery) {
                await recovery.click();
                await driver.delayMs(300);
            }
            const editable = await driver.findComponent(ON.id('form-input:name').inWindow(bundle));
            expect(await editable.isEnabled()).assertTrue();
            await editable.click();
            await driver.delayMs(700);
            await (await driver.findComponent(ON.id('form-input:name').inWindow(bundle))).inputText('未保存快捷键验证');
            await driver.delayMs(500);
            expect(await (await driver.findComponent(ON.id('form-input:name').inWindow(bundle))).getText()).assertEqual('未保存快捷键验证');
            await escape();
            const keep = await driver.waitForComponent(ON.text('继续编辑').inWindow(bundle), 5000);
            if (!keep) {
                if (deviceInfo.sdkApiVersion >= 26) {
                    await driver.dumpLayout('/data/storage/el2/base/cache/elvacos-unsaved-escape.json');
                }
                await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-unsaved-escape.png');
            }
            expect(!!keep).assertTrue();
            await keep.click();
            expect(await (await driver.findComponent(ON.id('form-input:name').inWindow(bundle))).getText()).assertEqual('未保存快捷键验证');
            await escape();
            await (await driver.waitForComponent(ON.text('放弃修改').inWindow(bundle), 5000)).click();
            await driver.delayMs(700);
            expect(await driver.waitForIdle(700, 5000)).assertTrue();
            expect(!!await driver.findComponent(ON.id('sheet-close').inWindow(bundle))).assertFalse();
            for (let index = 0; index < 3; index++) {
                await combination(KeyCode.KEYCODE_N);
                expect(!!await driver.waitForComponent(ON.id('form-input:name').inWindow(bundle), 3000)).assertTrue();
                await driver.pressBack();
                await driver.delayMs(80);
                // Reopen during the old native sheet's dismissal, before onDisappear.
                await driver.triggerCombineKeys(KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_N);
                await driver.delayMs(700);
                const reopened = await driver.waitForComponent(ON.id('form-input:name').inWindow(bundle), 3000);
                await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-sheet-reopen-' + index + '.png');
                expect(!!reopened).assertTrue();
                expect(await reopened.isEnabled()).assertTrue();
                expect(!!await driver.findComponent(ON.text('新建计划').inWindow(bundle))).assertTrue();
                await driver.pressBack();
                await driver.delayMs(700);
            }
            await combination(KeyCode.KEYCODE_1);
        });
        if (expectedDevice === '2in1') {
            it('resizingCrossesDashboardBreakpointsAndReturnsToSingleColumn', 0, async () => {
                if (deviceInfo.deviceType !== '2in1') {
                    throw new Error('Window resizing must run on the requested 2in1 device');
                }
                const appWindow = await driver.findWindow({ bundleName: bundle });
                const original = await appWindow.getBounds();
                const originalMode = await appWindow.getWindowMode();
                if (originalMode !== WindowMode.FLOATING) {
                    await appWindow.resume();
                }
                expect(await appWindow.getWindowMode()).assertEqual(WindowMode.FLOATING);
                const density = display.getDisplayByIdSync(await appWindow.getDisplayId()).densityPixels;
                const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
                const nativeWindow = await window.getLastWindow(ability.context);
                try {
                    await combination(KeyCode.KEYCODE_4);
                    for (const width of [599, 600, 839, 840, 600, 599]) {
                        // UiWindow.resize drags the border; a 1vp step can stay below
                        // its pointer threshold. Native resize gives an exact pixel size.
                        await nativeWindow.resize(Math.ceil(width * density), original.bottom - original.top);
                        await driver.delayMs(700);
                        const bounds = await appWindow.getBounds();
                        const actualWidth = (bounds.right - bounds.left) / density;
                        expect(actualWidth >= width - 0.01 && actualWidth < width + 1).assertTrue();
                        const cards = await driver.findComponents(ON.description('双击打开装备详情').inWindow(bundle));
                        if (cards.length < 2) {
                            throw new Error('Responsive layout requires at least two visible fixture assets');
                        }
                        const first = await cards[0].getBounds();
                        const second = await cards[1].getBounds();
                        await abilityDelegatorRegistry.getAbilityDelegator().print('WINDOW_LAYOUT ' + JSON.stringify({
                            requestedVp: width, density: density, window: bounds,
                            list: await (await driver.findComponent(ON.id('library-scroll').inWindow(bundle))).getBounds(), first: first, second: second
                        }) + '\n');
                        await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-' + expectedDevice + '-width-' + width + '.png');
                        inside(first, bounds);
                        inside(second, bounds);
                        if (width < 600) {
                            expect(first.left).assertEqual(second.left);
                            expect(first.bottom <= second.top).assertTrue();
                        } else {
                            expect(Math.abs(first.top - second.top) <= 2).assertTrue();
                            expect(first.right <= second.left).assertTrue();
                        }
                    }
                    // Card lanes change at 600vp. Photos also change at 840vp,
                    // so verify that boundary with the real lazy photo rows.
                    await nativeWindow.resize(original.right - original.left, original.bottom - original.top);
                    await driver.delayMs(700);
                    await combination(KeyCode.KEYCODE_5);
                    await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-photo-breakpoint-entry.png');
                    expect(!!await driver.waitForComponent(ON.id('root-action-导入照片').inWindow(bundle), 5000)).assertTrue();
                    const plan = getApplicationState().albumSummary.plans.find((item): boolean => item.total >= 4);
                    if (!plan) {
                        throw new Error('Photo breakpoints require a fixture group with at least four photos');
                    }
                    const groups = await driver.waitForComponent(ON.id('album-plan-list').inWindow(bundle), 5000);
                    if (!groups) {
                        throw new Error('Photo breakpoint acceptance must start from the album groups');
                    }
                    await groups.scrollToTop(600);
                    const viewport = await groups.getBounds();
                    const x = Math.round(viewport.left + (viewport.right - viewport.left) * 0.2);
                    const upper = Math.round(viewport.top + 200 * density);
                    const lower = Math.round(viewport.bottom - 130 * density);
                    let group = await driver.findComponent(ON.id('album-plan:' + plan.id).inWindow(bundle));
                    for (let attempt = 0; attempt < 20; attempt++) {
                        let reverse = false;
                        let distance = lower - upper;
                        if (group) {
                            const bounds = await group.getBounds();
                            const center = (bounds.top + bounds.bottom) / 2;
                            if (center > upper && center < lower) {
                                break;
                            }
                            reverse = center <= upper;
                            distance = Math.round(Math.min(lower - upper - 32, Math.max(96, Math.abs(center - (upper + lower) / 2))));
                        }
                        await driver.swipe(x, reverse ? upper : lower, x, reverse ? upper + distance : lower - distance, 1000);
                        await driver.delayMs(150);
                        group = await driver.findComponent(ON.id('album-plan:' + plan.id).inWindow(bundle));
                    }
                    await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-photo-breakpoint-group-search.png');
                    if (!group) {
                        throw new Error('Fixture photo group could not be scrolled into view');
                    }
                    await group.click();
                    await driver.delayMs(700);
                    for (const width of [599, 600, 839, 840, 600, 599]) {
                        await nativeWindow.resize(Math.ceil(width * density), original.bottom - original.top);
                        await driver.delayMs(700);
                        const dayEntry = await driver.findComponent(ON.id('day-entry-bar').inWindow(bundle));
                        if (dayEntry) {
                            const entryBounds = await dayEntry.getBounds();
                            const scope = await driver.findComponent(ON.id('album-portfolio-toggle').inWindow(bundle));
                            expect((await scope.getBounds()).top >= entryBounds.bottom).assertTrue();
                        }
                        const photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
                        if (!photos.length) {
                            throw new Error('No rendered photos at the requested window width');
                        }
                        const rectangles: Rect[] = [];
                        for (const photo of photos) {
                            rectangles.push(await photo.getBounds());
                        }
                        const firstTop = Math.min(...rectangles.map((rect: Rect): number => rect.top));
                        const row = rectangles.filter((rect: Rect): boolean => Math.abs(rect.top - firstTop) <= 2);
                        await abilityDelegatorRegistry.getAbilityDelegator().print('PHOTO_WINDOW_LAYOUT ' + JSON.stringify({
                            requestedVp: width, window: await appWindow.getBounds(), row: row
                        }) + '\n');
                        await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-' + expectedDevice + '-photos-width-' + width + '.png');
                        expect(row.length).assertEqual(width >= 840 ? 4 : width >= 600 ? 3 : 2);
                        for (let index = 1; index < row.length; index++) {
                            expect(row[index - 1].right <= row[index].left).assertTrue();
                        }
                    }
                } finally {
                    await nativeWindow.resize(original.right - original.left, original.bottom - original.top);
                    if (originalMode === WindowMode.FULLSCREEN) {
                        await appWindow.maximize();
                    }
                }
            });
        }
    });
}
