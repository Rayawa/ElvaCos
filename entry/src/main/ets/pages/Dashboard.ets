import { EventRoute, EventReturnPath } from '../model/EventRoute';
import { dayTitle } from '../model/DayMode';
import { InboxPage } from './more/InboxPage';
import { InboxRoute } from '../model/CollectedEntry';
import { AppLogPage } from './more/AppLogPage';
import { DevPage } from './more/DevPage';
import { LocalHtmlPage } from './more/LocalHtmlPage';
import { getApplicationState } from '../common/appState';
import { DEVELOPER_PAGE_TITLE, MAIN_PAGE_TITLES, SETTINGS_ENTRANCE_KEY } from '../common/constants';
import { PressFeedback } from '../common/pressFeedback';
import { DetailDestination } from '../component/DetailDestination';
import { StaggerEntrance, MainEntranceSession } from '../common/motion';
import { ReferenceDetail } from './detail/ReferenceDetailPage';
import { ExpenseSummary } from './more/ExpenseSummaryPage';
import { ReferenceImage } from '../model/Planning';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsNavigationMenuItemOptions,
  BlurStrategy,
} from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { AppState } from '../model/ApplicationState';
import { confirm } from '../common/Confirm';
import { showToastSafely } from '../common/safeUi';
import { appSheetOptions } from '../common/sheet';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';
import { SheetHeader } from '../component/SheetHeader';
import { SegmentButtonV2Items, SegmentButtonV2ItemOptions } from '@kit.ArkUI';
import { HdsTitleBarSegment } from '../component/HdsTitleBarSegment';
import { HdsActionTabs } from '../component/HdsActionTabs';
import { HapticService } from '../common/HapticService';
import { ProjectRoute } from '../model/ProjectRoute';
import { EditDraft } from '../model/EditDraft';
import { Character, CosProject, Asset, CosEvent, PhotoAsset, PhotoStatus } from '../model/Entities';
import { SystemCapability } from '../common/SystemCapability';
import { HomePage } from './main/HomePage';
import { CosPage } from './main/CosPage';
import { EventsPage } from './main/EventsPage';
import { LibraryPage } from './main/LibraryPage';
import { SettingsPage } from './more/SettingsPage';
import { MePage } from './main/MePage';
import { CharacterDetail } from './detail/CharacterDetailPage';
import { ProjectDetail } from './detail/ProjectDetailPage';
import { AssetDetail } from './detail/AssetDetailPage';
import { EventDetail } from './detail/EventDetailPage';
import { PhotoDetail } from './detail/PhotoDetailPage';
import { PhotoGrid } from '../component/PhotoGrid';
import { FormEditor } from '../component/FormEditor';
import { EmptyState } from '../component/Surfaces';

@Entry
@ComponentV2
  struct Dashboard {
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Local state: AppState = getApplicationState();
  private mainEntranceSession: MainEntranceSession = new MainEntranceSession();
  private detailStack: NavPathStack = new NavPathStack();
  private stacks: NavPathStack[] = [new NavPathStack(), new NavPathStack(), new NavPathStack(), new NavPathStack(), new NavPathStack()];
  private pageScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller(), new Scroller()];
  private tabsController: HdsTabsController = new HdsTabsController();
  @Local tab: number = 0;
  @Local cosProjects: boolean = true;
  @Local eventCalendar: boolean = false;
  @Local eventFilter: number = 0;
  @Local meSection: number = 0;
  @Local libraryPhotos: boolean = false;
  @Local rootSheetKind: string = 'form';
  @Local importOpen: boolean = false;
  @Local formOpen: boolean = false;
  @Local draft: EditDraft = new EditDraft();
  @Local viewportWidth: number = 360;
  private clockTimer: number = -1;
  private startupTimer: number = -1;
  private maintenanceTimer: number = -1;
  private visible: boolean = false;
  private maintenanceDone: boolean = false;

  onPageShow(): void {
    this.visible = true;
    this.state.tickClock();
    if (this.clockTimer < 0) { this.clockTimer = setInterval((): void => { this.state.tickClock(); }, 1000); }
    if (this.startupTimer >= 0) { return; }
    this.startupTimer = setTimeout(async (): Promise<void> => {
      this.startupTimer = -1;
      await this.state.start(this.getUIContext().getHostContext() as common.UIAbilityContext);
      if (this.visible && this.state.ready && !this.maintenanceDone) {
        this.maintenanceTimer = setTimeout((): void => {
          this.maintenanceTimer = -1;
          if (!this.state.busy) { this.maintenanceDone = true; this.state.maintain(); }
        }, 300);
      }
    }, 0);
  }

  private cancelTasks(): void {
    this.visible = false;
    if (this.clockTimer >= 0) { clearInterval(this.clockTimer); this.clockTimer = -1; }
    if (this.startupTimer >= 0) { clearTimeout(this.startupTimer); this.startupTimer = -1; }
    if (this.maintenanceTimer >= 0) { clearTimeout(this.maintenanceTimer); this.maintenanceTimer = -1; }
    this.state.suspend();
  }

  aboutToDisappear(): void { this.cancelTasks(); }
  @Monitor('state.ready', 'state.pendingEventId')
  openPendingEvent(): void {
    if (!this.state.ready || !this.state.pendingEventId) { return; }
    const id = this.state.pendingEventId; this.state.pendingEventId = '';
    if (this.state.events.some((e: CosEvent) => e.id === id)) { this.open('event', id); }
  }
  onPageHide(): void { this.cancelTasks(); }

  /** 二级页面返回：Dashboard AppDetailPage 的 closePage 语义 + 显式返回振动。 */
  private closeDetail(): void {
    HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel);
    if (this.detailStack.size() > 0) { this.detailStack.pop(); }
  }
  private open(kind: string, id: string): void {
    if (!id) { return; }
    HapticService.confirm(this.state.settings.haptic);
    this.state.suspend();
    if (kind === 'event' || kind === 'dayEvent') { this.openEvent(id, kind === 'dayEvent'); return; }
    if (kind === 'inbox' && id.startsWith('event|')) { this.openEvent(id.slice(6), false, 2); return; }
    if (kind === 'inbox') {
      const parts = id.split('|'); this.detailStack.pushPathByName('inbox', new InboxRoute(parts[0] || 'global', parts[1] || ''));
    } else if (kind === 'project' || kind === 'packing' || kind === 'projectPhotos' || kind === 'outing') {
      const section = kind === 'packing' || kind === 'outing' ? 1 : kind === 'projectPhotos' ? 2 : 0;
      const route = new ProjectRoute(id, section); route.outing = kind === 'outing';
      this.detailStack.pushPathByName('project', route);
    } else {
      this.detailStack.pushPathByName(kind, id);
    }
  }

  private openEvent(id: string, dayMode: boolean, section: number = 0): void {
    const current = this.stacks[2].size() > 0 ? this.stacks[2].getParamByIndex(this.stacks[2].size() - 1) as EventRoute : undefined;
    if (this.detailStack.size() === 0 && current && current.id === id) {
      if (current.dayMode !== dayMode) { current.section = section; current.dayMode = dayMode; }
      else if (!dayMode && section !== 0) { current.section = section; }
      if (!current.returnPaths.length) { current.sourceTab = this.tab === 2 ? current.sourceTab : this.tab; }
      this.tab = 2; this.tabsController.changeIndex(2); return;
    }
    const route = new EventRoute(id, dayMode, section); route.sourceTab = this.tab;
    const names = this.detailStack.getAllPathName();
    names.forEach((name: string, index: number): void => { route.returnPaths.push(new EventReturnPath(name, this.detailStack.getParamByIndex(index) as Object)); });
    if (names.length) { this.detailStack.clear(false); }
    this.tab = 2; this.tabsController.changeIndex(2);
    this.stacks[2].pushPathByName('event', route);
  }
  private closeEvent(route: EventRoute): void {
    if (this.stacks[2].size() === 0 || this.stacks[2].getParamByIndex(this.stacks[2].size() - 1) !== route) { return; }
    this.stacks[2].pop(); this.tab = route.sourceTab; this.tabsController.changeIndex(route.sourceTab);
    for (const path of route.returnPaths) { this.detailStack.pushPathByName(path.name, path.param, false); }
    route.returnPaths = [];
  }
  private eventMenus(route: EventRoute): HdsNavigationMenuItemOptions[] {
    if (route.dayMode || !this.state.events.some((event: CosEvent) => event.id === route.id)) { return []; }
    return [{ content: { label: '编辑活动', icon: Icons.edit, isEnabled: !this.state.busy, action: (): void => { this.edit('event', route.id); } } },
      { content: { label: '删除活动', icon: Icons.remove, isEnabled: !this.state.busy, action: (): void => { this.remove('event', route.id); } } }];
  }
  @Builder eventSegment(route: EventRoute) {
    HdsTitleBarSegment({ componentId: 'event-detail-segment', items: this.buildSegmentItems(['概览', '本场计划', '收录', '提醒']), selectedIndexes: [route.section],
      minimumTargetHeight: 48, segmentHeight: 56, experimentalHeight: 60,
      experimentalWidth: Math.max(240, Math.min(460, this.viewportWidth - 100)),
      onSelectedIndexChanged: (section: number): void => { route.section = section; },
      onItemClicked: (): void => { HapticService.confirm(this.state.settings.haptic); } })
  }
  @Builder eventContent(route: EventRoute, entrance: StaggerEntrance) {
    if (this.state.events.some((event: CosEvent) => event.id === route.id)) {
      EventDetail({ state: this.state, event: this.state.events.find((event: CosEvent) => event.id === route.id) as CosEvent, route: route, entrance: entrance,
        open: (kind: string, id: string): void => { this.open(kind, id); },
        edit: (kind: string, id: string, parent: string): void => { this.edit(kind, id, parent); }, back: (): void => { this.closeEvent(route); } })
    } else {
      EmptyState({ title: '活动已不存在', message: '关联计划仍保留，可以返回继续查看。', button: '返回', action: (): void => { this.closeEvent(route); } }).margin({ top: Theme.detailTop, left: Theme.pagePadding, right: Theme.pagePadding })
    }
  }
  @Builder scheduleDestination(kind: string, param: Object) {
    if (kind === 'event') {
      DetailDestination({ customTitle: (param as EventRoute).dayMode, titleOptions: SystemCapability.titleBar((param as EventRoute).dayMode ? '今天模式' : '', this.state.settings.effects, this.state.settings.materialLevel,
        (param as EventRoute).dayMode ? undefined : (): void => { this.eventSegment(param as EventRoute); }, this.eventMenus(param as EventRoute), false, (): void => { this.closeEvent(param as EventRoute); }),
        back: (): void => { this.closeEvent(param as EventRoute); }, content: this.eventContent.bind(this, param as EventRoute) })
    }
  }

  /** 开发者选项入口：设置页连点版本号五次，按需求不振动。 */
  private openDeveloper(): void {
    this.state.suspend();
    this.detailStack.pushPathByName('developer', 'developer');
  }
  private edit(kind: string, id: string = '', parent: string = ''): void {
    HapticService.confirm(this.state.settings.haptic);
    if (!this.state.staleScopes.length) { this.state.error = ''; }
    this.rootSheetKind = 'form';
    this.draft = EditDraft.make(this.state, kind === 'eventProject' ? 'project' : kind, id, parent);
    this.formOpen = true;
  }
  private async remove(kind: string, id: string): Promise<void> {
    const messages = new Map<string, string>([
      ['project', '计划、清单、照片记录与应用内照片副本将删除。系统相册原图保留。'],
      ['character', '角色及其版本将删除。仍有关联计划时无法删除。'],
      ['asset', '衣柜装备与所有计划关联将删除，清单会保留名称。'],
      ['event', '活动将删除，关联计划会保留。'],
      ['photo', '照片记录与本地副本将删除，系统相册原图保留。'],
      ['variant', '角色版本将删除；仍被计划使用时无法删除。'],
      ['checklist', '此清单项将删除。'],
      ['preparation', '此准备任务将删除，打包清单保留。'],
      ['category', '此分类及其准备任务将删除，装备和打包清单保留。'],
      ['team', '此成员的本机分工记录将删除。'],
      ['expense', '此笔花费将删除，并从统计中移除。'],
      ['reference', '此参考图记录与应用内副本将删除。系统相册原图保留。'],
    ]);
    const accepted = await confirm(this.getUIContext(), '确认删除？', messages.get(kind) || '记录将删除。', '删除');
    if (accepted && await this.state.remove(kind, id)) {
      if (kind === 'project' || kind === 'character') {
        this.detailStack.clear();
      } else if (kind === 'event') {
        const route = this.stacks[2].getParamByIndex(this.stacks[2].size() - 1) as EventRoute;
        if (route && route.id === id) { this.closeEvent(route); }
      } else if (!['variant', 'checklist', 'preparation', 'category', 'team', 'expense'].includes(kind)) {
        this.detailStack.pop();
      }
    }
  }
  private async destructive(kind: string): Promise<void> {
    const accepted = await confirm(
      this.getUIContext(),
      kind === 'restore' ? '替换当前元数据？' : '清空本地数据？',
      kind === 'restore'
        ? '建议先导出当前记录。恢复会替换全部角色、计划和衣柜记录；本机未保存的照片需重新导入。'
        : '全部本地记录和照片副本将删除，系统相册原图保留。建议先完成备份。',
      kind === 'restore' ? '选择备份' : '清空'
    );
    if (accepted) {
      const changed = kind === 'restore' ? await this.state.restoreData() : await this.state.clearData();
      if (changed) { this.detailStack.clear(); }
    }
  }

  @Builder rootSheet() {
    if (this.rootSheetKind === 'form') { this.form() } else { this.importSheet() }
  }
  @Builder form() {
    FormEditor({
      entrance: this.sheetEntrance,
      state: this.state, draft: this.draft,
      done: (): void => { this.formOpen = false; },
      saved: (kind: string, id: string, created: boolean): void => { if (kind === 'project' && created) { this.open('project', id); } },
    })
  }

  @Builder detailContent(kind: string, param: Object, entrance: StaggerEntrance) {
    Column() {
      if (kind === 'character') {
        CharacterDetail({
          entrance: entrance,
          state: this.state,
          character: this.state.characters.find((c: Character) => c.id === (param as string)) || new Character(),
          open: (k: string, id: string) => this.open(k, id),
          edit: (k: string, id: string, parent: string) => this.edit(k, id, parent),
          remove: (k: string, id: string) => this.remove(k, id)
        })
      }
      else if (kind === 'project') {
        if ((param as ProjectRoute).section === 2) {
          PhotoGrid({
            entrance: entrance,
            state: this.state,
            topInset: Theme.detailTopWithSegment,
            bottomInset: Theme.contentBottom,
            sidePadding: Theme.pagePadding,
            photos: this.state.photos.filter((p: PhotoAsset) => p.projectId === (param as ProjectRoute).id),
            open: (k: string, id: string) => this.open(k, id)
          })
        }
        else {
          ProjectDetail({
            entrance: entrance,
            state: this.state,
            route: param as ProjectRoute,
            topInset: Theme.detailTopWithSegment,
            project: this.state.projects.find((p: CosProject) => p.id === (param as ProjectRoute).id) || new CosProject(),
            open: (k: string, id: string) => this.open(k, id),
            edit: (k: string, id: string, parent: string) => this.edit(k, id, parent),
            remove: (k: string, id: string) => this.remove(k, id)
          })
        }
      }
      else if (kind === 'reference') {
        ReferenceDetail({
          entrance: entrance,
          state: this.state,
          reference: this.state.references.find((r: ReferenceImage) => r.id === (param as string)) || new ReferenceImage()
        })
      }
      else if (kind === 'expenseStats') {
        ExpenseSummary({
          entrance: entrance,
          state: this.state,
          edit: (k: string, id: string, parent: string): void => this.edit(k, id, parent),
          remove: (k: string, id: string): void => { this.remove(k, id); }
        })
      }
      else if (kind === 'asset') {
        AssetDetail({
          entrance: entrance,
          state: this.state,
          asset: this.state.assets.find((a: Asset) => a.id === (param as string)) || new Asset(),
          open: (k: string, id: string) => this.open(k, id),
          edit: (k: string, id: string, parent: string) => this.edit(k, id, parent),
          remove: (k: string, id: string) => this.remove(k, id)
        })
      }
      else if (kind === 'photo') {
        PhotoDetail({
          entrance: entrance,
          state: this.state,
          photo: this.state.photos.find((p: PhotoAsset) => p.id === (param as string)) || new PhotoAsset(),
          open: (k: string, id: string) => this.open(k, id),
          remove: (k: string, id: string) => this.remove(k, id)
        })
      }
    }.width('100%').height('100%')
  }

  @Builder destinationBody(kind: string, param: Object, entrance: StaggerEntrance) {
    if (kind === 'privacy') {
      LocalHtmlPage({ entrance: entrance })
    } else if (kind === 'settings') {
      SettingsPage({
        open: (kind: string, id: string): void => this.open(kind, id),
        entrance: entrance,
        entranceSession: this.mainEntranceSession,
        state: this.state,
        bottomInset: Theme.contentBottom,
        destructive: (k: string): void => { this.destructive(k); },
        openDeveloper: (): void => { this.openDeveloper(); }
      })
    } else if (kind === 'inbox') {
      InboxPage({ state: this.state, route: param as InboxRoute, backToOwner: (): void => { this.closeDetail(); }, open: (kind: string, id: string): void => { this.open(kind, id); } })
    } else if (kind === 'developer') {
      DevPage({ entrance: entrance, state: this.state })
    } else {
      HdsActionTabs({
        items: this.detailTools(kind, param), effects: this.state.settings.effects,
        materialLevel: this.state.settings.materialLevel, availableWidth: this.viewportWidth,
        busy: this.state.busy, haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        content: (): void => { this.detailContent(kind, param, entrance); },
      })
    }
  }

  @Builder destination(kind: string, param: Object) {
    if (kind === 'appLog') {
      AppLogPage({
        effects: this.state.settings.effects,
        materialLevel: this.state.settings.materialLevel,
        back: (): void => { this.closeDetail(); },
      })
    } else {
      DetailDestination({
        entranceSession: kind === 'settings' ? this.mainEntranceSession : undefined,
        entranceKey: kind === 'settings' ? SETTINGS_ENTRANCE_KEY : '',
        titleOptions: SystemCapability.titleBar(
          kind === 'project' ? '' : kind === 'inbox' ? this.inboxTitle(param as InboxRoute) : this.destinationTitle(kind, param as string),
          this.state.settings.effects,
          this.state.settings.materialLevel,
          kind === 'project' ? (): void => { this.projectSegment(param as ProjectRoute); } : undefined,
          [], false,
          (): void => { this.closeDetail(); },
        ),
        back: (): void => { this.closeDetail(); },
        hidden: (): void => {
          if (kind === 'project') { (param as ProjectRoute).outing = false; }
          this.state.suspend();
        },
        content: this.destinationBody.bind(this, kind, param),
      })
    }
  }

  private inboxTitle(route: InboxRoute): string {
    if (route.scopeKind === 'global') { return '收录箱'; }
    return this.destinationTitle(route.scopeKind, route.scopeId) + ' · 收录';
  }

  private destinationTitle(kind: string, id: string): string {
    if (kind === 'privacy') { return '隐私政策'; }
    if (kind === 'settings') { return '设置'; }
    if (kind === 'developer') { return DEVELOPER_PAGE_TITLE; }
    if (kind === 'reference') { return '准备参考图'; }
    if (kind === 'expenseStats') { return '花费统计'; }
    if (kind === 'inbox') { return '收录箱'; }
    if (kind === 'character') { return this.state.characterName(id); }
    if (kind === 'project') { return this.state.projectName(id); }
    if (kind === 'event') { return this.state.events.find((e: CosEvent) => e.id === id)?.name || '活动'; }
    if (kind === 'asset') { return this.state.assets.find((a: Asset) => a.id === id)?.name || '装备'; }
    return '照片';
  }
  private chooseImport(): void {
    if (this.state.projects.length === 0) { this.edit('project'); this.state.reportNotice('先建立计划，再导入照片。'); }
    else { this.rootSheetKind = 'import'; this.importOpen = true; }
  }
  private async referenceCover(id: string): Promise<void> {
    const r = this.state.references.find((r: ReferenceImage) => r.id === id); if (!r) { return; }
    const characterId = r.characterId || this.state.projects.find((p: CosProject) => p.id === r.projectId)?.characterId || '';
    const character = this.state.characters.find((c: Character) => c.id === characterId);
    if (character?.cover && character.cover !== r.thumbnailPath && !(await confirm(this.getUIContext(), '替换角色封面？', '使用此参考图作为角色封面，原有图片保留。', '替换'))) {
      return;
    }
    await this.state.referenceCover(r);
  }
  private async setCover(photo: PhotoAsset): Promise<void> {
    const project = this.state.projects.find((item: CosProject) => item.id === photo.projectId);
    const character = this.state.characters.find((item: Character) => item.id === project?.characterId);
    if (character?.cover && character.cover !== photo.thumbnailPath) {
      if (!(await confirm(this.getUIContext(), '替换角色封面？', '将使用这张照片作为角色封面。已有照片文件与计划记录都会保留。', '替换'))) { return; }
    }
    await this.state.setCover(photo);
  }

  @Builder importSheet() {
    Column({ space: 16 }) {
      SheetHeader({
        title: '选择照片所属计划', hint: '导入的照片只保存在本机',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.importOpen = false; },
      }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
      List({ space: 10 }) {
        ForEach(this.state.projects, (p: CosProject) => {
          ListItem() {
            Button(p.name)
            .accessibilityText('选择照片所属计划 ' + p.name)
            .width('100%')
            .constraintSize({ minHeight: 56 })
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .onClick(() => { HapticService.confirm(this.state.settings.haptic); this.importOpen = false; this.state.importPhotos(p.id); })
            .visualEffect(this.feedback.effect('import-project:' + p.id, true))
            .compositingFilter(this.feedback.filter('import-project:' + p.id, true))
            .attributeModifier(this.feedback.control('import-project:' + p.id, true))
          }
        }, (p: CosProject) => p.id)
      }.layoutWeight(1).width('100%').opacity(this.sheetEntrance.step >= 2 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
    }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface)
  }

  private rootTools(index: number): ToolbarItem[] {
    if (index === 1) {
      return [{ value: this.cosProjects ? '新建计划' : '添加角色', icon: Icons.add, action: () => this.edit(this.cosProjects ? 'project' : 'character') }];
    }
    if (index === 2) { return [{ value: '添加活动', icon: Icons.add, action: () => this.edit('event') }]; }
    if (index === 3) {
      return [{
        value: this.libraryPhotos ? '导入照片' : '添加装备', icon: this.libraryPhotos ? Icons.importPhoto : Icons.add, action: () => {
          if (this.libraryPhotos) {
            this.chooseImport();
          } else {
            this.edit('asset');
          }
        }
      }];
    }
    return [{ value: '新建计划', icon: Icons.add, action: () => this.edit('project') }, { value: '添加活动', icon: Icons.event, action: () => this.edit('event') }, { value: '导入照片', icon: Icons.importPhoto, action: () => this.chooseImport() }];
  }
  private rootMenus(index: number): HdsNavigationMenuItemOptions[] {
    if (index === 4) {
      return [{
        content: {
          label: '设置', componentId: 'root-action-设置', icon: Icons.settings, isEnabled: this.state.ready && !this.state.busy, action: (): void => {
            this.open('settings', 'settings');
          }
        }
      }];
    }
    return this.rootTools(index).map((item: ToolbarItem): HdsNavigationMenuItemOptions => {
      return { content: { label: item.value, icon: item.icon as Resource, isEnabled: this.state.ready && !this.state.busy, action: item.action, componentId: 'root-action-' + item.value } };
    });
  }

  @Builder projectSegment(route: ProjectRoute) {
    Column() {
      HdsTitleBarSegment({
        componentId: 'project-task-segment',
        items: this.buildSegmentItems(['准备', '打包', '照片']),
        selectedIndexes: [route.section],
        experimentalWidth: Theme.titleSegmentWidth,
        onSelectedIndexChanged: (selected: number): void => { route.section = selected; route.outing = false; this.state.suspend(); },
        onItemClicked: (): void => { HapticService.confirm(this.state.settings.haptic); },
      }).margin({ top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  private detailTools(kind: string, param: Object): ToolbarItem[] {
    const id = kind === 'project' ? (param as ProjectRoute).id : param as string;
    if (kind === 'settings') { return []; }
    if (kind === 'developer') { return []; }
    if (kind === 'expenseStats') { return [{ value: '记一笔', icon: Icons.add, action: () => this.edit('expense') }]; }
    if (kind === 'reference') {
      return [
        { value: '设为封面', symbolIcon: Icons.toolbarCover(), action: () => this.referenceCover(id) },
        { value: '编辑说明', icon: Icons.edit, action: () => this.edit('reference', id) },
        { value: '删除', icon: Icons.remove, action: () => this.remove('reference', id) }
      ];
    }
    if (kind === 'project') {
      const route = param as ProjectRoute;
      if (route.section === 2) { return [{ value: '导入照片', icon: Icons.importPhoto, action: () => this.state.importPhotos(id) }]; }
      if (route.section === 1) {
        return [{ value: '添加物品', icon: Icons.add, action: () => this.edit('checklist', '', id) },
        { value: '常用物品', icon: Icons.check, action: () => this.state.generateChecklist(id) },
        {
          value: route.outing ? '结束出门' : '出门模式', icon: Icons.check, action: () => {
            route.outing = !route.outing;
            if (route.outing) {
              this.state.resume();
            } else {
              this.state.suspend();
            }
          }
        }];
      }
      return [{ value: '准备任务', icon: Icons.add, action: () => { route.sheetKind = 0; route.preparing = true; } },
      { value: '从衣柜', icon: Icons.library, action: () => { route.sheetKind = 1; route.linking = true; } },
      { value: '编辑', icon: Icons.edit, action: () => this.edit('project', id) },
      { value: '分享', icon: Icons.share, action: () => this.state.shareProject(id) },
      { value: '删除计划', icon: Icons.remove, action: () => this.remove('project', id) }];
    }
    if (kind === 'character') {
      return [{ value: '新建计划', symbolIcon: Icons.toolbarAdd(), action: () => this.edit('project', '', id) }, { value: '添加版本', symbolIcon: Icons.toolbarAdd(), action: () => this.edit('variant', '', id) }, { value: '编辑角色', icon: Icons.edit, action: () => this.edit('character', id) }, { value: '删除角色', icon: Icons.remove, action: () => this.remove('character', id) }];
    }
    if (kind === 'asset') {
      return [{ value: '编辑', icon: Icons.edit, action: () => this.edit(kind, id) }, { value: '删除', icon: Icons.remove, action: () => this.remove(kind, id) }];
    }
    return [{
      value: '选中照片', icon: Icons.check, action: () => {
        const photo = this.state.photos.find((p: PhotoAsset) => p.id === id);
        if (photo) {
          this.state.setPhotoStatus(photo, PhotoStatus.SELECTED);
        }
      }
    }, {
      value: '设为封面', symbolIcon: Icons.toolbarCover(), action: () => {
        const photo = this.state.photos.find((p: PhotoAsset) => p.id === id);
        if (photo) {
          this.setCover(photo);
        }
      }
    }, { value: '删除', icon: Icons.remove, action: () => this.remove('photo', id) }];
  }

  private segmentLabels(index: number): string[] {
    if (index === 1) { return ['角色', '计划']; }
    if (index === 2) { return ['列表', '日历']; }
    if (index === 3) { return ['装备', '照片']; }
    return ['作品', '时间轴'];
  }

  private segmentSelection(index: number): number {
    if (index === 1) { return this.cosProjects ? 1 : 0; }
    if (index === 2) { return this.eventCalendar ? 1 : 0; }
    if (index === 3) { return this.libraryPhotos ? 1 : 0; }
    return this.meSection;
  }

  private buildSegmentItems(labels: string[]): SegmentButtonV2Items {
    const options: SegmentButtonV2ItemOptions[] = [];
    for (let position = 0; position < labels.length; position++) {
      const label = labels[position];
      const spoken = label === '即将' ? '即将参加' : label === '过去' ? '已过去' : label;
      options.push({ text: label, accessibilityText: spoken });
    }
    return new SegmentButtonV2Items(options);
  }

  @Builder titleSegment(index: number) {
    Column() {
      HdsTitleBarSegment({
        componentId: 'secondary-segment-' + index,
        items: this.buildSegmentItems(this.segmentLabels(index)),
        selectedIndexes: [this.segmentSelection(index)],
        experimentalWidth: Theme.titleSegmentWidth,
        onSelectedIndexChanged: (selected: number): void => {
          if (index === 1) { this.cosProjects = selected === 1; }
          else if (index === 2) { this.eventCalendar = selected === 1; }
          else if (index === 3) { this.libraryPhotos = selected === 1; }
          else { this.meSection = selected; }
        },
        onItemClicked: (_selected: number): void => { HapticService.confirm(this.state.settings.haptic); },
      }).align(Alignment.Center).margin({ top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Monitor('state.error', 'state.notice', 'state.feedbackVersion')
  private feedbackChanged(): void {
    const message = this.state.error || this.state.notice;
    if (message) { showToastSafely(this.getUIContext().getPromptAction(), message, 2000, 'Application'); }
  }
  @Builder recoveryBanner() {
    if (this.state.staleScopes.length > 0) {
      Row({ space: 12 }) {
        Text('记录已保存，显示尚未更新。无需重复提交。').fontSize(14).fontColor(Theme.ink).layoutWeight(1)
        Button(this.state.busy ? '加载中…' : '重新加载')
          .enabled(!this.state.busy).fontColor(Theme.onAccent).backgroundColor(Theme.brand)
          .onClick((): void => { this.state.reloadRecords(); })
          .accessibilityText('重新加载已保存的记录')
      }.id('saved-refresh-recovery').width('100%').padding(16).backgroundColor(Theme.surface)
        .margin({ bottom: Theme.contentBottom }).align(Alignment.Bottom).accessibilityGroup(true)
    }
  }

  @Builder loadingOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.state.busy) {
        LoadingProgress().width(40).height(40).color(Theme.brand).hitTestBehavior(HitTestMode.None).accessibilityText('操作进行中')
      }
      this.recoveryBanner()
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder mainNavigation(index: number) {
    HdsNavigation(this.stacks[index]) {
      Column() {
        if (!this.state.ready) {
          if (!this.state.busy && this.state.error) {
            EmptyState({
              title: '暂时无法打开记录',
              message: '请重试加载本地数据。',
              button: '重试',
              action: (): void => { this.state.start(this.getUIContext().getHostContext() as common.UIAbilityContext); }
            }).margin({ top: Theme.contentTop, left: Theme.pagePadding, right: Theme.pagePadding })
          }
        }
        else if (index === 0) {
          HomePage({
            entranceSession: this.mainEntranceSession,
            scroller: this.pageScrollers[index],
            state: this.state,
            topInset: Theme.contentTop,
            bottomInset: Theme.homeContentBottom,
            active: this.tab === index,
            open: (k: string, id: string) => this.open(k, id),
            add: (k: string, parent: string) => this.edit(k, '', parent)
          })
        }
        else if (index === 1) {
          CosPage({
            entranceSession: this.mainEntranceSession,
            scroller: this.pageScrollers[index],
            state: this.state,
            topInset: Theme.contentTop,
            bottomInset: Theme.contentBottom,
            active: this.tab === index,
            projects: this.cosProjects,
            selection: (projects: boolean) => { this.cosProjects = projects; },
            open: (k: string, id: string) => this.open(k, id),
            add: (k: string, parent: string) => this.edit(k, '', parent)
          })
        }
        else if (index === 2) {
          EventsPage({
            entranceSession: this.mainEntranceSession,
            scroller: this.pageScrollers[index],
            state: this.state,
            topInset: Theme.contentTop,
            bottomInset: Theme.contentBottom,
            active: this.tab === index,
            calendar: this.eventCalendar,
            filter: this.eventFilter,
            filterChanged: (filter: number): void => { this.eventFilter = filter; },
            open: (k: string, id: string) => this.open(k, id),
            add: (k: string, parent: string) => this.edit(k, '', parent)
          })
        }
        else if (index === 3) {
          LibraryPage({
            entranceSession: this.mainEntranceSession,
            scroller: this.pageScrollers[index],
            state: this.state,
            topInset: Theme.contentTop,
            bottomInset: Theme.contentBottom,
            active: this.tab === index,
            photos: this.libraryPhotos,
            selection: (photos: boolean) => { this.libraryPhotos = photos; },
            open: (k: string, id: string) => this.open(k, id),
            add: (k: string, parent: string) => this.edit(k, '', parent)
          })
        }
        else {
          MePage({
            entranceSession: this.mainEntranceSession,
            scroller: this.pageScrollers[index],
            state: this.state,
            topInset: Theme.contentTop,
            bottomInset: Theme.contentBottom,
            active: this.tab === index,
            section: this.meSection,
            open: (k: string, id: string) => this.open(k, id),
            destructive: (kind: string) => this.destructive(kind)
          })
        }
      }.width('100%').height('100%')
    }.mode(NavigationMode.Stack)
      .navDestination(this.scheduleDestination)
      .customNavContentTransition((_from: NavContentInfo, _to: NavContentInfo, operation: NavigationOperation) => {
        if (operation === NavigationOperation.POP) { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); }
        return undefined;
      })
      .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
      // 外层 HdsTabs 已忽略安全区，内层 HdsNavigation 需要显式避让，标题才不会进入状态栏。
      .titleBar(SystemCapability.titleBar(
        MAIN_PAGE_TITLES[index], this.state.settings.effects, this.state.settings.materialLevel,
        index > 0 ? (): void => { this.titleSegment(index); } : undefined,
        this.rootMenus(index), true,
      ))
      .hideToolBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%').height('100%').backgroundColor(Theme.bg)
  }

  @Builder mainTabs() {
    HdsTabs({ controller: this.tabsController, index: this.tab }) {
      TabContent() { this.mainNavigation(0) }
        .tabBar(new BottomTabBarStyle(Icons.home, '首页')).accessibilityText('首页标签页')
      TabContent() { this.mainNavigation(1) }
        .tabBar(new BottomTabBarStyle(Icons.cos, 'Cos')).accessibilityText('角色和计划标签页')
      TabContent() { this.mainNavigation(2) }
        .tabBar(new BottomTabBarStyle(Icons.event, '活动')).accessibilityText('活动标签页')
      TabContent() { this.mainNavigation(3) }
        .tabBar(new BottomTabBarStyle(Icons.library, '衣柜')).accessibilityText('衣柜标签页')
      TabContent() { this.mainNavigation(4) }
        .tabBar(new BottomTabBarStyle(Icons.me, '我的')).accessibilityText('我的标签页')
    }.id('main-tabs')
      .barPosition(BarPosition.End)
      .barWidth(Math.min(Theme.mainTabsWidth, Math.max(0, this.viewportWidth - 32)))
      .cachedMaxCount(5, TabsCacheMode.CACHE_LATEST_SWITCHED)
      .scrollable(false).vertical(false).barOverlap(true)
      .blurStrategy(this.state.settings.effects ? BlurStrategy.ENABLE : BlurStrategy.DISABLE)
      .barFloatingStyle(SystemCapability.tabs(this.state.settings.effects, this.state.settings.materialLevel))
      .onTabBarClick((index: number): void => {
        if (index === this.tab && this.stacks[index].size() === 0) {
          HapticService.confirm(this.state.settings.haptic);
          try {
            this.pageScrollers[index].scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } });
          } catch (error) {
            console.warn('Page scroll-to-top failed: ' + String(error));
          }
        }
      })
      .onChange((index: number): void => {
        this.tab = index;
        this.state.suspend();
        HapticService.confirm(this.state.settings.haptic, this.state.settings.hapticLevel);
      })
      .layoutWeight(1).width('100%')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Theme.bg)
      .accessibilityText('首页、角色和计划、活动、衣柜、我的五个标签页')
      .onAreaChange((_, area: Area): void => { this.viewportWidth = Number(area.width); })
  }

  @Builder dayEntryBar() {
    if (this.state.ready && this.state.todayEvents.length > 0) {
      Row({ space: 8 }) {
        Button(dayTitle(this.state.todayEvents[0], this.state.clockTime) + (this.state.todayEvents.length > 1 ? ' · 还有 ' + (this.state.todayEvents.length - 1) + ' 个' : ''))
          .layoutWeight(1).constraintSize({ minHeight: 64 }).fontSize(17).fontColor(Theme.accent).backgroundColor(Theme.tint)
          .onClick((): void => { this.open('dayEvent', this.state.todayEvents[0]?.id || ''); }).id('day-entry-bar')
        Button('关闭').constraintSize({ minHeight: 64, minWidth: 64 }).fontColor(Theme.muted).backgroundColor(Theme.surface).enabled(!this.state.settingsBusy)
          .onClick((): void => { const id = this.state.todayEvents[0]?.id; if (id) { this.state.dismissDayEntry(id); } }).accessibilityText('今天不再显示这场活动的入口')
      }.padding({ left: 16, right: 16, bottom: 28 }).width('100%').backgroundColor(Theme.bg)
    }
  }

  build() {
    WithTheme({ theme: Theme.nativeTheme }) {
    HdsNavigation(this.detailStack) {
      Column() {
        this.mainTabs()
        this.dayEntryBar()
      }.width('100%').height('100%')
    }.mode(NavigationMode.Stack).hideTitleBar(true).hideToolBar(true)
      .navDestination(this.destination)
      .customNavContentTransition((_from: NavContentInfo, _to: NavContentInfo, operation: NavigationOperation) => {
        if (operation === NavigationOperation.POP) { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); }
        return undefined;
      })
      .width('100%').height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Theme.bg).overlay(this.loadingOverlay, { align: Alignment.Center })
      .bindSheet(this.importOpen || this.formOpen, this.rootSheet(), appSheetOptions((): void => {
        this.importOpen = false;
        this.formOpen = false;
      }, this.sheetEntrance, this.getUIContext()))
    }
  }
}
