import { DeviceCalendarService } from '../../../main/ets/common/DeviceCalendarService';
import { AccountService } from '../../../main/ets/common/AccountService';
import { CosEvent } from '../../../main/ets/model/Entities';
import { Driver, ON, Rect, abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, beforeAll, beforeEach, afterAll, it, expect } from '@ohos/hypium';

export default function uiShellTest(): void {
  describe('HdsShell', () => {
    let driver: Driver;
    const bundle = 'top.rayawa.elvacos';
    const tap = async (text: string): Promise<void> => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      let components = await driver.findComponents(ON.text(text).inWindow(bundle));
      if (!components || components.length === 0) { components = await driver.findComponents(ON.id('root-action-' + text).inWindow(bundle)); }
      if (!components || components.length === 0) { components = await driver.findComponents(ON.id(text).inWindow(bundle)); }
      if (!components || components.length === 0) { throw new Error('Missing application component: ' + text); }
      // Native tab labels come after the current page's title in the layout tree.
      await components[components.length - 1].click();
      await driver.delayMs(350);
    }
    const back = async (): Promise<void> => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      await driver.pressBack(); await driver.delayMs(500);
    };
    const present = async (text: string): Promise<void> => {
      if (await driver.findComponent(ON.id('root-action-' + text).inWindow(bundle))) { return; }
      if (await driver.findComponent(ON.id(text).inWindow(bundle))) { return; }
      if (!(await driver.waitForComponent(ON.text(text).inWindow(bundle), 3000))) {
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-ui-missing.png');
        throw new Error('Missing visible application component: ' + text);
      }
    }
    beforeAll(async () => {
      driver = Driver.create();
      await present('首页');
      const appWindow = await driver.findWindow({ bundleName: bundle });
      await appWindow.focus();
      await present('首页');
    });
    beforeEach(async () => {
      await (await driver.findWindow({ bundleName: bundle })).focus();
      await driver.delayMs(350);
    });
    afterAll(async () => { await tap('首页'); });
    const scrollBody = async (): Promise<void> => {
      const bounds = await (await driver.findWindow({ bundleName: bundle })).getBounds();
      // Keep vertical gestures in the label column, away from Settings sliders.
      const x = Math.round(bounds.left + (bounds.right - bounds.left) * 0.2);
      await driver.swipe(x, Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.7), x, Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.3), 800);
      await driver.delayMs(350);
    };
    const tabBounds = async (): Promise<Rect> => {
      const tabs = await driver.findComponents(ON.type('Column').text('首页').inWindow(bundle));
      return tabs[tabs.length - 1].getBounds();
    };
    const settingsItem = async (text: string): Promise<void> => {
      const scroll = await driver.findComponent(ON.id('settings-scroll').inWindow(bundle));
      if (!scroll) { throw new Error('Missing settings scroll container'); }
      await scroll.scrollSearch(ON.text(text).inWindow(bundle));
      await driver.delayMs(350);
      await present(text);
    };
    const detailActions = async (): Promise<void> => {
      expect((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle))).length).assertEqual(1);
      expect(((await driver.findComponents(ON.id('main-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
      expect(((await driver.findComponents(ON.type('ToolBar').inWindow(bundle)))?.length || 0)).assertEqual(0);
    };
    it('tabsSecondarySegmentsAndTitleMenusWork', 0, async () => {
      await tap('首页'); await present('新建计划');
      await driver.delayMs(1000);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-home.png');
      await tap('Cos'); await tap('角色'); await present('添加角色');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-characters.png');
      const characters = await driver.findComponents(ON.description('双击打开角色详情').inWindow(bundle));
      if (characters.length > 0) {
        await characters[0].click(); await driver.delayMs(500); await present('添加版本');
        await detailActions();
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-character-detail.png');
        await tap('添加版本'); await present('添加角色版本'); await tap('sheet-close'); await present('添加版本');
        await detailActions();
        await back(); await driver.delayMs(350);
      }
      await tap('计划'); await present('新建计划');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-projects.png');
      await tap('活动'); await present('添加活动');
      await tap('日历'); await present('今天'); await tap('列表'); await present('event-list-filter');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-events.png');
      await tap('衣柜'); await tap('装备'); await present('添加装备');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-library.png');
      await tap('照片'); await present('导入照片');
      await driver.delayMs(1000);
      if (!(await driver.findComponent(ON.text('每一张，都是一次登场').inWindow(bundle)))) {
        const loadedPhotos = await driver.findComponents(ON.description('照片已加载').inWindow(bundle));
        expect(loadedPhotos.length > 0).assertTrue();
      }
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-library-photos.png');
      const photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
      if (photos.length > 0) {
        await photos[0].click(); await driver.delayMs(500); await present('设为封面');
        await detailActions();
        expect((await driver.findComponents(ON.description('照片已加载').inWindow(bundle))).length > 0).assertTrue();
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-photo-detail.png');
        await back(); await driver.delayMs(350);
      }
      await tap('我的'); await tap('时间轴'); await present('热爱的轨迹');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-timeline.png');
      await tap('作品'); await present('作品集');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-me.png');
    });
    it('fixedChromeAndIndependentSettingsRespectSafeAreas', 0, async () => {
      await tap('衣柜'); await tap('装备');
      const before = await tabBounds();
      const segment = await driver.findComponent(ON.id('secondary-segment-3').inWindow(bundle));
      const segmentBefore = await segment.getBounds();
      const titles = await driver.findComponents(ON.text('衣柜').inWindow(bundle));
      const titleBefore = await titles[0].getBounds();
      const appWindow = await driver.findWindow({ bundleName: bundle });
      const windowBounds = await appWindow.getBounds();
      expect(titleBefore.top > windowBounds.top).assertTrue();
      expect(segmentBefore.top < titleBefore.bottom && segmentBefore.bottom > titleBefore.top).assertTrue();
      const scroll = await driver.findComponent(ON.id('library-scroll').inWindow(bundle));
      await scrollBody();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-library-scrolled.png');
      const segmentAfter = await (await driver.findComponent(ON.id('secondary-segment-3').inWindow(bundle))).getBounds();
      expect(segmentAfter.top).assertEqual(segmentBefore.top);
      expect((await tabBounds()).top).assertEqual(before.top);
      expect(before.bottom < windowBounds.bottom).assertTrue();
      await tap('我的'); await tap('设置'); await settingsItem('用户名'); await driver.delayMs(1000);
      expect(((await driver.findComponents(ON.id('main-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-top.png');
      const settingsScroll = await driver.findComponent(ON.id('settings-scroll').inWindow(bundle));
      await settingsItem('材质等级');
      await settingsScroll.scrollToBottom(1000); await driver.delayMs(350);
      const footer = await driver.findComponent(ON.text('版本 1.0.0-beta.1').inWindow(bundle));
      expect((await footer.getBounds()).bottom < windowBounds.bottom).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-bottom.png');
      await back(); await driver.delayMs(250); await present('作品集');
      expect((await tabBounds()).top).assertEqual(before.top);
    });
    it('titleMenuOpensCancelableCharacterFormWithoutWritingData', 0, async () => {
      await tap('Cos'); await tap('角色'); await present('添加角色'); await tap('添加角色');
      await present('名称 *'); await present('保存');
      await driver.delayMs(250);
      const formTitle = await driver.findComponent(ON.text('添加角色').inWindow(bundle));
      const firstField = await driver.findComponent(ON.text('名称 *').inWindow(bundle));
      const formTitleBounds = await formTitle.getBounds();
      const firstFieldBounds = await firstField.getBounds();
      expect(firstFieldBounds.top - formTitleBounds.bottom < (formTitleBounds.bottom - formTitleBounds.top) * 1.5).assertTrue();
      await tap('保存');
      await driver.delayMs(250);
      const fieldAfterError = await driver.findComponent(ON.text('名称 *').inWindow(bundle));
      expect((await fieldAfterError.getBounds()).top).assertEqual(firstFieldBounds.top);
      expect((await (await driver.findComponent(ON.text('添加角色').inWindow(bundle))).getBounds()).top).assertEqual(formTitleBounds.top);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-form.png');
      await tap('sheet-close'); await present('添加角色');
    });
    it('newPlanCreatesRoleInlineAndCanBeCanceledWithoutWrites', 0, async () => {
      await tap('首页'); await tap('新建计划'); await present('新建 Cos 计划');
      await present('计划名称 *'); await present('创建计划并开始准备');
      const selector = await driver.findComponent(ON.type('Select').inWindow(bundle));
      await selector.click(); await driver.delayMs(250); await tap('＋ 创建新角色');
      await present('角色名称 *'); await present('所属作品（可选）');
      await tap('创建计划并开始准备'); await driver.delayMs(300);
      await present('角色名称 *');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-new-plan.png');
      await tap('sheet-close'); await present('新建计划');
    });
    it('planViewsUseContextualActionsAndReturnToTheirTaskView', 0, async () => {
      await tap('Cos'); await tap('计划');
      const plans = await driver.findComponents(ON.description('双击打开计划详情').inWindow(bundle));
      if (plans && plans.length > 0) {
        await plans[0].click(); await driver.delayMs(400);
        await present('准备进度'); await detailActions();
        await tap('准备任务'); await present('补入所选任务'); await present('常用准备模板'); await tap('sheet-close');
        await tap('从衣柜'); await present('从衣柜添加'); await tap('＋ 新装备'); await present('添加装备'); await present('名称 *');
        await tap('sheet-close'); await present('准备进度');
        await tap('打包'); await present('打包清单');
        expect((await driver.findComponents(ON.id('project-packing').inWindow(bundle))).length).assertEqual(1);
        await tap('添加物品'); await present('添加清单项'); await tap('sheet-close'); await present('打包清单');
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-packing.png');
        await tap('照片'); await present('批量选片'); await present('导入照片');
        const photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
        if (photos && photos.length > 0) {
          await tap('批量选片');
          const selectable = await driver.findComponents(ON.description('双击切换照片选择').inWindow(bundle));
          await selectable[0].click(); await present('已选 1 张'); await present('应用');
          await tap('取消选择');
          const restored = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
          await restored[0].click(); await driver.delayMs(350); await present('设为封面');
          await back(); await driver.delayMs(350); await present('批量选片');
        }
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-plan-photos.png');
        await tap('准备'); await present('准备进度');
        await back(); await driver.delayMs(250);
      }
      await tap('首页');
    });
    it('calendarChangesMonthAndCanCreatePendingOrMultidayActivityWithoutSaving', 0, async () => {
      await tap('活动'); await tap('日历'); await present('今天'); await present('calendar-previous'); await present('calendar-next');
      await tap('calendar-next'); await tap('今天');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-calendar.png');
      await tap('添加活动'); await present('添加活动'); await present('event-date-mode');
      const mode = await driver.findComponent(ON.id('event-date-mode').inWindow(bundle));
      await mode.click(); await tap('日期待定');
      expect(((await driver.findComponents(ON.text('日期 *').inWindow(bundle)))?.length || 0)).assertEqual(0);
      expect(((await driver.findComponents(ON.id('event-device-calendar').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await mode.click(); await tap('多日'); await present('开始日期 *'); await present('结束日期 *'); await present('event-device-calendar');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-event-schedule.png');
      await tap('sheet-close'); await present('今天'); await tap('列表'); await present('日历'); await tap('首页');
    });
    it('photoImportPlanSheetCanBeClosedWithoutLaunchingPickerOrWritingData', 0, async () => {
      await tap('衣柜'); await tap('照片'); await tap('导入照片');
      const form = await driver.findComponents(ON.text('新建 Cos 计划').inWindow(bundle));
      if (form && form.length > 0) { await tap('sheet-close'); } else {
        await present('选择照片所属计划'); await tap('sheet-close'); await present('导入照片');
      }
      await tap('首页');
    });
    it('expenseSummaryUsesCoveringRouteAndCancelableRecordSheet', 0, async () => {
      await tap('首页'); await tap('home-expenses'); await present('花费统计'); await detailActions(); await present('花费明细');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-expenses.png');
      await tap('记一笔'); await present('添加花费'); await present('实际花费（元） *'); await present('付款日期 *');
      await tap('sheet-close'); await present('花费统计'); await back(); await present('新建计划');
    });
    it('unconfiguredAccountStopsBeforeSystemLoginAndKeepsLocalState', 0, async () => {
      await tap('首页');
      const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      const configuration = AccountService.configurationMessage(ability.context);
      if (configuration) {
        const result = await new AccountService().signIn(ability.context);
        expect(result.ok).assertFalse(); expect(result.message.includes('Client ID')).assertTrue();
        await present('新建计划');
      }
    });
    it('systemCalendarEditorCanBeCanceledWithoutCreatingDeviceOrAppData', 0, async () => {
      await tap('首页');
      const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      const event = new CosEvent(); event.name = '日历联动验证（不保存）'; event.date = '2027-01-03'; event.city = '杭州'; event.venue = '公园'; event.timeMode = 'range'; event.startTime = '09:00'; event.endTime = '11:00'; event.reminderMinutes = 30;
      let settled = false; let added = false; let failure = '';
      const operation = new DeviceCalendarService().add(event, ability.context).then((value: boolean): void => { settled = true; added = value; }, (error: Error): void => { settled = true; failure = error.message; });
      await driver.delayMs(1500);
      expect(settled).assertFalse();
      expect((await driver.findComponents(ON.text(event.name))).length > 0).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-device-calendar-confirm.png');
      await driver.pressBack(); await driver.delayMs(400);
      const discard = await driver.findComponent(ON.text('放弃'));
      if (discard) { await discard.click(); }
      await operation; expect(failure).assertEqual(''); expect(added).assertFalse();
      await driver.delayMs(400); await present('新建计划');
    });
    it('settingsUseAlignedHandChoicesAndRealHelpSheets' , 0, async () => {
      await tap('我的'); await tap('作品'); await tap('设置'); await settingsItem('云同步');
      await tap('说明'); await present('云空间与同步'); await present('导出元数据备份'); await tap('sheet-close');
      await settingsItem('用户名'); await settingsItem('材质等级'); await settingsItem('右手');
      await driver.delayMs(700);
      expect(((await driver.findComponents(ON.text('操作偏好').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await present('跟随系统'); await present('左手'); await present('智感握持'); await present('右手');
      const left = await (await driver.findComponent(ON.text('左手').inWindow(bundle))).getBounds();
      const grip = await (await driver.findComponent(ON.text('智感握持').inWindow(bundle))).getBounds();
      const right = await (await driver.findComponent(ON.text('右手').inWindow(bundle))).getBounds();
      expect(left.right <= grip.left && grip.right <= right.left).assertTrue();
      expect(left.top).assertEqual(grip.top); expect(grip.top).assertEqual(right.top);
      expect(((await driver.findComponents(ON.type('Select').inWindow(bundle)))?.length || 0)).assertEqual(0);
      expect(((await driver.findComponents(ON.type('Toggle').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-preferences.png');
      await settingsItem('使用说明'); await tap('使用说明');
      await present('准备一次 Cos'); await tap('sheet-close'); await present('隐私政策');
      await tap('更新日志'); await present('1.0.0-beta.1'); await present('app-log-scroll');
      await present('app-log-filter-rc'); await present('app-log-filter-release');
      await tap('app-log-filter-beta'); await present('暂无符合条件的日志');
      await tap('app-log-filter-beta'); await present('1.0.0-beta.1');
      await back();
      await tap('隐私政策'); await present('关于绮秀与隐私的声明'); await present('privacy-scroll');
      await back(); await back(); await driver.delayMs(350); await present('作品集');
    });
  });
}
