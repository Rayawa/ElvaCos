import { getApplicationState } from '../../../main/ets/common/appState';
import { DeviceCalendarService } from '../../../main/ets/common/DeviceCalendarService';
import { CollectedEntry } from '../../../main/ets/model/CollectedEntry';
import { CosEvent, CosProject, Character, ChecklistItem, PhotoAsset, PhotoStatus, ProjectStatus } from '../../../main/ets/model/Entities';
import { localDay } from '../../../main/ets/model/DayMode';
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
      if (!components || components.length === 0) { components = await driver.findComponents(ON.id('detail-action-' + text).inWindow(bundle)); }
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
      if (await driver.findComponent(ON.id('detail-action-' + text).inWindow(bundle))) { return; }
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
      expect((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle))).length).assertEqual(0);
      expect(((await driver.findComponents(ON.id('main-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
      expect(((await driver.findComponents(ON.type('ToolBar').inWindow(bundle)))?.length || 0)).assertEqual(0);
    };
    it('tabsSecondarySegmentsAndTitleMenusWork', 0, async () => {
      await tap('首页'); await present('root-action-我的');
      await driver.delayMs(1000);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-home.png');
      await tap('计划'); await tap('plan-role-library'); await present('添加角色');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-characters.png');
      const characters = await driver.findComponents(ON.description('双击打开角色详情').inWindow(bundle));
      if (characters.length > 0) {
        await characters[0].click(); await driver.delayMs(500); await present('添加版本');
        expect(((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
        await present('用这个角色新建计划'); await present('character-view-tabs');
        await tap('履历'); await present('角色履历'); await tap('参考图'); await present('参考图片'); await tap('资料');
        await tap('用这个角色新建计划'); await present('新建计划'); await tap('sheet-close');
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-character-detail.png');
        await tap('添加版本'); await present('添加角色版本'); await tap('sheet-close'); await present('添加版本');
        const characterScroll = await driver.findComponent(ON.id('character-detail-scroll').inWindow(bundle)); await characterScroll.scrollToBottom(1000); await driver.delayMs(350);
        await tap('character-entry-link'); await present('角色收录'); await tap('sheet-close');
        expect(((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
        await back(); await driver.delayMs(350);
      }
      await back(); await tap('计划'); await present('新建计划');
      const plans = await driver.findComponents(ON.description('双击打开计划详情').inWindow(bundle));
      if (plans.length > 0) {
        await plans[0].click(); await driver.delayMs(500);
        const viewport = await (await driver.findComponent(ON.id('project-overview').inWindow(bundle))).getBounds();
        for (const id of ['project-money-open', 'project-team-open']) {
          const bounds = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds();
          expect(bounds.top >= viewport.top && bounds.bottom <= viewport.bottom).assertTrue();
        }
        await tap('project-team-open'); await present('团队分工'); await tap('sheet-close');
        await (await driver.findComponent(ON.id('project-overview').inWindow(bundle))).scrollSearch(ON.id('project-records-open').inWindow(bundle));
        await tap('project-records-open'); await present('计划记录'); await tap('sheet-close'); await tap('照片'); await present('project-shots-open'); await tap('project-shots-open'); await present('拍摄清单');
        await tap('添加拍摄事项'); await present('拍摄事项 *'); await present('参考图（可选）'); await tap('sheet-close'); await present('拍摄清单'); await tap('sheet-close'); await back();
      }
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-projects.png');
      await tap('日程'); await present('添加活动');
      await tap('日历'); await present('今天'); await tap('今天'); await tap('列表'); await present('查看某一天（可选）');
      await tap('清除'); await present('event-list-filter');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-events.png');
      await tap('衣柜'); await present('添加装备');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-library.png');
      await present('全部类型'); await present('全部状态'); await present('全部位置');
      const asset = getApplicationState().assets[0];
      if (asset) {
        const wardrobe = await driver.findComponent(ON.id('library-scroll').inWindow(bundle));
        await wardrobe.scrollSearch(ON.id('wardrobe-asset:' + asset.id).inWindow(bundle)); await tap('wardrobe-asset:' + asset.id);
        expect(((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
        if (await driver.findComponent(ON.id('asset-view-tabs').inWindow(bundle))) { await tap('使用计划'); }
        await present('加入计划'); await tap('加入计划'); await present('选择计划加入装备'); await tap('sheet-close'); await back();
        await present('全部类型'); await present('全部状态'); await present('全部位置');
      }
      await tap('相册'); await present('按场次'); await present('待处理');
      const albumPlans = await driver.findComponents(ON.description('双击查看本场照片').inWindow(bundle));
      if (albumPlans.length > 0) { await albumPlans[0].click(); }
      await driver.delayMs(1000);
      if (albumPlans.length > 0 && !(await driver.findComponent(ON.text('这个范围还没有照片').inWindow(bundle)))) {
        const loadedPhotos = await driver.findComponents(ON.description('照片已加载').inWindow(bundle));
        expect(loadedPhotos.length > 0).assertTrue();
      }
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-library-photos.png');
      const photos = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
      if (photos.length > 0) {
        await photos[0].click(); await driver.delayMs(500); await present('照片工作流');
        await present('编辑照片说明'); await tap('编辑照片说明'); await present('编辑照片说明'); await present('照片说明'); await tap('sheet-close'); await present('照片工作流');
        expect(((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
        expect((await driver.findComponents(ON.description('照片已加载').inWindow(bundle))).length > 0).assertTrue();
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-photo-detail.png');
        await back(); await driver.delayMs(350);
      }
      await present('作品集展示 · 成片与已发布');
      await tap('首页');
    });
    it('globalSearchRestoresItsQueryAndOffersTheExistingObjectHomes', 0, async () => {
      await tap('首页');
      await (await driver.findComponent(ON.id('home-scroll').inWindow(bundle))).scrollSearch(ON.id('home-search').inWindow(bundle));
      await tap('home-search'); await present('全局搜索'); await present('search-view-tabs'); await present('global-search-input');
      await tap('search-role-library'); await present('添加角色'); await back(); await present('全局搜索');
      const role = getApplicationState().characters[0];
      if (role) {
        await tap('角色'); await (await driver.findComponent(ON.id('global-search-input').inWindow(bundle))).inputText(role.name); await driver.delayMs(400);
        await driver.pressBack(); await driver.delayMs(350); await present('search-view-tabs');
        const resultId = 'search-result:character:' + role.id;
        await (await driver.findComponent(ON.id('search-results').inWindow(bundle))).scrollSearch(ON.id(resultId).inWindow(bundle)); await tap(resultId);
        await present('character-view-tabs'); await back(); await present('search-view-tabs');
        await (await driver.findComponent(ON.id('search-results').inWindow(bundle))).scrollSearch(ON.id('global-search-input').inWindow(bundle));
        expect(await (await driver.findComponent(ON.id('global-search-input').inWindow(bundle))).getText()).assertEqual(role.name);
        await present(resultId);
      }
      await tap('资源'); await tap('search-resource-filter'); await tap('照片'); await present('search-resource-filter');
      await (await driver.findComponent(ON.id('global-search-input').inWindow(bundle))).inputText('ElvaCos-没有此名称-搜索边界'); await driver.delayMs(350);
      await driver.pressBack(); await driver.delayMs(350); await present('当前范围没有匹配结果'); await tap('清除搜索'); await present('打开角色库');
      expect((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle))).length).assertEqual(0);
      await back(); await present('home-search');
    });
    it('secondaryNativeTabsKeepSelectionAndPackingPositionWithIsolatedMetadata', 0, async () => {
      const state = getApplicationState();
      const oldCharacters = state.characters, oldProjects = state.projects, oldChecklist = state.checklist, oldPhotos = state.photos;
      const stamp = String(Date.now());
      const role = new Character(); role.id = 'ui-native-tabs-role-' + stamp; role.name = '页签验证角色' + stamp;
      const plan = new CosProject(); plan.id = 'ui-native-tabs-plan-' + stamp; plan.name = '页签验证计划' + stamp;
      plan.characterId = role.id; plan.status = ProjectStatus.PREPARING; plan.targetDate = localDay(Date.now());
      const packing: ChecklistItem[] = [], photos: PhotoAsset[] = [];
      for (let index = 0; index < 40; index++) {
        const item = new ChecklistItem(); item.id = 'ui-native-tabs-pack-' + stamp + '-' + index; item.projectId = plan.id;
        item.label = '临时打包项 ' + index; item.sortOrder = index; packing.push(item);
      }
      for (let index = 0; index < 12; index++) {
        const photo = new PhotoAsset(); photo.id = 'ui-native-tabs-photo-' + stamp + '-' + index;
        photo.projectId = plan.id; photo.status = PhotoStatus.RAW; photos.push(photo);
      }
      try {
        // Only runtime arrays and selection change; no files, Picker, Apply or repository write.
        state.characters = oldCharacters.concat(role); state.projects = oldProjects.concat(plan);
        state.checklist = oldChecklist.concat(packing); state.photos = oldPhotos.concat(photos);
        await tap('首页');
        await (await driver.findComponent(ON.id('home-scroll').inWindow(bundle))).scrollSearch(ON.id('home-search').inWindow(bundle));
        await tap('home-search'); await tap('search-view-tabs-0');
        await (await driver.findComponent(ON.id('global-search-input').inWindow(bundle))).inputText(plan.name);
        await driver.delayMs(400); await driver.pressBack(); await driver.delayMs(350);
        const resultId = 'search-result:project:' + plan.id;
        await (await driver.findComponent(ON.id('search-results').inWindow(bundle))).scrollSearch(ON.id(resultId).inWindow(bundle)); await tap(resultId);
        await present('project-view-tabs'); await present('project-overview'); await detailActions();
        await tap('project-view-tabs-2'); await present('project-packing');
        const anchor = 'packing-row:' + packing[20].id;
        await (await driver.findComponent(ON.id('project-packing').inWindow(bundle))).scrollSearch(ON.id(anchor).inWindow(bundle)); await driver.delayMs(350);
        const before = await (await driver.findComponent(ON.id(anchor).inWindow(bundle))).getBounds();
        await tap('project-view-tabs-3'); await present('photo-list'); await tap('批量选片'); await tap('全选当前筛选'); await present('已选 12 张');
        await tap('project-view-tabs-1'); await present('project-preparation');
        await tap('project-view-tabs-3'); await present('已选 12 张'); await tap('取消选择');
        await tap('project-view-tabs-2'); await present('project-packing'); await driver.delayMs(350);
        const after = await (await driver.findComponent(ON.id(anchor).inWindow(bundle))).getBounds();
        expect(Math.abs(after.top - before.top) <= 2 && Math.abs(after.bottom - before.bottom) <= 2).assertTrue();
        await back(); await present('search-view-tabs');
        await (await driver.findComponent(ON.id('search-results').inWindow(bundle))).scrollSearch(ON.id('global-search-input').inWindow(bundle));
        expect(await (await driver.findComponent(ON.id('global-search-input').inWindow(bundle))).getText()).assertEqual(plan.name);
        await tap('search-view-tabs-1');
        await (await driver.findComponent(ON.id('global-search-input').inWindow(bundle))).inputText(role.name);
        await driver.delayMs(400); await driver.pressBack(); await driver.delayMs(350);
        const roleResult = 'search-result:character:' + role.id;
        await (await driver.findComponent(ON.id('search-results').inWindow(bundle))).scrollSearch(ON.id(roleResult).inWindow(bundle)); await tap(roleResult);
        await present('character-view-tabs'); await tap('character-view-tabs-1'); await present('角色履历');
        await tap('character-view-tabs-2'); await present('参考图片'); await tap('character-view-tabs-0');
        await (await driver.findComponent(ON.id('character-detail-scroll').inWindow(bundle))).scrollSearch(ON.id('character-entry-link').inWindow(bundle)); await present('character-entry-link');
        await back(); await present('search-view-tabs'); await back(); await present('home-search');
        expect(state.checklist.filter((item: ChecklistItem): boolean => item.projectId === plan.id && item.done).length).assertEqual(0);
        expect(state.photos.filter((photo: PhotoAsset): boolean => photo.projectId === plan.id && photo.status !== PhotoStatus.RAW).length).assertEqual(0);
      } finally {
        for (let attempt = 0; attempt < 5 && !(await driver.findComponent(ON.id('main-tabs').inWindow(bundle))); attempt++) { await back(); }
        state.characters = oldCharacters; state.projects = oldProjects; state.checklist = oldChecklist; state.photos = oldPhotos;
        await tap('首页');
      }
    });
    it('inboxAndOwnerCollectionsKeepKindAndScrolledRowsThroughReturnAndSheetReopening', 0, async () => {
      const state = getApplicationState(); const oldEntries = state.entries; const oldEvents = state.events;
      const oldProjects = state.projects; const oldCharacters = state.characters;
      const event = new CosEvent(); event.id = 'ui-inbox-context-event'; event.name = '收录返回验证'; event.dateMode = 'pending';
      const fixtures: CollectedEntry[] = [];
      for (let index = 0; index < 32; index++) {
        const entry = new CollectedEntry(); entry.id = 'ui-inbox-context-' + index; entry.kind = 'map'; entry.scopeKind = 'event'; entry.scopeId = event.id; entry.title = '返回位置地图 ' + index; entry.text = '只读内存验证'; fixtures.push(entry);
      }
      const loose = new CollectedEntry(); loose.id = 'ui-inbox-context-loose'; loose.text = '未归位只读验证'; fixtures.push(loose);
      try {
        state.events = oldEvents.concat(event); state.entries = fixtures;
        await tap('首页'); await (await driver.findComponent(ON.id('home-scroll').inWindow(bundle))).scrollSearch(ON.id('home-inbox').inWindow(bundle)); await tap('home-inbox');
        await present('未归位'); await tap('entry-scope-filter'); await tap('全部收录'); await tap('entry-kind-filter'); await tap('地图');
        const id = 'entry-row:ui-inbox-context-30'; const scroll = await driver.findComponent(ON.id('inbox-scroll').inWindow(bundle));
        await scroll.scrollSearch(ON.id(id).inWindow(bundle)); await driver.delayMs(350);
        const before = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds(); await tap(id);
        await present('event-view-tabs'); await present('收录');
        await tap('entry-kind-filter'); await tap('地图');
        await (await driver.findComponent(ON.id('event-entries-scroll').inWindow(bundle))).scrollSearch(ON.id(id).inWindow(bundle)); await driver.delayMs(350);
        const eventBefore = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds();
        await tap('概览'); await tap('收录'); await present('地图');
        const eventAfter = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds();
        expect(Math.abs(eventAfter.top - eventBefore.top) <= 2 && Math.abs(eventAfter.bottom - eventBefore.bottom) <= 2).assertTrue();
        await (await driver.findComponent(ON.id('event-entries-scroll').inWindow(bundle))).scrollToTop(1000); await driver.delayMs(350);
        await (await driver.findComponent(ON.id('event-entries-scroll').inWindow(bundle))).scrollSearch(ON.id(id).inWindow(bundle)); await tap(id);
        const editor = await driver.findComponent(ON.id('entry-editor-scroll').inWindow(bundle));
        await editor.scrollSearch(ON.id('entry-input:url').inWindow(bundle));
        const urlInput = await driver.findComponent(ON.id('entry-input:url').inWindow(bundle)); await urlInput.inputText('not-a-url');
        await editor.scrollSearch(ON.text('保存修改').inWindow(bundle)); await tap('保存修改');
        await present('entry-action-error'); await driver.delayMs(2300);
        expect(await (await driver.findComponent(ON.id('entry-action-error').inWindow(bundle))).getText()).assertEqual('链接需要以 https:// 或 http:// 开头');
        await editor.scrollSearch(ON.id('entry-input:url').inWindow(bundle));
        expect(await (await driver.findComponent(ON.id('entry-input:url').inWindow(bundle))).getText()).assertEqual('not-a-url');
        expect(state.entries.find((entry: CollectedEntry): boolean => entry.id === 'ui-inbox-context-30')!.url).assertEqual('');
        await editor.scrollToTop(1000); await driver.delayMs(350); await tap('sheet-close'); await present('放弃本次修改？'); await tap('放弃修改');
        await (await driver.findComponent(ON.id('event-entries-scroll').inWindow(bundle))).scrollToTop(1000); await driver.delayMs(350);
        await tap('entry-kind-filter'); await tap('链接'); await present('没有匹配的收录'); await tap('entry-kind-filter'); await tap('地图');
        await present('entry-kind-filter'); await back(); await present(id);
        const after = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds();
        expect(Math.abs(after.top - before.top) <= 2 && Math.abs(after.bottom - before.bottom) <= 2).assertTrue();
        await (await driver.findComponent(ON.id('inbox-scroll').inWindow(bundle))).scrollToTop(1000); await driver.delayMs(350);
        await present('全部收录'); await present('地图'); await back();
        const role = new Character(); role.id = 'ui-owner-collection-role'; role.name = '收录位置验证角色';
        const plan = new CosProject(); plan.id = 'ui-owner-collection-plan'; plan.name = '收录位置验证计划'; plan.characterId = role.id;
        state.characters = oldCharacters.concat(role); state.projects = oldProjects.concat(plan);
        const checkOwnerSheet = async (kind: string, ownerId: string, sheetScrollId: string, pageScrollId: string, entryButtonId: string): Promise<void> => {
          state.entries = fixtures.map((entry: CollectedEntry): CollectedEntry => {
            const copy = new CollectedEntry(); copy.id = entry.id; copy.kind = entry.kind; copy.title = entry.title; copy.text = entry.text;
            copy.scopeKind = entry.scopeKind === 'global' ? 'global' : kind; copy.scopeId = copy.scopeKind === 'global' ? '' : ownerId; return copy;
          });
          await tap('首页'); await (await driver.findComponent(ON.id('home-scroll').inWindow(bundle))).scrollSearch(ON.id('home-inbox').inWindow(bundle)); await tap('home-inbox');
          await tap('entry-scope-filter'); await tap('全部收录'); await tap('entry-kind-filter'); await tap('地图');
          await (await driver.findComponent(ON.id('inbox-scroll').inWindow(bundle))).scrollSearch(ON.id(id).inWindow(bundle)); await tap(id);
          await present(sheetScrollId); await tap('entry-kind-filter'); await tap('地图');
          await (await driver.findComponent(ON.id(sheetScrollId).inWindow(bundle))).scrollSearch(ON.id(id).inWindow(bundle)); await driver.delayMs(350);
          const sheetBefore = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds();
          await tap('sheet-close');
          await (await driver.findComponent(ON.id(pageScrollId).inWindow(bundle))).scrollSearch(ON.id(entryButtonId).inWindow(bundle)); await tap(entryButtonId);
          await present(sheetScrollId);
          const sheetAfter = await (await driver.findComponent(ON.id(id).inWindow(bundle))).getBounds();
          expect(Math.abs(sheetAfter.top - sheetBefore.top) <= 2 && Math.abs(sheetAfter.bottom - sheetBefore.bottom) <= 2).assertTrue();
          await (await driver.findComponent(ON.id(sheetScrollId).inWindow(bundle))).scrollToTop(1000); await driver.delayMs(350); await present('地图');
          await tap('sheet-close'); await back(); await back();
        };
        await checkOwnerSheet('project', plan.id, 'project-entries-scroll', 'project-overview', 'project-entry-link');
        await checkOwnerSheet('character', role.id, 'character-entries-scroll', 'character-detail-scroll', 'character-entry-link');
      } finally {
        for (let attempt = 0; attempt < 4 && !(await driver.findComponent(ON.id('main-tabs').inWindow(bundle))); attempt++) { await back(); }
        state.entries = oldEntries; state.events = oldEvents; state.projects = oldProjects; state.characters = oldCharacters;
      }
    });
    it('residentTodaySnackBarFloatsAboveStableTabsAndReturnsFromDayMode', 0, async () => {
      const state = getApplicationState(); const oldEvents = state.events;
      const event = new CosEvent(); event.id = 'ui-snackbar-' + Date.now(); event.name = '今日通知位置验证'; event.date = localDay(Date.now());
      await tap('首页'); const before = await tabBounds();
      try {
        // Temporary metadata in memory: no business write and no persisted dismissal.
        state.events = [event]; state.tickClock();
        const enter = await driver.waitForComponent(ON.id('day-entry-bar').inWindow(bundle), 3000);
        if (!enter) { throw new Error('Official resident SnackBar did not appear'); }
        const close = await driver.findComponent(ON.id('day-entry-close').inWindow(bundle));
        if (!close) { throw new Error('Official resident SnackBar close action is missing'); }
        const after = await tabBounds();
        expect(after.top).assertEqual(before.top); expect(after.bottom).assertEqual(before.bottom);
        expect((await enter.getBounds()).bottom < after.top).assertTrue();
        expect((await close.getBounds()).bottom < after.top).assertTrue();
        await enter.click(); await driver.delayMs(500); await present('今天模式'); await present('现场');
        const dayDate = await driver.findComponent(ON.id('day-date-time').inWindow(bundle));
        expect(await dayDate.getText()).assertEqual(event.date + ' · 未标记时间');
        await present('day-location'); const dateBefore = await dayDate.getBounds();
        await tap('event-view-tabs-1'); await driver.delayMs(350);
        const dateAfter = await (await driver.findComponent(ON.id('day-date-time').inWindow(bundle))).getBounds();
        expect(dateAfter.top).assertEqual(dateBefore.top); expect(dateAfter.bottom).assertEqual(dateBefore.bottom);
        await present('day-location');
        expect((await driver.findComponents(ON.id('day-entry-bar').inWindow(bundle))).length).assertEqual(0);
        await back();
        if (!(await driver.waitForComponent(ON.id('day-entry-bar').inWindow(bundle), 3000))) { throw new Error('Today entry did not return to the root'); }
        const returned = await tabBounds(); expect(returned.top).assertEqual(before.top); expect(returned.bottom).assertEqual(before.bottom);
      } finally {
        // Remove the fixture before pressing Back, so the test cannot dismiss it into Preferences.
        state.events = oldEvents; state.tickClock(); await driver.delayMs(350);
        for (let attempt = 0; attempt < 4 && !(await driver.findComponent(ON.id('main-tabs').inWindow(bundle))); attempt++) { await back(); }
        await tap('首页');
      }
    });
    it('fixedChromeAndIndependentSettingsRespectSafeAreas', 0, async () => {
      await tap('衣柜');
      const before = await tabBounds();
      expect((await driver.findComponents(ON.id('secondary-segment-3').inWindow(bundle))).length).assertEqual(0);
      const titles = await driver.findComponents(ON.text('衣柜').inWindow(bundle));
      const titleBefore = await titles[0].getBounds();
      const windowBounds = await (await driver.findWindow({ bundleName: bundle })).getBounds();
      expect(titleBefore.top > windowBounds.top).assertTrue();
      const add = await driver.findComponent(ON.id('root-action-添加装备').inWindow(bundle)); const addBefore = await add.getBounds();
      await scrollBody();
      expect((await titles[0].getBounds()).top).assertEqual(titleBefore.top);
      expect((await add.getBounds()).top).assertEqual(addBefore.top);
      expect((await tabBounds()).top).assertEqual(before.top); expect(before.bottom < windowBounds.bottom).assertTrue();
      await tap('首页'); await tap('我的'); await settingsItem('用户名'); await driver.delayMs(1000);
      expect(((await driver.findComponents(ON.id('main-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-top.png');
      const settingsScroll = await driver.findComponent(ON.id('settings-scroll').inWindow(bundle));
      await settingsItem('材质等级');
      await settingsScroll.scrollToBottom(1000); await driver.delayMs(350);
      const footer = await driver.findComponent(ON.text('版本 1.0.0-beta.1').inWindow(bundle));
      expect((await footer.getBounds()).bottom < windowBounds.bottom).assertTrue();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-settings-bottom.png');
      await back(); await driver.delayMs(250); await present('root-action-我的'); await tap('衣柜'); await present('全部位置');
      expect((await tabBounds()).top).assertEqual(before.top);
    });
    it('titleMenuOpensCancelableCharacterFormWithoutWritingData', 0, async () => {
      await tap('计划'); await tap('plan-role-library'); await present('添加角色'); await tap('添加角色');
      await present('名称 *'); await present('保存');
      await driver.delayMs(250);
      const formTitle = await driver.findComponent(ON.text('添加角色').inWindow(bundle));
      const firstField = await driver.findComponent(ON.text('名称 *').inWindow(bundle));
      const formTitleBounds = await formTitle.getBounds();
      const firstFieldBounds = await firstField.getBounds();
      expect(firstFieldBounds.top - formTitleBounds.bottom < (formTitleBounds.bottom - formTitleBounds.top) * 1.5).assertTrue();
      await tap('保存');
      await driver.delayMs(250);
      await present('名称需要 1–80 个字');
      const fieldAfterError = await driver.findComponent(ON.id('form-input:name').inWindow(bundle));
      const fieldBounds = await fieldAfterError.getBounds();
      const viewport = await (await driver.findComponent(ON.id('form-scroll').inWindow(bundle))).getBounds();
      expect(fieldBounds.top >= viewport.top && fieldBounds.bottom <= viewport.bottom).assertTrue();
      expect((await (await driver.findComponent(ON.text('添加角色').inWindow(bundle))).getBounds()).top).assertEqual(formTitleBounds.top);
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-form.png');
      await tap('sheet-close'); await present('添加角色'); await back();
    });
    it('newPlanCreatesRoleInlineAndCanBeCanceledWithoutWrites', 0, async () => {
      await tap('计划'); await tap('新建计划'); await present('新建计划');
      await present('计划名称 *'); await present('创建计划并开始准备');
      const selector = await driver.findComponent(ON.type('Select').inWindow(bundle));
      await selector.click(); await driver.delayMs(250); await tap('＋ 创建新角色');
      await present('角色名称 *'); await present('所属作品（可选）');
      await tap('创建计划并开始准备'); await driver.delayMs(300);
      await present('角色名称 *');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-new-plan.png');
      await (await driver.findComponent(ON.id('form-input:characterName').inWindow(bundle))).inputText('未提交验证角色');
      await driver.delayMs(500); await back();
      const formScroll = await driver.findComponent(ON.id('form-scroll').inWindow(bundle)); await formScroll.scrollSearch(ON.id('form-project-more').inWindow(bundle)); await tap('form-project-more');
      await formScroll.scrollSearch(ON.id('form-input:shootingTime').inWindow(bundle)); await present('拍摄 / 约拍开始时间（可选）'); await tap('form-input:shootingTime');
      expect((await driver.findComponents(ON.type('TimePicker').inWindow(bundle))).length > 0).assertTrue(); await back();
      await formScroll.scrollSearch(ON.id('form-input:characterName').inWindow(bundle));
      await tap('sheet-close'); await present('继续编辑'); await tap('继续编辑');
      expect(await (await driver.findComponent(ON.id('form-input:characterName').inWindow(bundle))).getText()).assertEqual('未提交验证角色');
      await tap('sheet-close'); await present('放弃修改'); await tap('放弃修改'); await present('新建计划');
    });
    it('planViewsUseContextualActionsAndReturnToTheirTaskView', 0, async () => {
      await tap('计划');
      const plans = await driver.findComponents(ON.description('双击打开计划详情').inWindow(bundle));
      if (plans && plans.length > 0) {
        await plans[0].click(); await driver.delayMs(400);
        await tap('准备'); await present('准备进度'); await detailActions();
        await tap('添加准备任务'); await present('补入所选任务'); await present('常用准备模板'); await tap('sheet-close');
        await tap('从衣柜复用'); await present('从衣柜添加'); await tap('＋ 新装备'); await present('添加装备'); await present('名称 *');
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
          await selectable[0].click(); await present('已选 1 张'); await present('photo-batch-apply');
          await tap('取消选择');
          const restored = await driver.findComponents(ON.description('双击打开照片详情').inWindow(bundle));
          await restored[0].click(); await driver.delayMs(350); await present('照片工作流');
          await back(); await driver.delayMs(350); await present('批量选片');
        }
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-plan-photos.png');
        await tap('准备'); await present('准备进度');
        await back(); await driver.delayMs(250);
      }
      await tap('首页');
    });
    it('calendarChangesMonthAndCanCreatePendingOrMultidayActivityWithoutSaving', 0, async () => {
      await tap('日程'); await tap('日历'); await present('今天'); await present('calendar-previous'); await present('calendar-next');
      await tap('calendar-next'); await tap('今天');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-calendar.png');
      await tap('添加活动'); await present('添加活动'); await present('form-input:dateMode');
      const mode = await driver.findComponent(ON.id('form-input:dateMode').inWindow(bundle));
      await mode.click(); await tap('日期待定');
      expect(((await driver.findComponents(ON.text('日期 *').inWindow(bundle)))?.length || 0)).assertEqual(0);
      expect(((await driver.findComponents(ON.id('event-device-calendar').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await mode.click(); await tap('多日'); await present('开始日期 *'); await present('结束日期 *'); await present('event-device-calendar');
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-event-schedule.png');
      await tap('sheet-close'); await present('今天'); await tap('列表'); await present('日历'); await tap('首页');
    });
    it('photoImportPlanSheetCanBeClosedWithoutLaunchingPickerOrWritingData', 0, async () => {
      await tap('相册'); await tap('按场次'); await tap('album-plan-filter'); await tap('全部场次 / 计划'); await tap('导入照片');
      const form = await driver.findComponents(ON.text('新建计划').inWindow(bundle));
      if (form && form.length > 0) { await tap('sheet-close'); } else {
        await present('选择照片所属计划'); await present('新建计划后继续导入');
        await tap('新建计划后继续导入'); await present('新建计划'); await present('创建计划并导入照片'); await tap('sheet-close'); await present('导入照片');
      }
      await tap('首页');
    });
    it('expenseSummaryUsesCoveringRouteAndCancelableRecordSheet', 0, async () => {
      await tap('首页'); await tap('home-expenses'); await present('花费统计');
      expect(((await driver.findComponents(ON.id('detail-action-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
      expect(((await driver.findComponents(ON.id('main-tabs').inWindow(bundle)))?.length || 0)).assertEqual(0);
      await present('expense-range'); await present('expense-scope');
      await (await driver.findComponent(ON.id('expense-scroll').inWindow(bundle))).scrollSearch(ON.text('花费明细').inWindow(bundle));
      await present('花费明细');
      const before = await (await driver.findComponent(ON.text('花费明细').inWindow(bundle))).getBounds();
      await driver.screenCap('/data/storage/el2/base/cache/elvacos-expenses.png');
      await tap('记一笔'); await present('添加花费'); await present('实际花费（元） *'); await present('付款日期 *');
      await tap('sheet-close'); await present('花费统计');
      const after = await (await driver.findComponent(ON.text('花费明细').inWindow(bundle))).getBounds();
      expect(Math.abs(after.top - before.top) <= 2 && Math.abs(after.bottom - before.bottom) <= 2).assertTrue();
      await back(); await present('root-action-我的');
    });
    it('myIsOnlyOnHomeAndCreationBelongsToEachBusinessRoot', 0, async () => {
      const signedIn = getApplicationState().account.signedIn;
      await tap('首页'); await present('root-action-我的');
      expect((await driver.findComponents(ON.id('root-action-新建计划').inWindow(bundle))).length).assertEqual(0);
      await tap('我的'); await present('本机存储与同步');
      expect((await driver.findComponents(ON.text('登录').inWindow(bundle))).length).assertEqual(0);
      expect((await driver.findComponents(ON.text('退出').inWindow(bundle))).length).assertEqual(0);
      expect(getApplicationState().account.signedIn).assertEqual(signedIn);
      await back(); await present('root-action-我的');
      const tabs = ['计划', '日程', '衣柜', '相册'];
      const actions = ['新建计划', '添加活动', '添加装备', '导入照片'];
      for (let index = 0; index < tabs.length; index++) {
        await tap(tabs[index]); await present('root-action-' + actions[index]);
        expect((await driver.findComponents(ON.id('root-action-我的').inWindow(bundle))).length).assertEqual(0);
        expect((await driver.findComponents(ON.id('root-action-设置').inWindow(bundle))).length).assertEqual(0);
      }
      await tap('首页');
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
      await driver.delayMs(400); await present('root-action-我的');
    });
    it('settingsUseAlignedHandChoicesAndRealHelpSheets' , 0, async () => {
      await tap('首页'); await tap('我的'); await settingsItem('云同步');
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
      await back(); await back(); await driver.delayMs(350); await present('按场次');
    });
  });
}
