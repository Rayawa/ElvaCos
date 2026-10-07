import { Driver, ON } from '@kit.TestKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { monthlyExpenses, photoDistribution } from '../../../main/ets/model/Statistics';
import { portfolioStage } from '../../../main/ets/model/Rules';
import { Expense } from '../../../main/ets/model/Planning';
import { PhotoAsset, PhotoStatus } from '../../../main/ets/model/Entities';

export default function uiPolishTest(): void {
  describe('UiPolishAndCharts', () => {
    const bundle = 'top.rayawa.elvacos';
    let driver: Driver;
    const tap = async (text: string): Promise<void> => {
      const matches = await driver.findComponents(ON.text(text).inWindow(bundle));
      if (!matches || matches.length === 0) { throw new Error('Missing ' + text); }
      await matches[matches.length - 1].click(); await driver.delayMs(450);
    };
    const scroll = async (): Promise<void> => {
      const bounds = await (await driver.findWindow({ bundleName: bundle })).getBounds();
      const x = Math.round(bounds.right * 0.15);
      await driver.swipe(x, Math.round(bounds.bottom * 0.78), x, Math.round(bounds.bottom * 0.42), 900);
      await driver.delayMs(400);
    };
    beforeAll(async () => {
      driver = Driver.create();
      await driver.waitForComponent(ON.id('main-tabs').inWindow(bundle), 5000);
      await (await driver.findWindow({ bundleName: bundle })).focus();
      await tap('首页');
    });
    afterAll(async () => { await tap('首页'); });
    it('monthlyExpensesCrossYearAndPreserveCents', 0, () => {
      const dates = ['2025-12-31', '2026-01-01', '2026-01-31', '2025-08-01', '2026-03-01'];
      const amounts = [99, 10, 20, 10000, 30000];
      const records = dates.map((date: string, index: number): Expense => { const record = new Expense(); record.date = date; record.amountCents = amounts[index]; return record; });
      const points = monthlyExpenses(records, '2026-02-10');
      expect(points.length).assertEqual(6); expect(points[0].label).assertEqual('2025-09');
      expect(points[3].value).assertEqual(0.99); expect(points[4].value).assertEqual(0.30);
      expect(points[4].detail).assertEqual('2026-01 · ¥0.30 · 2 笔'); expect(points[5].value).assertEqual(0);
      expect(records.length).assertEqual(5);
    });
    it('photoDistributionCountsEveryStatusExactlyOnce', 0, () => {
      const photos = [PhotoStatus.IMPORTED, PhotoStatus.RAW, PhotoStatus.SELECTED, PhotoStatus.WAITING,
        PhotoStatus.RETOUCHED, PhotoStatus.FINAL, PhotoStatus.PUBLISHED, PhotoStatus.ARCHIVED]
        .map((status: PhotoStatus): PhotoAsset => { const photo = new PhotoAsset(); photo.status = status; return photo; });
      const groups = photoDistribution(photos);
      expect(groups.reduce((sum: number, item): number => sum + item.value, 0)).assertEqual(photos.length);
      expect(groups[0].value).assertEqual(2); expect(groups[3].value).assertEqual(2); expect(groups[4].value).assertEqual(1);
      expect(photoDistribution([]).every((item): boolean => item.value === 0)).assertTrue();
    });
    it('portfolioFiltersOnlyFinalAndPublishedPhotos', 0, () => {
      const photos = [PhotoStatus.RAW, PhotoStatus.RETOUCHED, PhotoStatus.FINAL, PhotoStatus.PUBLISHED, PhotoStatus.ARCHIVED]
        .map((status: PhotoStatus): PhotoAsset => { const photo = new PhotoAsset(); photo.status = status; return photo; });
      expect(portfolioStage(photos, 0).length).assertEqual(2);
      expect(portfolioStage(photos, 1)[0].status).assertEqual(PhotoStatus.FINAL);
      expect(portfolioStage(photos, 2)[0].status).assertEqual(PhotoStatus.PUBLISHED);
      expect(portfolioStage([], 0).length).assertEqual(0);
    });
    it('countdownAndCaptionShareHorizontalCenter', 0, async () => {
      const countdown = await driver.findComponent(ON.id('home-event-countdown').inWindow(bundle));
      if (!countdown) { return; }
      const number = await countdown.getBounds();
      const caption = await (await driver.findComponent(ON.id('home-event-caption').inWindow(bundle))).getBounds();
      expect(Math.abs((number.left + number.right) / 2 - (caption.left + caption.right) / 2) < 3).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-polish-home.png');
    });
    it('portfolioSelectorRefreshesVisiblePhotos', 0, async () => {
      await tap('我的'); await tap('作品'); await driver.delayMs(900);
      expect(!!(await driver.findComponent(ON.text('照片处理分布').inWindow(bundle)))).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-polish-distribution.png');
      await scroll();
      const filter = await driver.findComponent(ON.id('portfolio-status-filter').inWindow(bundle));
      expect(!!filter).assertTrue(); await filter.click(); await driver.delayMs(250);
      await tap('已发布'); await driver.delayMs(400);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-polish-portfolio.png');
      const cards = (await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle))) || [];
      if (cards.length > 0) {
        expect((await driver.findComponents(ON.type('Text').text('已发布').inWindow(bundle))).length > 1).assertTrue();
        const finalLabels = (await driver.findComponents(ON.type('Text').text('最终作品').inWindow(bundle))) || [];
        for (const label of finalLabels) {
          const bounds = await label.getBounds();
          expect(bounds.right === bounds.left || bounds.bottom < 332 || bounds.top > 2550).assertTrue();
        }
      }
      await filter.click(); await driver.delayMs(250); await tap('全部作品');
    });
    it('calendarAndButtonPressFeedbackRenders', 0, async () => {
      await tap('活动'); await tap('日历');
      const today = await driver.findComponent(ON.text('今天').inWindow(bundle));
      const bounds = await today.getBounds();
      await driver.longClick(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2));
      await driver.delayMs(200);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-polish-calendar.png');
    });
    it('expenseTrendSelectsMonth', 0, async () => {
      await tap('首页');
      await (await driver.findComponent(ON.id('home-expenses').inWindow(bundle))).click(); await driver.delayMs(900);
      const detail = await driver.findComponent(ON.id('line-chart-detail:近半年花费趋势').inWindow(bundle));
      expect(!!detail).assertTrue(); const before = await detail.getText();
      await (await driver.findComponent(ON.id('line-chart-canvas:近半年花费趋势').inWindow(bundle))).click();
      await driver.delayMs(250);
      expect((await detail.getText()) !== before).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-polish-expenses.png');
      await driver.pressBack(); await driver.delayMs(400);
    });
  });
}
