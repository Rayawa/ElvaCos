import { Driver, ON, Rect } from '@kit.TestKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';

class LayoutView {
  public tab: string;
  public index: number;
  public section: string;
  constructor(tab: string, index: number, section: string) { this.tab = tab; this.index = index; this.section = section; }
}

// Read-only checks: use the application's existing records, never change preferences or entities.
export default function fidelityLayoutTest(): void {
  describe('DashboardLayoutFidelity', () => {
    const bundle = 'top.rayawa.elvacos';
    let driver: Driver;
    const tap = async (label: string): Promise<void> => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      let matches = await driver.findComponents(ON.text(label).inWindow(bundle));
      if (!matches || matches.length === 0) { matches = await driver.findComponents(ON.id('root-action-' + label).inWindow(bundle)); }
      if (!matches || matches.length === 0) { throw new Error('Missing visible label: ' + label); }
      await matches[matches.length - 1].click();
      await driver.delayMs(400);
    };
    const back = async (): Promise<void> => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      await driver.pressBack(); await driver.delayMs(500);
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
    afterAll(async () => { if (await driver.findWindow({ bundleName: bundle })) { await tap('首页'); } });
    it('titleSegmentAndTabsStayFixedAcrossAllSecondaryViews', 0, async () => {
      const baselineTabs = await tabs();
      const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
      expect(baselineTabs.bottom < window.bottom).assertTrue();
      const views: LayoutView[] = [
        new LayoutView('Cos', 1, '角色'), new LayoutView('Cos', 1, '计划'),
        new LayoutView('漫展', 2, '即将'), new LayoutView('漫展', 2, '过去'), new LayoutView('漫展', 2, '想去'),
        new LayoutView('衣柜', 3, '装备'), new LayoutView('衣柜', 3, '照片'),
        new LayoutView('我的', 4, '作品'), new LayoutView('我的', 4, '时间轴'),
      ];
      let baselineSegment: Rect | undefined;
      for (const view of views) {
        await tap(view.tab); await tap(view.section);
        const segment = await driver.findComponent(ON.id('secondary-segment-' + view.index).inWindow(bundle));
        const segmentBefore = await segment.getBounds();
        const titles = await driver.findComponents(ON.text(view.tab).inWindow(bundle));
        const titleBefore = await titles[0].getBounds();
        expect(titleBefore.top > window.top).assertTrue();
        expect(segmentBefore.top < titleBefore.bottom && segmentBefore.bottom > titleBefore.top).assertTrue();
        if (baselineSegment) { sameRect(baselineSegment, segmentBefore); }
        else { baselineSegment = segmentBefore; }
        sameRect(baselineTabs, await tabs());
        await scrollBody();
        sameRect(segmentBefore, await segment.getBounds());
        sameRect(titleBefore, await titles[0].getBounds());
        sameRect(baselineTabs, await tabs());
      }
    });
    it('libraryLastPhotoClearsFloatingTabsAndRepeatedTabReturnsToTop', 0, async () => {
      await tap('衣柜'); await tap('照片'); await tap('衣柜');
      const before = await tabs();
      let photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
      if (!photos || photos.length === 0) {
        expect((await driver.findComponents(ON.text('每一张，都是一次登场').inWindow(bundle))).length > 0).assertTrue();
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
        if (bottom === previousBottom) { break; }
        previousBottom = bottom;
      }
      const last = await photos[photos.length - 1].getBounds();
      expect(last.bottom <= before.top).assertTrue();
      sameRect(before, await tabs());
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-fidelity-library-bottom.png');
      await tap('衣柜'); await driver.delayMs(500);
      photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
      sameRect(first, await photos[0].getBounds());
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-fidelity-library-top.png');
    });
    it('repeatedValidationUsesToastWithoutMovingTheForm', 0, async () => {
      await tap('Cos'); await tap('角色'); await tap('添加角色');
      const field = await driver.waitForComponent(ON.text('名称 *').inWindow(bundle), 3000);
      const before = await field.getBounds();
      await tap('保存');
      sameRect(before, await field.getBounds());
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-fidelity-toast-first.png');
      // Let the first 2-second toast expire so the second screenshot proves a new prompt.
      await driver.delayMs(2300); await tap('保存');
      sameRect(before, await field.getBounds());
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-fidelity-toast-repeat.png');
      await tap('取消');
      expect((await driver.findComponents(ON.id('root-action-添加角色').inWindow(bundle))).length > 0).assertTrue();
    });
    it('planTaskSegmentsAndActionBarStayFixedAndReturnToTheSelectedView', 0, async () => {
      await tap('Cos'); await tap('计划');
      const plans = await driver.findComponents(ON.description('双击打开计划详情').inWindow(bundle));
      if (!plans || plans.length === 0) { return; }
      await plans[0].click(); await driver.delayMs(800);
      const segment = await driver.findComponent(ON.id('project-task-segment').inWindow(bundle));
      const baseline = await segment.getBounds();
      const window = await (await driver.findWindow({ bundleName: bundle })).getBounds();
      expect(Math.abs((baseline.right - baseline.left) - (window.right - window.left) * 0.5) <= 2).assertTrue();
      let actionTop: number = 0;
      let actionBottom: number = 0;
      const sections = ['准备', '打包', '照片'];
      const actions = ['添加装备', '添加物品', '导入照片'];
      for (let index = 0; index < sections.length; index++) {
        await tap(sections[index]); await driver.delayMs(400);
        sameRect(baseline, await segment.getBounds());
        const bars = await driver.findComponents(ON.type('Column').text(actions[index]).inWindow(bundle));
        const bar = await bars[bars.length - 1].getBounds();
        expect(bar.bottom < window.bottom).assertTrue();
        if (index === 0) { actionTop = bar.top; actionBottom = bar.bottom; }
        else { expect(bar.top).assertEqual(actionTop); expect(bar.bottom).assertEqual(actionBottom); }
        const titles = await driver.findComponents(ON.text('计划').inWindow(bundle));
        for (const title of titles || []) {
          const bounds = await title.getBounds();
          if (bounds.top < baseline.bottom && bounds.bottom > baseline.top) { expect(bounds.right <= baseline.left).assertTrue(); }
        }
        await scrollBody(0.5);
        sameRect(baseline, await segment.getBounds());
        expect((await bars[bars.length - 1].getBounds()).top).assertEqual(actionTop);
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-fidelity-plan-' + index + '.png');
      }
      const photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
      let opened: boolean = false;
      for (const photo of photos || []) {
        const bounds = await photo.getBounds();
        const center = (bounds.top + bounds.bottom) / 2;
        if (center <= baseline.bottom + 24 || center >= actionTop - 24) { continue; }
        await (await driver.findWindow({ bundleName: bundle })).focus();
        await photo.click(); await driver.delayMs(500);
        if (!(await driver.waitForComponent(ON.text('设为封面').inWindow(bundle), 3000))) { throw new Error('Visible photo did not open its detail'); }
        expect(((await driver.findComponents(ON.id('project-task-segment').inWindow(bundle)))?.length || 0)).assertEqual(0);
        await back();
        sameRect(baseline, await (await driver.findComponent(ON.id('project-task-segment').inWindow(bundle))).getBounds());
        // The photo list preserves its scroll position when returning.
        const segmentAfter = await driver.findComponent(ON.id('project-task-segment').inWindow(bundle));
        sameRect(baseline, await segmentAfter.getBounds());
        const returnedPhotos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
        let restoredPosition: boolean = false;
        for (const returnedPhoto of returnedPhotos || []) {
          const returnedBounds = await returnedPhoto.getBounds();
          if (returnedBounds.left === bounds.left && returnedBounds.top === bounds.top &&
            returnedBounds.right === bounds.right && returnedBounds.bottom === bounds.bottom) { restoredPosition = true; }
        }
        expect(restoredPosition).assertTrue();
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-fidelity-plan-photo-return.png');
        opened = true; break;
      }
      if (photos && photos.length > 0) { expect(opened).assertTrue(); }
      await back();
      expect((await driver.findComponents(ON.id('main-tabs').inWindow(bundle))).length).assertEqual(1);
    });
  });
}
