import { abilityDelegatorRegistry, Driver, ON, Rect, ResizeDirection, WindowMode } from '@kit.TestKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';

// 在每个真实设备类型上分别执行；2in1 还必须实际跨越窗口断点，不能以手机画布代替。
export default function responsiveInputTest(): void {
    describe('ResponsiveInput', () => {
        const bundle = 'top.rayawa.elvacos';
        const parameters = abilityDelegatorRegistry.getArguments().parameters;
        const expectedDevice = parameters['expectedDeviceType'] as string;
        let driver: Driver;
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
            if (!(await driver.waitForComponent(ON.id('main-tabs').inWindow(bundle), 10000))) {
                throw new Error('Application main tabs did not become visible');
            }
            await (await driver.findWindow({ bundleName: bundle })).focus();
        });
        afterAll(async () => {
            if (driver && await driver.findWindow({ bundleName: bundle })) {
                await combination(KeyCode.KEYCODE_1);
            }
        });
        it('runsOnTheRequestedDeviceFamily', 0, async () => {
            expect(deviceInfo.deviceType).assertEqual(expectedDevice);
            const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
            inside(await (await driver.findComponent(ON.id('main-tabs').inWindow(bundle))).getBounds(), window);
            console.info('RESPONSIVE_DEVICE ' + expectedDevice + ' API ' + deviceInfo.sdkApiVersion + ' ' + JSON.stringify(window));
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
                await driver.screenCap('/data/storage/el2/base/cache/elvacos-' + expectedDevice + '-root-' + index + '.png');
            }
            for (let index = labels.length - 1; index >= 0; index--) {
                await combination(KeyCode.KEYCODE_1 + index);
                expect(!!(await driver.waitForComponent(ON.id('root-action-' + actions[index]).inWindow(bundle), 5000))).assertTrue();
            }
        });
        it('searchInputSettingsAndEscapeKeepNativeKeyboardBehavior', 0, async () => {
            await combination(KeyCode.KEYCODE_F);
            const input = await driver.waitForComponent(ON.id('global-search-input').inWindow(bundle), 5000);
            if (!input) {
                throw new Error('Ctrl+F did not open global search');
            }
            await input.inputText('layout');
            await driver.triggerKey(KeyCode.KEYCODE_N);
            expect((await input.getText()).includes('n')).assertTrue();
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
                try {
                    await combination(KeyCode.KEYCODE_4);
                    for (const width of [599, 600, 839, 840, 600, 599]) {
                        await appWindow.resize(Math.round(width * density), original.bottom - original.top, ResizeDirection.RIGHT);
                        await driver.delayMs(700);
                        const bounds = await appWindow.getBounds();
                        expect(Math.abs((bounds.right - bounds.left) / density - width) <= 2).assertTrue();
                        const cards = await driver.findComponents(ON.description('双击打开装备详情').inWindow(bundle));
                        if (cards.length < 2) {
                            throw new Error('Responsive layout requires at least two visible fixture assets');
                        }
                        const first = await cards[0].getBounds();
                        const second = await cards[1].getBounds();
                        inside(first, bounds);
                        inside(second, bounds);
                        if (width < 600) {
                            expect(first.left).assertEqual(second.left);
                            expect(first.bottom <= second.top).assertTrue();
                        } else {
                            expect(Math.abs(first.top - second.top) <= 2).assertTrue();
                            expect(first.right <= second.left).assertTrue();
                        }
                        await driver.screenCap('/data/storage/el2/base/cache/elvacos-' + expectedDevice + '-width-' + width + '.png');
                    }
                } finally {
                    await appWindow.resize(original.right - original.left, original.bottom - original.top, ResizeDirection.RIGHT);
                    if (originalMode === WindowMode.FULLSCREEN) {
                        await appWindow.maximize();
                    }
                }
            });
        }
    });
}
