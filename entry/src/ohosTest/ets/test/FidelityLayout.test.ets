import { captureScreenshot } from '../testability/UiEvidence';
import { getApplicationState } from '../../../main/ets/state/appState';
import { Driver, ON, Rect } from '@kit.TestKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
class LayoutView {
    public tab: string;
    public index: number;
    public section: string;

    constructor(tab: string, index: number, section: string) {
        this.tab = tab;
        this.index = index;
        this.section = section;
    }
}
// Read-only checks: use the application's existing records, never change preferences or entities.

export default function fidelityLayoutTest(): void {

    describe('DashboardLayoutFidelity', () => {
        const bundle = 'top.rayawa.elvacos';
        let driver: Driver;
        const tap = async (label: string): Promise<void> => {
            await (await driver.findWindow({ bundleName: bundle })).focus();
            let matches = await driver.findComponents(ON.text(label).inWindow(bundle));
            if (!matches || matches.length === 0) {
                matches = await driver.findComponents(ON.id('root-action-' + label).inWindow(bundle));
            }
            if (!matches || matches.length === 0) {
                matches = await driver.findComponents(ON.id('detail-action-' + label).inWindow(bundle));
            }
            if (!matches || matches.length === 0) {
                matches = await driver.findComponents(ON.id(label).inWindow(bundle));
            }
            if (!matches || matches.length === 0) {
                throw new Error('Missing visible label: ' + label);
            }
            await matches[matches.length - 1].click();
            await driver.delayMs(400);
        };
        const back = async (): Promise<void> => {
            await (await driver.findWindow({ bundleName: bundle })).focus();
            await driver.pressBack();
            await driver.delayMs(500);
        };
        const sameRect = (before: Rect, after: Rect): void => {
            expect(after.left).assertEqual(before.left);
            expect(after.top).assertEqual(before.top);
            expect(after.right).assertEqual(before.right);
            expect(after.bottom).assertEqual(before.bottom);
        };
        const tabs = async (): Promise<Rect> => {
            const matches = await driver.findComponents(ON.type('Column').text('首页').inWindow(bundle));
            return matches[matches.length - 1].getBounds();
        };
        const scrollBody = async (horizontalRatio: number = 0.2): Promise<void> => {
            const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
            // The left content column avoids settings sliders and the fixed bottom bar.
            const x = Math.round(window.left + (window.right - window.left) * horizontalRatio);
            const height = window.bottom - window.top;
            await driver.swipe(x, Math.round(window.top + height * 0.7), x, Math.round(window.top + height * 0.3), 800);
            await driver.delayMs(500);
        };
        beforeAll(async () => {
            driver = Driver.create();
            if (!(await driver.waitForComponent(ON.id('main-tabs').inWindow(bundle), 5000))) {
                throw new Error('Application main tabs did not become visible');
            }
            await (await driver.findWindow({ bundleName: bundle })).focus();
            await tap('首页');
        });
        afterAll(async () => {
            if (await driver.findWindow({ bundleName: bundle })) {
                await tap('首页');
            }
        });
        it('titleSegmentAndTabsStayFixedAcrossAllSecondaryViews', 0, async () => {
            const baselineTabs = await tabs();
            const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
            expect(baselineTabs.bottom < window.bottom).assertTrue();
            const views: LayoutView[] = [
                new LayoutView('计划', 1, '进行中'), new LayoutView('计划', 1, '已完成'), new LayoutView('计划', 1, '全部'),
                new LayoutView('日程', 2, '列表'), new LayoutView('日程', 2, '日历'),
                new LayoutView('相册', 4, '按场次'), new LayoutView('相册', 4, '待处理'),
            ];
            let baselineSegment: Rect | undefined;
            for (const view of views) {
                await tap(view.tab);
                await tap(view.section);
                const segment = await driver.findComponent(ON.id('secondary-segment-' + view.index).inWindow(bundle));
                const segmentBefore = await segment.getBounds();
                const titles = await driver.findComponents(ON.text(view.tab).inWindow(bundle));
                const titleBefore = await titles[0].getBounds();
                expect(titleBefore.top > window.top).assertTrue();
                expect(segmentBefore.top < titleBefore.bottom && segmentBefore.bottom > titleBefore.top).assertTrue();
                // Dashboard uses 50% for every title segment; wide windows must not cap it.
                expect(Math.abs((segmentBefore.right - segmentBefore.left) - (window.right - window.left) * 0.5) <= 2).assertTrue();
                const segmentCenter = (segmentBefore.left + segmentBefore.right) / 2;
                const windowCenter = (window.left + window.right) / 2;
                expect(Math.abs(segmentCenter - windowCenter) <= 2).assertTrue();
                expect(titleBefore.right <= segmentBefore.left).assertTrue();
                if (baselineSegment) {
                    expect(segmentBefore.top).assertEqual(baselineSegment.top);
                    expect(segmentBefore.bottom).assertEqual(baselineSegment.bottom);
                } else {
                    baselineSegment = segmentBefore;
                }
                sameRect(baselineTabs, await tabs());
                await scrollBody();
                sameRect(segmentBefore, await segment.getBounds());
                sameRect(titleBefore, await titles[0].getBounds());
                sameRect(baselineTabs, await tabs());
            }
            await tap('衣柜');
            expect(((await driver.findComponents(ON.id('secondary-segment-3').inWindow(bundle)))?.length || 0)).assertEqual(0);
            const gear = await driver.findComponent(ON.id('root-action-添加装备').inWindow(bundle));
            const gearBefore = await gear.getBounds();
            await scrollBody();
            sameRect(gearBefore, await gear.getBounds());
            sameRect(baselineTabs, await tabs());
        });
        it('albumLastPhotoClearsFloatingTabsAndRepeatedTabReturnsToTop', 0, async () => {
            await tap('相册');
            await tap('按场次');
            await tap('相册');
            const source = getApplicationState().photos[0];
            if (!source) {
                expect((await driver.findComponents(ON.id('root-action-导入照片').inWindow(bundle))).length > 0).assertTrue();
                return;
            }
            const groups = await driver.findComponent(ON.id('album-plan-list').inWindow(bundle));
            await groups.scrollSearch(ON.id('album-plan:' + source.projectId).inWindow(bundle));
            await tap('album-plan:' + source.projectId);
            await driver.delayMs(500);
            const before = await tabs();
            let photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
            if (!photos || photos.length === 0) {
                expect((await driver.findComponents(ON.text('这个范围还没有照片').inWindow(bundle))).length > 0).assertTrue();
                return;
            }
            const first = await photos[0].getBounds();
            // Existing photo records are the fixture. Enough swipes for the current library,
            // with a limit that keeps the read-only check bounded for larger collections.
            let previousBottom = 0;
            for (let attempt = 0; attempt < 20; attempt++) {
                await scrollBody();
                photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
                const bottom = (await photos[photos.length - 1].getBounds()).bottom;
                if (bottom === previousBottom) {
                    break;
                }
                previousBottom = bottom;
            }
            const last = await photos[photos.length - 1].getBounds();
            expect(last.bottom <= before.top).assertTrue();
            sameRect(before, await tabs());
            await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-fidelity-library-bottom.png');
            await tap('相册');
            await driver.delayMs(500);
            photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
            sameRect(first, await photos[0].getBounds());
            await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-fidelity-library-top.png');
        });
        it('repeatedValidationKeepsItsInlineErrorAndFieldPosition', 0, async () => {
            await tap('计划');
            await tap('plan-role-library');
            await tap('添加角色');
            await tap('保存');
            const field = await driver.waitForComponent(ON.id('form-input:name').inWindow(bundle), 3000);
            expect(!!field).assertTrue();
            const error = await driver.findComponent(ON.text('名称需要 1–80 个字').inWindow(bundle));
            expect(!!error).assertTrue();
            const before = await field.getBounds();
            await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-fidelity-inline-error-first.png');
            // The error persists after a toast would have expired, and repeat validation preserves the focused field.
            await driver.delayMs(2300);
            expect(!!(await driver.findComponent(ON.text('名称需要 1–80 个字').inWindow(bundle)))).assertTrue();
            await tap('保存');
            sameRect(before, await field.getBounds());
            expect(!!(await driver.findComponent(ON.text('名称需要 1–80 个字').inWindow(bundle)))).assertTrue();
            await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-fidelity-inline-error-repeat.png');
            await tap('sheet-close');
            expect((await driver.findComponents(ON.text('添加角色').inWindow(bundle))).length > 0).assertTrue();
            await back();
        });
        it('nativePlanViewTabsAndTitleActionsStayFixedAndReturnToTheSelectedView', 0, async () => {
            await tap('计划');
            await tap('进行中');
            const plans = await driver.findComponents(ON.description('双击打开计划详情').inWindow(bundle));
            if (!plans || plans.length === 0) {
                return;
            }
            await plans[0].click();
            await driver.delayMs(800);
            const segment = await driver.findComponent(ON.id('project-view-tabs-0').inWindow(bundle));
            const baseline = await segment.getBounds();
            const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
            expect(baseline.bottom < window.bottom && baseline.top > window.top + (window.bottom - window.top) * 0.5).assertTrue();
            let actionTop: number = 0;
            let actionBottom: number = 0;
            const sections = ['准备', '打包', '照片'];
            const actions = ['添加准备任务', '添加物品', '导入照片'];
            for (let index = 0; index < sections.length; index++) {
                await tap(sections[index]);
                await driver.delayMs(400);
                sameRect(baseline, await segment.getBounds());
                expect(((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
                const action = await driver.findComponent(ON.id('detail-action-' + actions[index]).inWindow(bundle));
                const bar = await action.getBounds();
                expect(bar.bottom < baseline.top && bar.top > window.top).assertTrue();
                if (index === 0) {
                    actionTop = bar.top;
                    actionBottom = bar.bottom;
                } else {
                    expect(bar.top).assertEqual(actionTop);
                    expect(bar.bottom).assertEqual(actionBottom);
                }
                await scrollBody(0.5);
                sameRect(baseline, await segment.getBounds());
                sameRect(bar, await action.getBounds());
                await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-fidelity-plan-' + index + '.png');
            }
            const photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
            let opened: boolean = false;
            for (const photo of photos || []) {
                const bounds = await photo.getBounds();
                const center = (bounds.top + bounds.bottom) / 2;
                if (center <= window.top + 120 || center >= baseline.top - 8) {
                    continue;
                }
                await (await driver.findWindow({ bundleName: bundle })).focus();
                await photo.click();
                await driver.delayMs(500);
                if (!(await driver.waitForComponent(ON.text('照片工作流').inWindow(bundle), 3000))) {
                    throw new Error('Visible photo did not open its detail');
                }
                expect(((await driver.findComponents(ON.id('project-view-tabs-0').inWindow(bundle)))?.length || 0)).assertEqual(0);
                await back();
                sameRect(baseline, await (await driver.findComponent(ON.id('project-view-tabs-0').inWindow(bundle))).getBounds());
                // The photo list preserves its scroll position when returning.
                const segmentAfter = await driver.findComponent(ON.id('project-view-tabs-0').inWindow(bundle));
                sameRect(baseline, await segmentAfter.getBounds());
                const returnedPhotos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
                let restoredPosition: boolean = false;
                for (const returnedPhoto of returnedPhotos || []) {
                    const returnedBounds = await returnedPhoto.getBounds();
                    if (returnedBounds.left === bounds.left && returnedBounds.top === bounds.top &&
                        returnedBounds.right === bounds.right && returnedBounds.bottom === bounds.bottom) {
                            restoredPosition = true;
                        }
                }
                expect(restoredPosition).assertTrue();
                await captureScreenshot(driver, '/data/storage/el2/base/cache/elvacos-fidelity-plan-photo-return.png');
                opened = true;
                break;
            }
            if (photos && photos.length > 0) {
                expect(opened).assertTrue();
            }
            await back();
            expect((await driver.findComponents(ON.id('main-tabs').inWindow(bundle))).length).assertEqual(1);
        });
    });
}
