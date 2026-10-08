import { SearchPage } from './more/SearchPage';
import { SearchRoute, SearchHit, globalSearch, searchRows, SEARCH_SECTIONS } from '../model/GlobalSearch';
import { ProjectPhotoHeader } from '../component/ProjectPhotoHeader';
import { CharacterRoute } from '../model/CharacterRoute';
import { AssetRoute } from '../model/AssetRoute';
import { WardrobeRoute, assetUsesSegments } from '../model/Wardrobe';
import { AlbumRoute } from '../model/AlbumRoute';
import { PhotoCollectionRoute, PhotoViewerRoute, returnToPhotoCollection } from '../model/PhotoCollection';
import { AlbumPage } from './main/AlbumPage';
import { BackupRestoreSheet } from '../component/BackupRestoreSheet';
import { EventRoute, EventReturnPath } from '../model/EventRoute';
import { TaskRoute, TaskQueueItem } from '../model/TaskQueue';
import { LedgerRoute } from '../model/LedgerRoute';
import { ScheduleRoute } from '../model/ScheduleRoute';
import { today } from '../common/format';
import { PlanListRoute } from '../model/PlanListRoute';
import { TasksPage } from './more/TasksPage';
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
  HdsSnackBar, SnackBarOperationType,
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
import { LengthMetrics, SegmentButtonV2Items, SegmentButtonV2ItemOptions } from '@kit.ArkUI';
import { HdsTitleBarSegment } from '../component/HdsTitleBarSegment';
import { HdsViewTabs } from '../component/HdsViewTabs';
import { HapticService } from '../common/HapticService';
import { ProjectRoute } from '../model/ProjectRoute';
import { EditDraft } from '../model/EditDraft';
import { Character, CosProject, Asset, CosEvent, PhotoAsset, PhotoStatus, ProjectStatus } from '../model/Entities';
import { SystemCapability } from '../common/SystemCapability';
import { HomePage } from './main/HomePage';
import { CosPage } from './main/CosPage';
import { EventsPage } from './main/EventsPage';
import { LibraryPage } from './main/LibraryPage';
import { SettingsPage } from './more/SettingsPage';
import { CharacterDetail } from './detail/CharacterDetailPage';
import { ProjectDetail } from './detail/ProjectDetailPage';
import { AssetDetail } from './detail/AssetDetailPage';
import { EventDetail } from './detail/EventDetailPage';
import { PhotoDetail } from './detail/PhotoDetailPage';
import { PhotoGrid } from '../component/PhotoGrid';
import { FormSession } from '../model/FormSession';
import { formDraftStore } from '../common/formDrafts';
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
  @Local planListRoute: PlanListRoute = new PlanListRoute();
  @Local wardrobeRoute: WardrobeRoute = new WardrobeRoute();
  @Local scheduleRoute: ScheduleRoute = new ScheduleRoute(today());
  @Local albumRoute: AlbumRoute = new AlbumRoute();
  @Local rootSheetKind: string = 'form';
  @Local creatingForImport: boolean = false;
  @Local pendingImportPlanId: string = '';
  @Local importOpen: boolean = false;
  @Local formOpen: boolean = false;
  @Local restoreOpen: boolean = false;
  @Local formSession: FormSession = new FormSession(new EditDraft(), formDraftStore);
  private editingShotRoute?: ProjectRoute;
  private checkingFormClose: boolean = false;
  @Local viewportWidth: number = 360;
  private daySnackBar?: HdsSnackBar;
  private daySnackKey: string = '';
  private rootVisible: boolean = true;
  private closingDaySnack: boolean = false;
  @Local daySnackReservation: number = 0;
  private clockTimer: number = -1;
  private startupTimer: number = -1;
  private maintenanceTimer: number = -1;
  private visible: boolean = false;
  private maintenanceDone: boolean = false;

  onPageShow(): void {
    this.visible = true;
    this.state.tickClock(); this.syncDaySnack();
    if (this.clockTimer < 0) { this.clockTimer = setInterval((): void => { this.state.tickClock(); this.syncDaySnack(); }, 1000); }
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
    this.visible = false; this.hideDaySnack();
    if (this.clockTimer >= 0) { clearInterval(this.clockTimer); this.clockTimer = -1; }
    if (this.startupTimer >= 0) { clearTimeout(this.startupTimer); this.startupTimer = -1; }
    if (this.maintenanceTimer >= 0) { clearTimeout(this.maintenanceTimer); this.maintenanceTimer = -1; }
    if (this.formOpen) { void this.formSession.flush(); }
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
    if (this.detailStack.size() > 0) {
      const index = this.detailStack.size() - 1;
      if (this.detailStack.getAllPathName()[index] === 'character') { (this.detailStack.getParamByIndex(index) as CharacterRoute).restoreSource(); }
      if (this.detailStack.getAllPathName()[index] === 'asset') { const route = this.detailStack.getParamByIndex(index) as AssetRoute; route.restoreSource(); this.tab = route.sourceTab; this.tabsController.changeIndex(route.sourceTab); }
      if (this.detailStack.getAllPathName()[index] === 'photo') { returnToPhotoCollection(this.detailStack.getParamByIndex(index) as PhotoViewerRoute, this.state.photos); }
      this.detailStack.pop();
    }
  }
  private open(kind: string, id: string): void {
    if (!id) { return; }
    HapticService.confirm(this.state.settings.haptic);
    this.state.suspend();
    if (kind === 'search') { this.detailStack.pushPathByName('search', new SearchRoute()); return; }
    if (kind === 'asset') { this.openAsset(id); return; }
    if (kind === 'character') {
      const top = this.detailStack.size() - 1;
      const project = top >= 0 && this.detailStack.getAllPathName()[top] === 'project' ? this.state.projects.find((item: CosProject) => item.id === (this.detailStack.getParamByIndex(top) as ProjectRoute).id) : undefined;
      const route = new CharacterRoute(id, project?.characterId === id ? project.variantId : '');
      if (project) { route.project = this.detailStack.getParamByIndex(top) as ProjectRoute; }
      if (top >= 0 && this.detailStack.getAllPathName()[top] === 'characters') { route.library = this.detailStack.getParamByIndex(top) as PlanListRoute; route.library.anchorId = id; }
      this.detailStack.pushPathByName('character', route); return;
    }
    if (kind === 'event' || kind === 'dayEvent') { this.openEvent(id, kind === 'dayEvent'); return; }
    if (kind === 'album' || kind === 'albumQueue') { this.detailStack.pushPathByName('album', new AlbumRoute(id === 'all' ? '' : id, kind === 'albumQueue')); return; }
    if (kind === 'photo') { this.openPhoto(new PhotoViewerRoute(id, 'collection', new PhotoCollectionRoute(), this.state.photos)); return; }
    if (kind === 'characters') { this.detailStack.pushPathByName('characters', new PlanListRoute()); return; }
    if (kind === 'tasks') { this.detailStack.pushPathByName('tasks', new TaskRoute(id === 'all' ? '' : id)); return; }
    if (kind === 'expenseStats') {
      const route = new LedgerRoute(id === 'all' ? '' : id); if (route.projectId) { route.range = 'all'; }
      this.detailStack.pushPathByName('expenseStats', route); return;
    }
    if (kind === 'inbox' && id.startsWith('project|')) {
      const projectId = id.slice(8); const current = this.detailStack.size() > 0 ? this.detailStack.getParamByIndex(this.detailStack.size() - 1) as ProjectRoute : undefined;
      if (current && current.id === projectId && this.detailStack.getAllPathName()[this.detailStack.size() - 1] === 'project') { current.contextSheet = 'entries'; }
      else { const route = new ProjectRoute(projectId); route.contextSheet = 'entries'; this.detailStack.pushPathByName('project', route); }
      return;
    }
    if (kind === 'inbox' && id.startsWith('character|')) {
      const characterId = id.slice(10); const top = this.detailStack.size() - 1;
      if (top >= 0 && this.detailStack.getAllPathName()[top] === 'character' && (this.detailStack.getParamByIndex(top) as CharacterRoute).id === characterId) { (this.detailStack.getParamByIndex(top) as CharacterRoute).entriesOpen = true; }
      else { const route = new CharacterRoute(characterId); route.entriesOpen = true; this.detailStack.pushPathByName('character', route); }
      return;
    }
    if (kind === 'inbox' && id.startsWith('event|')) { this.openEvent(id.slice(6), false, 2); return; }
    if (kind === 'inbox') {
      const parts = id.split('|');
      if (parts[0] === 'asset') {
        const top = this.detailStack.size() - 1;
        if (top < 0 || this.detailStack.getAllPathName()[top] !== 'asset' || (this.detailStack.getParamByIndex(top) as AssetRoute).id !== parts[1]) {
          this.detailStack.pushPathByName('asset', new AssetRoute(parts[1], 'collection', '', this.tab), false);
        }
        const owner = this.detailStack.getParamByIndex(this.detailStack.size() - 1) as AssetRoute;
        this.detailStack.pushPathByName('inbox', owner.entries); return;
      }
      this.detailStack.pushPathByName('inbox', new InboxRoute(parts[0] || 'global', parts[1] || ''));
    } else if (kind === 'project' || kind === 'packing' || kind === 'projectPhotos' || kind === 'outing' || kind === 'projectPreparation') {
      const section = kind === 'packing' || kind === 'outing' ? 2 : kind === 'projectPhotos' ? 3 : kind === 'projectPreparation' ? 1 : 0;
      const route = new ProjectRoute(id, section); route.outing = kind === 'outing';
      this.detailStack.pushPathByName('project', route);
    } else {
      this.detailStack.pushPathByName(kind, id);
    }
  }

  private openSearchResult(route: SearchRoute, hit: SearchHit): void {
    const results = searchRows(globalSearch(this.state, route.query), route);
    const current = results.find((result: SearchHit) => result.key() === hit.key());
    if (!current) { route.feedback = '结果已更新，请查看当前匹配项。'; route.restoreVersion++; return; }
    route.anchorKey = current.key();
    if (current.kind === 'photo') {
      const viewer = new PhotoViewerRoute(current.id, 'search', new PhotoCollectionRoute(), this.state.photos);
      viewer.visibleIds = results.filter((result: SearchHit) => result.kind === 'photo').map((result: SearchHit) => result.id);
      this.openPhoto(viewer); return;
    }
    if (current.kind === 'character') {
      this.state.suspend(); this.detailStack.pushPathByName('character', new CharacterRoute(current.id, current.variantId)); return;
    }
    if (current.kind === 'entry') {
      if (current.ownerKind === 'global') {
        const inbox = new InboxRoute(); inbox.kind = current.entryKind; this.detailStack.pushPathByName('inbox', inbox);
      } else {
        if (current.ownerKind === 'asset') {
          this.state.suspend(); this.detailStack.pushPathByName('asset', new AssetRoute(current.ownerId, 'collection', '', this.tab), false);
        }
        this.open('inbox', current.ownerKind + '|' + current.ownerId);
      }
      return;
    }
    this.open(current.kind, current.id);
  }
  private openAsset(id: string, from: string = '', projectId: string = ''): void {
    const top = this.detailStack.size() - 1;
    const name = top >= 0 ? this.detailStack.getAllPathName()[top] : '';
    const project = name === 'project' ? this.detailStack.getParamByIndex(top) as ProjectRoute : undefined;
    const event = this.tab === 2 && this.stacks[2].size() > 0 ? this.stacks[2].getParamByIndex(this.stacks[2].size() - 1) as EventRoute : undefined;
    const origin = from || (project ? 'project' : !name && event?.dayMode ? 'day' : !name && this.tab === 3 ? 'wardrobe' : name === 'tasks' ? 'tasks' : !name && this.tab === 0 ? 'home' : 'collection');
    const route = new AssetRoute(id, origin, projectId || project?.id || '', this.tab);
    if (project) { route.project = project; }
    if (name === 'tasks') { route.tasks = this.detailStack.getParamByIndex(top) as TaskRoute; }
    if (origin === 'day' && event) { route.event = event; }
    if (origin === 'wardrobe') { route.wardrobe = this.wardrobeRoute; route.wardrobe.anchorId = id; }
    this.state.suspend(); this.detailStack.pushPathByName('asset', route);
  }
  private openPhoto(route: PhotoViewerRoute): void { this.state.suspend(); this.detailStack.pushPathByName('photo', route); }
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
  private openShot(projectId: string, shotId: string): void {
    const route = new ProjectRoute(projectId, 3); route.focusShotId = shotId; route.shotsOpen = true;
    this.detailStack.pushPathByName('project', route);
  }
  private openTaskItem(item: TaskQueueItem): void {
    if (item.source === 'asset') { this.openAsset(item.focusId, '', item.projectId); return; }
    const route = new ProjectRoute(item.projectId, item.section); route.photos.filter = item.photoFilter;
    if (item.source === 'preparation') { route.focusTaskId = item.focusId; }
    if (item.source === 'packing') { route.focusPackingId = item.focusId; }
    this.detailStack.pushPathByName('project', route);
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
  @Builder eventContent(route: EventRoute, entrance: StaggerEntrance) {
    if (this.state.events.some((event: CosEvent) => event.id === route.id)) {
      EventDetail({ state: this.state, event: this.state.events.find((event: CosEvent) => event.id === route.id) as CosEvent, route: route, entrance: entrance,
        open: (kind: string, id: string): void => { this.open(kind, id); }, openAsset: (id: string, projectId: string): void => { this.openAsset(id, 'day', projectId); },
        openShot: (projectId: string, shotId: string): void => { this.openShot(projectId, shotId); },
        edit: (kind: string, id: string, parent: string): void => { this.edit(kind, id, parent); }, back: (): void => { this.closeEvent(route); } })
    } else {
      EmptyState({ title: '活动已不存在', message: '关联计划仍保留，可以返回继续查看。', button: '返回', action: (): void => { this.closeEvent(route); } }).margin({ top: Theme.detailTop, left: Theme.pagePadding, right: Theme.pagePadding })
    }
  }
  @Builder scheduleDestination(kind: string, param: Object) {
    if (kind === 'event') {
      DetailDestination({ customTitle: (param as EventRoute).dayMode, titleOptions: SystemCapability.titleBar((param as EventRoute).dayMode ? '今天模式' : this.destinationTitle('event', (param as EventRoute).id), this.state.settings.effects, this.state.settings.materialLevel,
        undefined, this.eventMenus(param as EventRoute), false, (): void => { this.closeEvent(param as EventRoute); }),
        back: (): void => { this.closeEvent(param as EventRoute); }, shown: (): void => { (param as EventRoute).restoreVersion++; }, content: this.eventContent.bind(this, param as EventRoute) })
    }
  }

  /** 开发者选项入口：设置页连点版本号五次，按需求不振动。 */
  private openDeveloper(): void {
    this.state.suspend();
    this.detailStack.pushPathByName('developer', 'developer');
  }
  private edit(kind: string, id: string = '', parent: string = '', variant: string = ''): void {
    HapticService.confirm(this.state.settings.haptic);
    if (!this.state.staleScopes.length) { this.state.error = ''; }
    this.creatingForImport = false; this.pendingImportPlanId = '';
    this.rootSheetKind = 'form';
    this.formSession = new FormSession(EditDraft.make(this.state, kind === 'eventProject' ? 'project' : kind, id, parent, variant), formDraftStore);
    void this.formSession.initialize(this.state);
    this.formOpen = true;
  }
  private async remove(kind: string, id: string): Promise<void> {
    if (this.state.busy || this.state.staleScopes.length) { return; }
    const usage = this.state.assetUsage(id);
    const impact = this.state.removalImpact(kind, id);
    if (kind !== 'asset' && !impact) { this.state.reportError('记录已不存在，请返回后重新查看'); return; }
    const accepted = await confirm(this.getUIContext(), kind === 'asset' ? '删除装备？' : impact!.title, kind === 'asset' ? usage.removalMessage(this.state.assets.find((asset: Asset) => asset.id === id)?.name || '已失效装备') : impact!.detail, '删除');
    if (accepted && await (kind === 'asset' ? this.state.removeAsset(id, usage.removalKey) : this.state.remove(kind, id))) {
      if (kind === 'project' || kind === 'character' || kind === 'asset') {
        this.pruneInvalidDetails(kind, id);
      } else if (kind === 'event') {
        const route = this.stacks[2].getParamByIndex(this.stacks[2].size() - 1) as EventRoute;
        if (route && route.id === id) { this.closeEvent(route); }
      } else if (!['variant', 'checklist', 'preparation', 'category', 'team', 'expense'].includes(kind)) {
        this.detailStack.pop();
      }
    }
  }
  private validDetailPath(name: string, param: Object, deletedKind: string = '', deletedId: string = ''): boolean {
    if (name === deletedKind && (name === 'project' ? (param as ProjectRoute).id : name === 'photo' ? (param as PhotoViewerRoute).id : name === 'asset' ? (param as AssetRoute).id : name === 'character' ? (param as CharacterRoute).id : param as string) === deletedId) { return false; }
    if (name === 'project') { return this.state.projects.some((project: CosProject) => project.id === (param as ProjectRoute).id); }
    if (name === 'asset') { return this.state.assets.some((asset: Asset) => asset.id === (param as AssetRoute).id); }
    if (name === 'character') { return this.state.characters.some((character: Character) => character.id === (param as CharacterRoute).id); }
    if (name === 'inbox') {
      const route = param as InboxRoute;
      if (route.scopeKind === deletedKind && route.scopeId === deletedId) { return false; }
      return this.inboxOwnerExists(route);
    }
    if (name === 'photo') { return this.state.photos.some((photo: PhotoAsset) => photo.id === (param as PhotoViewerRoute).id && !(deletedKind === 'project' && photo.projectId === deletedId)); }
    if (name === 'album') {
      (param as AlbumRoute).reconcile(this.state.projects, this.state.photos, deletedKind === 'project' ? deletedId : '');
    }
    if (name === 'reference') { return this.state.references.some((reference: ReferenceImage) => reference.id === (param as string) && !(deletedKind === 'project' && reference.projectId === deletedId) && !(deletedKind === 'character' && reference.characterId === deletedId)); }
    if (name === 'tasks' && (param as TaskRoute).projectId && (deletedKind === 'project' && (param as TaskRoute).projectId === deletedId || !this.state.projects.some((project: CosProject) => project.id === (param as TaskRoute).projectId))) { (param as TaskRoute).projectId = ''; }
    if (name === 'expenseStats' && (param as LedgerRoute).projectId && (deletedKind === 'project' && (param as LedgerRoute).projectId === deletedId || !this.state.projects.some((project: CosProject) => project.id === (param as LedgerRoute).projectId))) { (param as LedgerRoute).projectId = ''; }
    return true;
  }
  private inboxOwnerExists(route: InboxRoute): boolean {
    if (route.scopeKind === 'global') { return true; }
    if (route.scopeKind === 'project') { return this.state.projects.some((project: CosProject) => project.id === route.scopeId); }
    if (route.scopeKind === 'character') { return this.state.characters.some((character: Character) => character.id === route.scopeId); }
    if (route.scopeKind === 'event') { return this.state.events.some((event: CosEvent) => event.id === route.scopeId); }
    return route.scopeKind === 'asset' && this.state.assets.some((asset: Asset) => asset.id === route.scopeId);
  }
  private pruneInvalidDetails(deletedKind: string, deletedId: string): void {
    const indexes: number[] = [];
    this.detailStack.getAllPathName().forEach((name: string, index: number): void => {
      const param = this.detailStack.getParamByIndex(index) as Object;
      if (!this.validDetailPath(name, param, deletedKind, deletedId)) {
        if (name === 'character') { (param as CharacterRoute).restoreSource(true); }
        if (name === 'asset') { (param as AssetRoute).restoreSource(true); }
        if (name === 'photo') { (param as PhotoViewerRoute).context.feedback = '照片记录已不存在，已保留原范围与附近位置'; (param as PhotoViewerRoute).context.restoreVersion++; }
        indexes.push(index);
      }
    });
    if (indexes.length) { this.detailStack.removeByIndexes(indexes); }
    for (let index = 0; index < this.stacks[2].size(); index++) {
      const route = this.stacks[2].getParamByIndex(index) as EventRoute;
      route.returnPaths = route.returnPaths.filter((path: EventReturnPath) => this.validDetailPath(path.name, path.param, deletedKind, deletedId));
    }
  }

  private async destructive(kind: string): Promise<void> {
    if (kind === 'restore') {
      if (await this.state.prepareRestoreData()) { this.rootSheetKind = 'restore'; this.restoreOpen = true; }
      return;
    }
    const accepted = await confirm(this.getUIContext(), '清空本地数据？', '全部本地记录和照片副本将删除，系统相册原图保留。建议先完成备份。', '清空');
    if (accepted && await this.state.clearData()) { this.resetNavigation(); }
  }
  private resetNavigation(): void {
    this.detailStack.clear(); this.stacks.forEach((stack: NavPathStack): void => { stack.clear(); });
    this.planListRoute = new PlanListRoute(); this.wardrobeRoute = new WardrobeRoute(); this.scheduleRoute = new ScheduleRoute(today()); this.albumRoute = new AlbumRoute();
    this.editingShotRoute = undefined; this.pendingImportPlanId = ''; this.creatingForImport = false;
    this.tab = 0; this.tabsController.changeIndex(0);
  }
  private closeRestore(): void {
    if (this.state.busy) { return; }
    this.restoreOpen = false; this.state.cancelRestoreData();
  }
  private async allowFormClose(): Promise<boolean> {
    if (this.state.busy || this.formSession.submitting || this.checkingFormClose) { return false; }
    this.checkingFormClose = true;
    try {
      if (this.formSession.dirty) {
        const message = this.formSession.skipDrafts ? '本次输入将放弃，现有本地草稿保留。' : '本次未保存的修改和对应本地草稿将放弃，正式记录保留。';
        const accepted = await confirm(this.getUIContext(), '放弃本次修改？', message, '放弃修改', '继续编辑');
        if (!accepted) { return false; }
        return this.formSession.finish(true);
      }
      return this.formSession.finish(false);
    } finally { this.checkingFormClose = false; }
  }
  private rootSheetOptions(): SheetOptions {
    const options = appSheetOptions((): void => { this.importOpen = false; this.formOpen = false; this.restoreOpen = false; this.creatingForImport = false; if (this.pendingImportPlanId && !this.state.staleScopes.length) { void this.continueImport(); } if (this.rootSheetKind === 'restore') { this.state.cancelRestoreData(); } if (this.editingShotRoute) { const route = this.editingShotRoute; this.editingShotRoute = undefined; if (this.state.projects.some((project: CosProject) => project.id === route.id)) { route.shotsOpen = true; } } }, this.sheetEntrance, this.getUIContext());
    if (this.rootSheetKind === 'form') {
      options.keyboardAvoidMode = SheetKeyboardAvoidMode.RESIZE_ONLY;
      options.onWillDismiss = (action: DismissSheetAction): void => { this.allowFormClose().then((allowed: boolean): void => { if (allowed) { action.dismiss(); } }); };
    }
    if (this.rootSheetKind === 'restore') { options.onWillDismiss = (action: DismissSheetAction): void => { if (!this.state.busy) { action.dismiss(); } }; }
    return options;
  }

  @Builder rootSheet() {
    if (this.rootSheetKind === 'form') { this.form() }
    else if (this.rootSheetKind === 'restore') {
      BackupRestoreSheet({ state: this.state, close: (): void => { this.closeRestore(); }, done: (): void => { this.restoreOpen = false; this.resetNavigation(); } })
    } else { this.importSheet() }
  }
  @Builder form() {
    FormEditor({
      entrance: this.sheetEntrance,
      state: this.state, draft: this.formSession.draft, session: this.formSession,
      creationAction: this.creatingForImport ? '创建计划并导入照片' : '创建计划并开始准备',
      close: (): void => { this.allowFormClose().then((allowed: boolean): void => { if (allowed) { this.formOpen = false; } }); },
      done: (): void => { this.formOpen = false; },
      saved: (kind: string, id: string, created: boolean): void => {
        if (kind === 'shot' && this.editingShotRoute) { this.editingShotRoute.focusShotId = id; this.editingShotRoute.focusShotHandled = false; }
        if (kind === 'project' && created) {
          if (this.creatingForImport) { this.pendingImportPlanId = id; this.open('projectPhotos', id); }
          else { this.open('projectPreparation', id); }
        }
      },
    })
  }

  @Builder detailContent(kind: string, param: Object, entrance: StaggerEntrance) {
    Column() {
      if (kind === 'character') {
        if (this.state.characters.some((character: Character) => character.id === (param as CharacterRoute).id)) {
          CharacterDetail({ entrance: entrance, state: this.state, route: param as CharacterRoute,
            character: this.state.characters.find((character: Character) => character.id === (param as CharacterRoute).id)!,
            open: (k: string, id: string): void => { this.open(k, id); },
            edit: (k: string, id: string, parent: string): void => { this.edit(k, id, parent); },
            createPlan: (characterId: string, variantId: string): void => { this.edit('project', '', characterId, variantId); },
            remove: (k: string, id: string): void => { void this.remove(k, id); }
          })
        } else { EmptyState({ title: '角色已不存在', message: '返回继续查看已有资料。', button: '返回', action: (): void => { this.closeDetail(); } }).margin({ top: Theme.detailTopWithSegment }) }
      }
      else if (kind === 'project') {
        if (!this.state.projects.some((project: CosProject) => project.id === (param as ProjectRoute).id)) {
          EmptyState({ title: '计划已不存在', message: '可以返回继续查看其他事项。', button: '返回', action: (): void => { this.closeDetail(); } }).margin({ top: Theme.detailTop })
        } else if ((param as ProjectRoute).section === 3) {
          PhotoGrid({
            entrance: entrance,
            state: this.state,
            topInset: Theme.detailTop,
            bottomInset: Theme.contentBottom,
            sidePadding: Theme.pagePadding,
            route: (param as ProjectRoute).photos, from: 'project',
            header: (): void => { this.projectPhotoHeader(param as ProjectRoute); },
            addPhotos: (): void => { this.state.importPhotos((param as ProjectRoute).id); },
            showAlbum: (): void => { this.open('album', (param as ProjectRoute).id); },
            photos: this.state.photos, view: (route: PhotoViewerRoute): void => { this.openPhoto(route); }
          })
        }
        else {
          ProjectDetail({
            entrance: entrance,
            state: this.state,
            route: param as ProjectRoute,
            topInset: Theme.detailTop,
            project: this.state.projects.find((p: CosProject) => p.id === (param as ProjectRoute).id) as CosProject,
            open: (k: string, id: string) => this.open(k, id),
            edit: (k: string, id: string, parent: string) => this.edit(k, id, parent),
            remove: (k: string, id: string) => this.remove(k, id)
          })
        }
      }
      else if (kind === 'reference') {
        if (this.state.references.some((reference: ReferenceImage) => reference.id === (param as string))) {
          ReferenceDetail({
            entrance: entrance,
            state: this.state,
            reference: this.state.references.find((reference: ReferenceImage) => reference.id === (param as string)) as ReferenceImage
          })
        } else { EmptyState({ title: '参考图已不存在', message: '可以返回所属计划或角色继续查看。', button: '返回', action: (): void => { this.closeDetail(); } }).margin({ top: Theme.detailTop }) }
      }
      else if (kind === 'expenseStats') {
        ExpenseSummary({
          entrance: entrance,
          state: this.state,
          route: param as LedgerRoute,
          edit: (k: string, id: string, parent: string): void => this.edit(k, id, parent),
          remove: (k: string, id: string): void => { this.remove(k, id); }
        })
      }
      else if (kind === 'asset') {
        if (this.state.assets.some((asset: Asset) => asset.id === (param as AssetRoute).id)) {
          AssetDetail({ entrance: entrance, state: this.state, route: param as AssetRoute,
            asset: this.state.assets.find((asset: Asset) => asset.id === (param as AssetRoute).id) as Asset,
            open: (kind: string, id: string): void => { this.open(kind, id); }, edit: (kind: string, id: string, parent: string): void => { this.edit(kind, id, parent); } })
        } else { EmptyState({ title: '装备已不存在', message: '可以返回原来的计划或衣柜范围。', button: '返回', action: (): void => { this.closeDetail(); } }).margin({ top: Theme.detailTop }) }
      }
      else if (kind === 'photo') {
        if (this.state.photos.some((photo: PhotoAsset) => photo.id === (param as PhotoViewerRoute).id)) {
          PhotoDetail({ entrance: entrance, state: this.state,
            photo: this.state.photos.find((photo: PhotoAsset) => photo.id === (param as PhotoViewerRoute).id) as PhotoAsset,
            open: (k: string, id: string): void => { this.open(k, id); }, edit: (k: string, id: string, parent: string): void => { this.edit(k, id, parent); }, remove: (k: string, id: string): void => { this.remove(k, id); } })
        } else { EmptyState({ title: '照片记录已不存在', message: '可以返回原来的照片范围。', button: '返回', action: (): void => { this.closeDetail(); } }).margin({ top: Theme.detailTop }) }
      }
    }.width('100%').height('100%')
  }

  private viewLabels(kind: string, param: Object): string[] {
    if (kind === 'project') { return ['概览', '准备', '打包', '照片']; }
    if (kind === 'character') { return ['资料', '履历', '参考图']; }
    if (kind === 'asset' && this.assetSegmented(param as AssetRoute)) { return ['资料', '使用计划']; }
    if (kind === 'album') { return ['按场次', '待处理']; }
    if (kind === 'search') { return SEARCH_SECTIONS; }
    return [];
  }
  private viewIcons(kind: string): Resource[] {
    if (kind === 'project') { return [Icons.home, Icons.check, Icons.library, Icons.importPhoto]; }
    if (kind === 'character') { return [Icons.profile, Icons.plan, Icons.importPhoto]; }
    if (kind === 'asset') { return [Icons.library, Icons.plan]; }
    if (kind === 'album') { return [Icons.importPhoto, Icons.check]; }
    return [Icons.plan, Icons.profile, Icons.event, Icons.library];
  }
  private viewIndex(kind: string, param: Object): number {
    if (kind === 'project') { return (param as ProjectRoute).section; }
    if (kind === 'character') { return (param as CharacterRoute).section; }
    if (kind === 'asset') { return (param as AssetRoute).section; }
    if (kind === 'album') { return (param as AlbumRoute).mode === 'queue' ? 1 : 0; }
    return (param as SearchRoute).section;
  }
  private canChangeView(kind: string, param: Object, index: number): boolean {
    if (kind === 'album') { return (param as AlbumRoute).canShowMode(index ? 'queue' : 'byPlan'); }
    if (kind === 'project') { return (param as ProjectRoute).canShowSection(index); }
    return true;
  }
  private changeView(kind: string, param: Object, index: number): void {
    if (!this.canChangeView(kind, param, index)) { return; }
    if (kind === 'project') { const route = param as ProjectRoute; route.section = index; route.outing = false; this.state.suspend(); }
    else if (kind === 'character') { (param as CharacterRoute).section = index; }
    else if (kind === 'asset') { (param as AssetRoute).section = index; }
    else if (kind === 'album') { (param as AlbumRoute).showMode(index ? 'queue' : 'byPlan'); }
    else { (param as SearchRoute).setSection(index); }
  }
  @Builder destinationBody(kind: string, param: Object, entrance: StaggerEntrance) {
    if (this.viewLabels(kind, param).length > 0) {
      HdsViewTabs({ labels: this.viewLabels(kind, param), icons: this.viewIcons(kind), selectedIndex: this.viewIndex(kind, param),
        componentId: kind + '-view-tabs', effects: this.state.settings.effects, materialLevel: this.state.settings.materialLevel,
        availableWidth: this.viewportWidth, haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        canChange: (index: number): boolean => { return this.canChangeView(kind, param, index); },
        changed: (index: number): void => { this.changeView(kind, param, index); },
        content: this.destinationPage.bind(this, kind, param, entrance) })
    } else { this.destinationPage(kind, param, entrance) }
  }

  @Builder destinationPage(kind: string, param: Object, entrance: StaggerEntrance) {
    if (kind === 'search') {
      SearchPage({ state: this.state, route: param as SearchRoute, open: (hit: SearchHit): void => { this.openSearchResult(param as SearchRoute, hit); }, library: (): void => { this.open('characters', 'all'); } })
    } else if (kind === 'characters') {
      CosPage({ state: this.state, route: param as PlanListRoute, projects: false, active: true, topInset: Theme.detailTop, bottomInset: Theme.contentBottom,
        open: (k: string, id: string): void => { this.open(k, id); }, add: (k: string, parent: string): void => { this.edit(k, '', parent); } })
    } else if (kind === 'album') {
      AlbumPage({ state: this.state, route: param as AlbumRoute, entrance: entrance, view: (route: PhotoViewerRoute): void => { this.openPhoto(route); }, importPhotos: (id: string): void => { this.chooseImport(id); } })
    } else if (kind === 'project' || kind === 'expenseStats' || kind === 'photo' || kind === 'asset' || kind === 'character') {
      this.detailContent(kind, param, entrance)
    } else if (kind === 'tasks') {
      TasksPage({ state: this.state, route: param as TaskRoute, openItem: (item: TaskQueueItem): void => { this.openTaskItem(item); }, addPlan: (): void => { this.edit('project'); } })
    } else if (kind === 'privacy') {
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
      if (this.inboxOwnerExists(param as InboxRoute)) {
        InboxPage({ state: this.state, route: param as InboxRoute, backToOwner: (): void => { this.closeDetail(); }, open: (kind: string, id: string): void => { this.open(kind, id); } })
      } else {
        EmptyState({ title: '收录归属对象已不存在', message: '保留的条目可在未归位收录中继续整理。', button: '返回', action: (): void => { this.closeDetail(); } }).margin({ top: Theme.detailTop })
      }
    } else if (kind === 'developer') {
      DevPage({ entrance: entrance, state: this.state })
    } else {
      this.detailContent(kind, param, entrance)
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
          kind === 'tasks' ? '全部待办' : kind === 'inbox' ? this.inboxTitle(param as InboxRoute) : this.destinationTitle(kind, kind === 'project' ? (param as ProjectRoute).id : kind === 'character' ? (param as CharacterRoute).id : kind === 'asset' ? (param as AssetRoute).id : param as string),
          this.state.settings.effects,
          this.state.settings.materialLevel,
          undefined,
          kind === 'character' ? this.characterMenus(param as CharacterRoute) : kind === 'project' ? this.projectMenus(param as ProjectRoute) : kind === 'album' ? [{ content: { label: '导入照片', icon: Icons.importPhoto, isEnabled: !this.state.busy, action: (): void => { this.chooseImport((param as AlbumRoute).collection.planId); } } }] : kind === 'asset' ? this.assetMenus(param as AssetRoute) : kind === 'reference' ? this.referenceMenus(param as string) : kind === 'photo' ? this.photoMenus(param as PhotoViewerRoute) : kind === 'expenseStats' ? [{ content: { label: '记一笔', icon: Icons.add, isEnabled: !this.state.busy, action: (): void => { this.edit('expense', '', (param as LedgerRoute).projectId); } } }] : kind === 'characters' ? [{ content: { label: '添加角色', icon: Icons.add, isEnabled: !this.state.busy, action: (): void => { this.edit('character'); } } }] : [], false,
          (): void => { this.closeDetail(); },
        ),
        back: (): void => { this.closeDetail(); },
        shown: (): void => {
          if (kind === 'inbox') { (param as InboxRoute).restoreVersion++; }
          if (kind === 'search') { (param as SearchRoute).restoreVersion++; }
          if (kind === 'expenseStats') { (param as LedgerRoute).restoreVersion++; }
          if (kind === 'characters') { (param as PlanListRoute).restoreVersion++; }
          if (kind === 'character') { (param as CharacterRoute).restoreVersion++; }
          if (kind === 'asset') { (param as AssetRoute).restoreVersion++; }
          if (kind === 'tasks') { (param as TaskRoute).restoreVersion++; }
          if (kind === 'project') { (param as ProjectRoute).restoreVersion++; (param as ProjectRoute).photos.restoreVersion++; if ((param as ProjectRoute).resumeShots) { (param as ProjectRoute).resumeShots = false; (param as ProjectRoute).shotsOpen = true; } if ((param as ProjectRoute).outing) { this.state.resume(); } }
          if (kind === 'album') { (param as AlbumRoute).restoreVersion++; (param as AlbumRoute).collection.restoreVersion++; }
        },
        hidden: (): void => {
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
    if (kind === 'search') { return '全局搜索'; }
    if (kind === 'album') { return '相册'; }
    if (kind === 'characters') { return '角色库'; }
    if (kind === 'privacy') { return '隐私政策'; }
    if (kind === 'settings') { return '我的'; }
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
  private chooseImport(planId: string = ''): void {
    if (planId && this.state.projects.some((project: CosProject) => project.id === planId)) { this.state.importPhotos(planId); return; }
    if (this.state.projects.length === 0) { this.createForImport(); }
    else { this.rootSheetKind = 'import'; this.importOpen = true; }
  }
  private createForImport(): void {
    this.edit('project'); this.creatingForImport = true; this.importOpen = false;
  }
  private async continueImport(): Promise<void> {
    const id = this.pendingImportPlanId;
    if (!id || this.state.busy || this.state.staleScopes.length) { return; }
    this.pendingImportPlanId = '';
    if (this.state.projects.some((project: CosProject) => project.id === id)) { await this.state.importPhotos(id); }
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
      Button('新建计划后继续导入').constraintSize({ minHeight: 48 }).width('100%').onClick((): void => { this.createForImport(); })
      List({ space: 10 }) {
        ForEach(this.state.projects, (p: CosProject) => {
          ListItem() {
            Button(p.name)
            .accessibilityText('选择照片所属计划 ' + p.name)
            .width('100%')
            .constraintSize({ minHeight: 56 })
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .onClick(() => { HapticService.confirm(this.state.settings.haptic); this.pendingImportPlanId = p.id; this.importOpen = false; })
            .visualEffect(this.feedback.effect('import-project:' + p.id, true))
            .compositingFilter(this.feedback.filter('import-project:' + p.id, true))
            .attributeModifier(this.feedback.control('import-project:' + p.id, true))
          }
        }, (p: CosProject) => p.id)
      }.layoutWeight(1).width('100%').opacity(this.sheetEntrance.step >= 2 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
    }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface)
  }

  private rootTools(index: number): ToolbarItem[] {
    if (index === 2) { return [{ value: '添加活动', icon: Icons.add, action: (): void => { this.edit('event'); } }]; }
    if (index === 3) { return [{ value: '添加装备', icon: Icons.add, action: (): void => { this.edit('asset'); } }]; }
    if (index === 4) { return [{ value: '导入照片', icon: Icons.importPhoto, action: (): void => { this.chooseImport(this.albumRoute.collection.planId); } }]; }
    if (index === 0) { return []; }
    return [{ value: '新建计划', icon: Icons.add, action: (): void => { this.edit('project'); } }];
  }
  private rootMenus(index: number): HdsNavigationMenuItemOptions[] {
    const enabled = this.state.ready && !this.state.busy && !this.state.staleScopes.length;
    const menus = this.rootTools(index).map((item: ToolbarItem): HdsNavigationMenuItemOptions => {
      return { content: { label: item.value, icon: item.icon as Resource, isEnabled: enabled, action: item.action, componentId: 'root-action-' + item.value } };
    });
    if (index === 0) {
      menus.push({ content: { label: '我的', componentId: 'root-action-我的', icon: Icons.profile, isEnabled: this.state.ready && !this.state.busy,
        action: (): void => { this.open('settings', 'settings'); } } });
    }
    return menus;
  }

  private characterMenus(route: CharacterRoute): HdsNavigationMenuItemOptions[] {
    if (!this.state.characters.some((character: Character) => character.id === route.id)) { return []; }
    const enabled = !this.state.busy && !this.state.staleScopes.length;
    return [{ content: { label: '编辑角色', icon: Icons.edit, isEnabled: enabled, action: (): void => { this.edit('character', route.id); } } },
      { content: { label: '删除角色', icon: Icons.remove, isEnabled: enabled, action: (): void => { void this.remove('character', route.id); } } }];
  }
  private assetSegmented(route: AssetRoute): boolean {
    const asset = this.state.assets.find((item: Asset) => item.id === route.id);
    return !!asset && (route.section === 1 || assetUsesSegments(asset, this.state.assetUsage(route.id)));
  }
  private assetMenus(route: AssetRoute): HdsNavigationMenuItemOptions[] {
    if (!this.state.assets.some((asset: Asset) => asset.id === route.id)) { return []; }
    const enabled = !this.state.busy && !this.state.staleScopes.length;
    return [{ content: { label: '编辑装备', icon: Icons.edit, isEnabled: enabled, action: (): void => { this.edit('asset', route.id); } } },
      { content: { label: '删除装备', icon: Icons.remove, isEnabled: enabled, action: (): void => { void this.remove('asset', route.id); } } }];
  }
  @Builder projectPhotoHeader(route: ProjectRoute) {
    ProjectPhotoHeader({ state: this.state, route: route,
      edit: (id: string, projectId: string): void => { this.edit('shot', id, projectId); this.editingShotRoute = route; },
      openReference: (id: string): void => { this.open('reference', id); },
      openAlbum: (): void => { this.open('album', route.id); }
    })
  }
  private photoMenus(route: PhotoViewerRoute): HdsNavigationMenuItemOptions[] {
    const photo = this.state.photos.find((photo: PhotoAsset) => photo.id === route.id); if (!photo) { return []; }
    return [{ content: { label: '设为角色封面', icon: Icons.edit, isEnabled: !this.state.busy && !!photo.thumbnailPath, action: (): void => { this.setCover(photo); } } },
      { content: { label: '删除照片', icon: Icons.remove, isEnabled: !this.state.busy, action: (): void => { this.remove('photo', route.id); } } }];
  }
  private projectMenus(route: ProjectRoute): HdsNavigationMenuItemOptions[] {
    const tools: ToolbarItem[] = [];
    if (route.section === 1) {
      tools.push({ value: '添加准备任务', icon: Icons.add, action: (): void => { route.sheetKind = 0; route.preparing = true; } });
      tools.push({ value: '从衣柜复用', icon: Icons.library, action: (): void => { route.sheetKind = 1; route.linking = true; } });
    } else if (route.section === 2) {
      if (!route.outing) {
        tools.push({ value: '添加物品', icon: Icons.add, action: (): void => { this.edit('checklist', '', route.id); } });
        tools.push({ value: '补入常用物品', icon: Icons.check, action: (): void => { this.state.generateChecklist(route.id); } });
      }
      tools.push({ value: route.outing ? '结束出门' : '出门模式', icon: Icons.check, action: (): void => { route.outing = !route.outing; if (route.outing) { this.state.resume(); } else { this.state.suspend(); } } });
    } else if (route.section === 3) { tools.push({ value: '导入照片', icon: Icons.importPhoto, action: (): void => { this.state.importPhotos(route.id); } }); }
    if (!route.outing) {
      if (this.state.projects.find((project: CosProject) => project.id === route.id)?.status === ProjectStatus.COMPLETED) {
        tools.unshift({ value: '归档计划', icon: Icons.plan, action: (): void => { void this.state.archiveProject(route.id); } });
      }
      tools.push({ value: '编辑计划', icon: Icons.edit, action: (): void => { this.edit('project', route.id); } });
      tools.push({ value: '分享', icon: Icons.share, action: (): void => { this.state.shareProject(route.id); } });
      tools.push({ value: '删除计划', icon: Icons.remove, action: (): void => { this.remove('project', route.id); } });
    }
    return tools.map((item: ToolbarItem): HdsNavigationMenuItemOptions => { return { content: { label: item.value, icon: item.icon as Resource, isEnabled: !this.state.busy && !this.state.staleScopes.length, action: item.action, componentId: 'detail-action-' + item.value } }; });
  }

  private referenceMenus(id: string): HdsNavigationMenuItemOptions[] {
    if (!this.state.references.some((reference: ReferenceImage) => reference.id === id)) { return []; }
    const enabled = !this.state.busy && !this.state.staleScopes.length;
    return [
      { content: { label: '设为封面', icon: Icons.importPhoto, isEnabled: enabled, action: (): void => { this.referenceCover(id); } } },
      { content: { label: '编辑说明', icon: Icons.edit, isEnabled: enabled, action: (): void => { this.edit('reference', id); } } },
      { content: { label: '删除', icon: Icons.remove, isEnabled: enabled, action: (): void => { void this.remove('reference', id); } } },
    ];
  }

  private segmentLabels(index: number): string[] {
    if (index === 1) { return ['进行中', '已完成', '全部']; }
    if (index === 2) { return ['列表', '日历']; }
    if (index === 4) { return ['按场次', '待处理']; }
    return [];
  }

  private segmentSelection(index: number): number {
    if (index === 1) { return this.planListRoute.section; }
    if (index === 2) { return this.scheduleRoute.calendar ? 1 : 0; }
    return index === 4 && this.albumRoute.mode === 'queue' ? 1 : 0;
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
          if (index === 1) { this.planListRoute.status = ''; this.planListRoute.section = selected; }
          else if (index === 2) { this.scheduleRoute.showCalendar(selected === 1); }
          else if (index === 4) { this.albumRoute.showMode(selected ? 'queue' : 'byPlan'); }
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
        if (this.state.photoImport.phase === 'importing') {
          Column({ space: 14 }) {
            LoadingProgress().width(40).height(40).color(Theme.brand)
            Text('正在导入 · ' + this.state.projectName(this.state.photoImport.projectId)).fontSize(16).fontColor(Theme.ink)
            Text('已处理 ' + this.state.photoImport.processed + ' / ' + this.state.photoImport.total + ' 张').fontSize(16).fontColor(Theme.ink)
            Button(this.state.photoImport.stopRequested ? '正在停止…' : '停止剩余导入').constraintSize({ minHeight: 48 }).enabled(!this.state.photoImport.stopRequested)
              .onClick((): void => { this.state.photoImport.cancel(); })
            Text('已提交的照片保留；当前文件处理结束后停止。').fontSize(14).fontColor(Theme.muted)
          }.padding(24).width('90%').constraintSize({ maxWidth: 460 }).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        } else { LoadingProgress().width(40).height(40).color(Theme.brand).hitTestBehavior(HitTestMode.None).accessibilityText('操作进行中') }
      }
      if (this.pendingImportPlanId && !this.state.busy && !this.state.staleScopes.length) {
        Column({ space: 10 }) {
          Text('计划已保存，可继续导入照片。').fontSize(14).fontColor(Theme.ink)
          Button('继续导入照片').constraintSize({ minHeight: 48 }).onClick((): void => { void this.continueImport(); })
          Button('稍后导入').constraintSize({ minHeight: 48 }).onClick((): void => { this.pendingImportPlanId = ''; })
        }.padding(24).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
      }
      if (this.state.photoImport.phase === 'completed' && !this.state.staleScopes.length && !this.state.busy) {
        Row({ space: 12 }) {
          Text(this.state.photoImport.summary()).fontSize(14).fontColor(Theme.ink).layoutWeight(1)
          Button('查看导入结果').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('album', this.state.photoImport.projectId); })
          Button('关闭').constraintSize({ minHeight: 48 }).onClick((): void => { this.state.photoImport.clear(); })
        }.width('100%').padding(16).backgroundColor(Theme.surface).margin({ bottom: Theme.contentBottom }).align(Alignment.Bottom).accessibilityGroup(true)
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
            bottomInset: Theme.homeContentBottom + this.daySnackReservation,
            active: this.tab === index,
            open: (k: string, id: string) => this.open(k, id),
            openTask: (item: TaskQueueItem): void => { this.openTaskItem(item); },
            add: (k: string, parent: string) => this.edit(k, '', parent)
          })
        }
        else if (index === 1) {
          CosPage({
            entranceSession: this.mainEntranceSession,
            scroller: this.pageScrollers[index],
            state: this.state,
            topInset: Theme.contentTop,
            bottomInset: Theme.contentBottom + this.daySnackReservation,
            active: this.tab === index,
            route: this.planListRoute,
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
            bottomInset: Theme.contentBottom + this.daySnackReservation,
            active: this.tab === index,
            route: this.scheduleRoute,
            openTask: (item: TaskQueueItem): void => { this.openTaskItem(item); },
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
            bottomInset: Theme.contentBottom + this.daySnackReservation,
            active: this.tab === index,
            route: this.wardrobeRoute,
            open: (k: string, id: string) => this.open(k, id),
            add: (k: string, parent: string) => this.edit(k, '', parent)
          })
        }
        else {
          AlbumPage({
            state: this.state, route: this.albumRoute,
            scroller: this.pageScrollers[index], entranceSession: this.mainEntranceSession,
            topInset: Theme.contentTop, bottomInset: Theme.contentBottom + this.daySnackReservation, active: this.tab === index,
            view: (route: PhotoViewerRoute): void => { this.openPhoto(route); },
            importPhotos: (id: string): void => { this.chooseImport(id); }
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
        (index === 1 || index === 2 || index === 4) ? (): void => { this.titleSegment(index); } : undefined,
        this.rootMenus(index), true,
      ))
      .hideToolBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%').height('100%').backgroundColor(Theme.bg)
      .onNavBarStateChange((_visible: boolean): void => { this.syncDaySnack(); })
  }

  @Builder mainTabs() {
    HdsTabs({ controller: this.tabsController, index: this.tab }) {
      TabContent() { this.mainNavigation(0) }
        .tabBar(new BottomTabBarStyle(Icons.home, '首页')).accessibilityText('首页标签页')
      TabContent() { this.mainNavigation(1) }
        .tabBar(new BottomTabBarStyle(Icons.plan, '计划')).accessibilityText('计划标签页')
      TabContent() { this.mainNavigation(2) }
        .tabBar(new BottomTabBarStyle(Icons.event, '日程')).accessibilityText('日程标签页')
      TabContent() { this.mainNavigation(3) }
        .tabBar(new BottomTabBarStyle(Icons.library, '衣柜')).accessibilityText('衣柜标签页')
      TabContent() { this.mainNavigation(4) }
        .tabBar(new BottomTabBarStyle(Icons.importPhoto, '相册')).accessibilityText('相册标签页')
    }.id('main-tabs')
      .barPosition(BarPosition.End).barHeight(Theme.mainTabsHeight)
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
      .width('100%').height('100%')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Theme.bg)
      .accessibilityText('首页、计划、日程、衣柜、相册五个标签页')
      .onAreaChange((_, area: Area): void => { this.viewportWidth = Number(area.width); this.syncDaySnack(); })
  }

  private hideDaySnack(): void {
    try { if (this.daySnackKey) { this.daySnackBar?.dismiss(); } }
    catch (error) { console.warn('Today SnackBar could not be dismissed: ' + String(error)); }
    finally { this.daySnackKey = ''; this.daySnackReservation = 0; }
  }
  @Monitor('state.todayEvents', 'state.ready', 'formOpen', 'importOpen', 'restoreOpen', 'state.settings')
  daySnackChanged(): void { this.syncDaySnack(); }
  private async dismissDaySnack(id: string): Promise<void> {
    if (this.closingDaySnack) { return; }
    this.closingDaySnack = true; this.hideDaySnack();
    try { await this.state.dismissDayEntry(id); }
    finally { this.closingDaySnack = false; this.syncDaySnack(); }
  }
  private syncDaySnack(): void {
    const event = this.state.todayEvents[0];
    if (!this.visible || !this.rootVisible || !this.state.ready || !event || this.detailStack.size() > 0 || this.stacks[this.tab].size() > 0 || this.formOpen || this.importOpen || this.restoreOpen || this.closingDaySnack) {
      this.hideDaySnack(); return;
    }
    const title = dayTitle(event, this.state.clockTime);
    const remaining = this.state.todayEvents.length - 1;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    const scale = Math.max(1, context?.config.fontSizeScale || 1);
    const width = Math.min(Theme.contentMaxWidth, Math.max(0, this.viewportWidth - 32));
    if (width <= 0) { return; }
    const key = JSON.stringify([event.id, title, remaining, width, scale, Theme.paletteId, this.state.settings.effects, this.state.settings.appearance]);
    if (key === this.daySnackKey) { return; }
    this.hideDaySnack();
    try {
      if (!this.daySnackBar) { this.daySnackBar = new HdsSnackBar(this.getUIContext()); }
      this.daySnackBar.show(
        { icon: Icons.event },
        { title: title, content: remaining ? '还有 ' + remaining + ' 场活动 · 查看今天模式' : '出发前与现场事项' },
        { operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: '进入', textButtonId: 'day-entry-bar', cancelButtonId: 'day-entry-close',
          contentAccessibilityText: '进入' + title + '的今天模式', closeButtonAccessibilityText: '今天不再显示这场活动的入口',
          onContentClick: (): void => { this.hideDaySnack(); this.open('dayEvent', event.id); },
          onCloseButtonClick: (): void => { void this.dismissDaySnack(event.id); } },
        { duration: -1, isHeightAdaptive: true, width: LengthMetrics.vp(width),
          keyboardDownAvoidHeight: LengthMetrics.vp(Theme.mainTabsHeight + Theme.mainTabsBottomMargin + Theme.daySnackGap),
          keyboardUpAvoidHeight: LengthMetrics.vp(Theme.daySnackGap), nextFocusId: 'main-tabs', theme: Theme.nativeTheme,
          blurStrategy: this.state.settings.effects ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
          pressBackCallback: (): void => { void this.dismissDaySnack(event.id); } }
      );
      this.daySnackKey = key; this.daySnackReservation = Theme.daySnackReservation * scale;
    } catch (error) { console.warn('Today SnackBar could not be shown: ' + String(error)); }
  }

  build() {
    WithTheme({ theme: Theme.nativeTheme }) {
    HdsNavigation(this.detailStack) {
      this.mainTabs()
    }.mode(NavigationMode.Stack).hideTitleBar(true).hideToolBar(true)
      .onNavBarStateChange((visible: boolean): void => { this.rootVisible = visible; this.syncDaySnack(); })
      .navDestination(this.destination)
      .customNavContentTransition((_from: NavContentInfo, _to: NavContentInfo, operation: NavigationOperation) => {
        if (operation === NavigationOperation.POP) { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); }
        return undefined;
      })
      .width('100%').height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Theme.bg).overlay(this.loadingOverlay, { align: Alignment.Center })
      .bindSheet(this.importOpen || this.formOpen || this.restoreOpen, this.rootSheet(), this.rootSheetOptions())
    }
  }
}
