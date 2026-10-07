import { Component, Driver, On, ON, Point, Rect } from '@kit.TestKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { fileIo } from '@kit.CoreFileKit';

export default function settingsLayoutTest(): void {
  describe('SettingsReplicaLayout', () => {
    const bundle = 'top.rayawa.elvacos';
    let driver: Driver;
    const required = async (selector: On, name: string): Promise<Component> => {
      const component = await driver.waitForComponent(selector.inWindow(bundle), 3000);
      if (!component) {
        await driver.dumpLayout('/data/storage/el2/base/cache/elvacos-settings-missing.json');
        throw new Error('Missing settings layout component: ' + name);
      }
      return component;
    };
    const selectWidth = async (name: string): Promise<void> => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      await (await required(ON.id('layout-width-' + name), name + ' width button')).click();
      await driver.delayMs(1000);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-' + name + '-start.png');
    };
    const sameRect = (before: Rect, after: Rect): void => {
      expect(after.left).assertEqual(before.left); expect(after.top).assertEqual(before.top);
      expect(after.right).assertEqual(before.right); expect(after.bottom).assertEqual(before.bottom);
    };
    const itemBounds = async (label: string): Promise<Rect> => {
      const text = await (await required(ON.text(label), label)).getBounds();
      const items = await driver.findComponents(ON.type('HdsListItem').inWindow(bundle));
      for (const item of items || []) {
        const bounds = await item.getBounds();
        if (bounds.left <= text.left && bounds.right >= text.right && bounds.top <= text.top && bounds.bottom >= text.bottom) { return bounds; }
      }
      throw new Error('Missing native HDS item containing ' + label);
    };
    beforeAll(async () => {
      driver = Driver.create();
      if (!(await driver.waitForComponent(ON.id('layout-width-phone').inWindow(bundle), 5000))) { throw new Error('Settings layout host did not appear'); }
    });
    afterAll(async () => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      await driver.pressBack();
    });
    it('phoneAndNarrowUseOneScrollableColumnWithReachableLastRows', 0, async () => {
      for (const width of ['phone', 'narrow']) {
        await selectWidth(width);
        expect(((await driver.findComponents(ON.id('settings-wide-layout').inWindow(bundle)))?.length || 0)).assertEqual(0);
        const scroll = await required(ON.id('settings-scroll'), width + ' scroll');
        await scroll.scrollSearch(ON.text('材质等级').inWindow(bundle));
        const referenceBounds = await itemBounds('材质等级');
        await scroll.scrollSearch(ON.text('应用外观').inWindow(bundle));
        const preferenceBounds = await itemBounds('应用外观');
        const sky = await (await required(ON.text('天蓝'), 'light appearance')).getBounds();
        const system = await (await required(ON.text('跟随系统'), 'system appearance')).getBounds();
        const mist = await (await required(ON.text('雾蓝'), 'dark appearance')).getBounds();
        expect(sky.right <= system.left && system.right <= mist.left).assertTrue();
        const canvas = await (await required(ON.id('settings-layout-canvas'), 'canvas')).getBounds();
        const pixelsPerVp = (canvas.right - canvas.left) / (width === 'narrow' ? 320 : 378);
        const expectedHeight = width === 'narrow' ? 116 : 68;
        // HDS native bounds include its insets; also compare against the copied Dashboard material row.
        expect(Math.abs((preferenceBounds.bottom - preferenceBounds.top) / pixelsPerVp - expectedHeight) <= 8).assertTrue();
        expect(Math.abs((preferenceBounds.bottom - preferenceBounds.top) - (referenceBounds.bottom - referenceBounds.top)) <= 2).assertTrue();
        await scroll.scrollToBottom(1000); await driver.delayMs(500);
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-' + width + '-layout.png');
        const bounds = await itemBounds('隐私协议');
        const viewport = await scroll.getBounds();
        expect(bounds.top >= viewport.top && bounds.bottom <= viewport.bottom).assertTrue();
      }
    });
    it('wideFixesInformationAndScrollsOnlyTheRightHandSettings', 0, async () => {
      await selectWidth('wide');
      const layout = await required(ON.id('settings-wide-layout'), 'wide split');
      const information = await required(ON.id('settings-fixed-information'), 'fixed information');
      const before = await information.getBounds();
      const scroll = await required(ON.id('settings-scroll'), 'wide scroll');
      const viewport = await scroll.getBounds();
      const frame = await layout.getBounds();
      expect(before.right < viewport.left).assertTrue();
      expect(viewport.right <= frame.right && viewport.top >= frame.top).assertTrue();
      const logo = await required(ON.id('settings-app-icon'), 'application icon');
      const logoBefore = await logo.getBounds();
      await scroll.scrollToBottom(1000); await driver.delayMs(500);
      sameRect(before, await information.getBounds());
      sameRect(logoBefore, await logo.getBounds());
      const helpBounds = await itemBounds('隐私协议');
      expect(helpBounds.left >= viewport.left && helpBounds.bottom <= viewport.bottom).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-wide-layout.png');
    });
    it('homeResizesToFixedOverviewAndKeepsTheLastPhotosReachable', 0, async () => {
      await (await required(ON.id('layout-page-home'), 'home fixture')).click();
      await selectWidth('phone');
      expect(((await driver.findComponents(ON.id('home-wide-layout').inWindow(bundle)))?.length || 0)).assertEqual(0);
      const phoneScroll = await required(ON.id('home-phone-scroll'), 'phone home scroll');
      await phoneScroll.scrollToBottom(1000); await driver.delayMs(500);
      let photos = await driver.findComponents(ON.text('照片待恢复').inWindow(bundle));
      expect(photos.length).assertEqual(3);
      expect((await photos[2].getBounds()).bottom <= (await phoneScroll.getBounds()).bottom).assertTrue();

      await selectWidth('wide');
      const fixed = await required(ON.id('home-fixed-overview'), 'fixed home overview');
      const fixedBefore = await fixed.getBounds();
      const action = await required(ON.id('home-expenses'), 'fixed home action');
      const actionBefore = await action.getBounds();
      const plan = await required(ON.text('布局验证计划'), 'current plan');
      const planBefore = await plan.getBounds();
      const scroll = await required(ON.id('home-wide-scroll'), 'wide home scroll');
      const viewport = await scroll.getBounds();
      expect(fixedBefore.right < viewport.left).assertTrue();
      expect(planBefore.top >= fixedBefore.top && planBefore.bottom <= fixedBefore.bottom).assertTrue();
      const startCanvas = await (await required(ON.id('settings-layout-canvas'), 'wide canvas')).getBounds();
      const countdown = await (await required(ON.id('home-event-countdown'), 'long activity countdown')).getBounds();
      // The far-future fixture exposes the former two-line numeric overflow.
      expect(countdown.bottom - countdown.top <= 38 * (startCanvas.right - startCanvas.left) / 920 + 2).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-home-wide-start.png');
      await scroll.scrollToBottom(1000); await driver.delayMs(500);
      sameRect(fixedBefore, await fixed.getBounds());
      sameRect(actionBefore, await action.getBounds());
      sameRect(planBefore, await plan.getBounds());
      photos = await driver.findComponents(ON.text('照片待恢复').inWindow(bundle));
      expect(photos.length).assertEqual(3);
      const last = await photos[2].getBounds();
      const canvas = await (await required(ON.id('settings-layout-canvas'), 'wide canvas')).getBounds();
      const pixelsPerVp = (canvas.right - canvas.left) / 920;
      expect(last.left >= viewport.left && last.right <= viewport.right).assertTrue();
      expect(viewport.bottom - last.bottom >= 96 * pixelsPerVp - 2).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-home-wide-bottom.png');

      await selectWidth('phone');
      expect(((await driver.findComponents(ON.id('home-wide-layout').inWindow(bundle)))?.length || 0)).assertEqual(0);
      const restored = await (await required(ON.id('home-phone-scroll'), 'restored single column')).getBounds();
      const phoneCanvas = await (await required(ON.id('settings-layout-canvas'), 'phone canvas')).getBounds();
      expect(Math.abs((restored.right - restored.left) - (phoneCanvas.right - phoneCanvas.left)) <= 2).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-home-phone-restored.png');
    });
    it('mouseWheelForwardsFromOverviewAndTaskCardsKeepTheirContext', 0, async () => {
      await selectWidth('wide');
      const scroll = await required(ON.id('home-wide-scroll'), 'wide home scroll');
      await scroll.scrollToTop(1000); await driver.delayMs(500);
      const fixed = await required(ON.id('home-fixed-overview'), 'fixed home overview');
      const overviewBefore = await fixed.getBounds();
      const task = await required(ON.text('服装 · 准备任务 0'), 'first preparation task');
      const before = await task.getBounds();
      const point: Point = {
        x: Math.round((overviewBefore.left + overviewBefore.right) / 2),
        y: Math.round(overviewBefore.top + 20),
      };
      await driver.mouseScroll(point, true, 1); await driver.delayMs(500);
      const moved = await task.getBounds();
      expect(moved.top < before.top).assertTrue();
      sameRect(overviewBefore, await fixed.getBounds());
      // TestKit defines key 2072 as Ctrl; Dashboard leaves modified wheel events alone.
      await driver.mouseScroll(point, true, 1, 2072); await driver.delayMs(500);
      sameRect(moved, await task.getBounds());
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-home-wheel.png');

      await scroll.scrollToTop(1000); await driver.delayMs(500);
      const preparation = await required(ON.description('双击继续准备'), 'preparation card');
      await preparation.click(); await driver.delayMs(500);
      const result = await required(ON.id('layout-route-result'), 'task route result');
      const preparationRoute = await result.getText();
      expect(preparationRoute.startsWith('project:')).assertTrue();
      const projectId = preparationRoute.slice('project:'.length);
      expect(projectId.length > 0).assertTrue();
      const packing = await required(ON.description('双击继续打包'), 'packing card');
      await packing.click(); await driver.delayMs(500);
      expect(await result.getText()).assertEqual('packing:' + projectId);
      const selection = await scroll.scrollSearch(ON.description('双击继续选片').inWindow(bundle));
      expect(selection !== undefined).assertTrue();
      await (await required(ON.description('双击继续选片'), 'photo selection card')).click(); await driver.delayMs(500);
      expect(await result.getText()).assertEqual('projectPhotos:' + projectId);
      await scroll.scrollToBottom(1000); await driver.delayMs(500);
      const recent = await required(ON.description('双击打开最近照片'), 'recent photo card');
      await recent.click(); await driver.delayMs(500);
      expect(await result.getText()).assertEqual('photo:layout-photo-0');
    });
    it('largeFontActuallyScalesAndSettingsRemainInsideTheirCards', 0, async () => {
      await (await required(ON.id('layout-page-settings'), 'settings fixture')).click();
      for (const width of ['phone', 'narrow']) {
        await selectWidth(width);
        const probe = await required(ON.id('layout-font-probe'), 'font scale probe');
        const normal = await probe.getBounds();
        const scroll = await required(ON.id('settings-scroll'), 'settings scroll');
        await scroll.scrollSearch(ON.text('应用外观').inWindow(bundle));
        const normalLabel = await (await required(ON.text('跟随系统'), 'normal appearance label')).getBounds();
        try {
          await (await required(ON.id('layout-font-large'), 'large font control')).click(); await driver.delayMs(1200);
          const large = await probe.getBounds();
          expect(large.bottom - large.top > (normal.bottom - normal.top) * 1.7).assertTrue();
          await scroll.scrollSearch(ON.text('应用外观').inWindow(bundle));
          const viewport = await scroll.getBounds();
          const visibleCard = await itemBounds('应用外观');
          if (visibleCard.bottom >= viewport.bottom - 2) {
            // scrollSearch stops once the heading is visible; TestKit bounds clip the lower labels to the viewport.
            const x = Math.round((viewport.left + viewport.right) / 2);
            const height = viewport.bottom - viewport.top;
            await driver.swipe(x, Math.round(viewport.top + height * 0.7), x, Math.round(viewport.top + height * 0.3), 800);
            await driver.delayMs(700);
          }
          const card = await itemBounds('应用外观');
          expect(card.top > viewport.top && card.bottom < viewport.bottom).assertTrue();
          const path = '/data/storage/el2/base/cache/elvacos-settings-' + width + '-large-font';
          // TestKit may retain trailing bytes when replacing a shorter capture. Remove only our own two files.
          for (const suffix of ['.png', '.json']) { if (fileIo.accessSync(path + suffix)) { fileIo.unlinkSync(path + suffix); } }
          await driver.screenCap(path + '.png');
          await driver.dumpLayout(path + '.json');
          for (const label of ['应用外观', '天蓝', '雾蓝', '跟随系统']) {
            const text = await (await required(ON.text(label), label)).getBounds();
            expect(text.top >= card.top && text.bottom <= card.bottom && text.left >= card.left && text.right <= card.right).assertTrue();
          }
          const wrappedLabel = await (await required(ON.text('跟随系统'), 'large appearance label')).getBounds();
          // Full four-character label needs two lines at 2x; one clipped line formerly passed bounds-only checks.
          expect(wrappedLabel.bottom - wrappedLabel.top > (normalLabel.bottom - normalLabel.top) * 3.4).assertTrue();
          await scroll.scrollSearch(ON.text('材质等级').inWindow(bundle));
          const reference = await itemBounds('材质等级');
          expect(Math.abs((card.bottom - card.top) - (reference.bottom - reference.top)) <= 2).assertTrue();
        } finally {
          await (await required(ON.id('layout-font-default'), 'restore font control')).click(); await driver.delayMs(1000);
          sameRect(normal, await probe.getBounds());
        }
      }
    });
  });
}
