import { HdsNavigation, HdsNavDestination, HdsNavigationTitleMode, HdsTabs, HdsTabsController, HdsNavigationMenuItemOptions, BlurStrategy, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { AppState, applicationState } from '../common/AppState';
import { confirm } from '../common/Confirm';
import { showToastSafely } from '../common/safeUi';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';
import { SegmentButtonV2Items, SegmentButtonV2ItemOptions } from '@kit.ArkUI';
import { HdsTitleBarSegment } from '../components/HdsTitleBarSegment';
import { HdsActionTabs } from '../components/HdsActionTabs';
import { HapticService } from '../services/haptic/HapticService';
import { ProjectRoute } from '../model/ProjectRoute';
import { EditDraft } from '../model/EditDraft';
import { Character, CosProject, Asset, CosEvent, PhotoAsset, PhotoStatus } from '../model/Entities';
import { SystemCapability } from '../services/capability/SystemCapability';
import { HomePage } from '../features/home/HomePage';
import { CosPage } from '../features/cos/CosPage';
import { EventsPage } from '../features/event/EventsPage';
import { LibraryPage } from '../features/asset/LibraryPage';
import { SettingsPage } from '../features/settings/SettingsPage';
import { MePage } from '../features/settings/MePage';
import { CharacterDetail } from '../features/cos/CharacterDetail';
import { ProjectDetail } from '../features/project/ProjectDetail';
import { AssetDetail } from '../features/asset/AssetDetail';
import { EventDetail } from '../features/event/EventDetail';
import { PhotoDetail } from '../features/photo/PhotoDetail';
import { PhotoGrid } from '../features/photo/PhotoGrid';
import { FormEditor } from '../components/FormEditor';
import { EmptyState } from '../components/Surfaces';

@Entry
@ComponentV2
struct Index {
  @Local state: AppState = applicationState;
  private detailStack: NavPathStack = new NavPathStack();
  private stacks: NavPathStack[] = [new NavPathStack(), new NavPathStack(), new NavPathStack(), new NavPathStack(), new NavPathStack()];
  private pageScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller(), new Scroller()];
  private tabsController: HdsTabsController = new HdsTabsController();
  @Local tab: number = 0;
  @Local cosProjects: boolean = true;
  @Local eventFilter: number = 0;
  @Local meSection: number = 0;
  @Local libraryPhotos: boolean = false;
  @Local outing: boolean = false;
  @Local importOpen: boolean = false;
  @Local formOpen: boolean = false;
  @Local draft: EditDraft = new EditDraft();
  @Local viewportWidth: number = 360;
  aboutToAppear(): void { if (!this.state.ready) { this.state.start(this.getUIContext().getHostContext() as common.UIAbilityContext); } }
  onPageHide(): void { this.state.suspend(); }
  private open(kind: string, id: string): void { if (id) { HapticService.confirm(this.state.settings.haptic); this.outing = false; this.state.suspend(); if (kind === 'project' || kind === 'packing' || kind === 'projectPhotos') { this.detailStack.pushPathByName('project', new ProjectRoute(id, kind === 'packing' ? 1 : kind === 'projectPhotos' ? 2 : 0)); } else { this.detailStack.pushPathByName(kind, id); } } }
  private edit(kind: string, id: string = '', parent: string = ''): void {
    HapticService.confirm(this.state.settings.haptic);
    this.state.error = '';
    this.draft = EditDraft.make(this.state, kind === 'eventProject' ? 'project' : kind, id, parent); this.formOpen = true;
  }
  private async remove(kind: string, id: string): Promise<void> {
    const messages = new Map<string, string>([['project', '计划、清单、照片记录与应用内照片副本将删除。系统相册原图保留。'], ['character', '角色及其版本将删除。仍有关联计划时无法删除。'], ['asset', '衣柜装备与所有计划关联将删除，清单会保留名称。'], ['event', '漫展将删除，关联计划会保留。'], ['photo', '照片记录与本地副本将删除，系统相册原图保留。'], ['variant', '角色版本将删除；仍被计划使用时无法删除。'], ['checklist', '此清单项将删除。']] );
    const accepted = await confirm(this.getUIContext(), '确认删除？', messages.get(kind) || '记录将删除。', '删除');
    if (accepted && await this.state.remove(kind, id)) {
      if (kind === 'project' || kind === 'character') { this.detailStack.clear(); } else if (kind !== 'variant' && kind !== 'checklist') { this.detailStack.pop(); }
    }
  }
  private async destructive(kind: string): Promise<void> {
    const accepted = await confirm(this.getUIContext(), kind === 'restore' ? '替换当前元数据？' : '清空本地数据？', kind === 'restore' ? '建议先导出当前记录。恢复会替换全部角色、计划和衣柜记录；本机未保存的照片需重新导入。' : '全部本地记录和照片副本将删除，系统相册原图保留。建议先完成备份。', kind === 'restore' ? '选择备份' : '清空');
    if (accepted) { if (kind === 'restore') { await this.state.restoreData(); } else { await this.state.clearData(); } this.detailStack.clear(); }
  }
  @Builder form() { FormEditor({ state: this.state, draft: this.draft, done: () => { this.formOpen = false; }, saved: (kind: string, id: string, created: boolean) => { if (kind === 'project' && created) { this.open('project', id); } } }) }
  @Builder detailContent(kind: string, param: Object) {
    Column() {
      if (kind === 'character') { CharacterDetail({ state: this.state, character: this.state.characters.find((c: Character) => c.id === (param as string)) || new Character(), open: (k: string, id: string) => this.open(k, id), edit: (k: string, id: string, parent: string) => this.edit(k, id, parent), remove: (k: string, id: string) => this.remove(k, id) }) }
      else if (kind === 'project') {
        if ((param as ProjectRoute).section === 2) { PhotoGrid({ state: this.state, topInset: Theme.contentTop, bottomInset: Theme.contentBottom, sidePadding: Theme.pagePadding, photos: this.state.photos.filter((p: PhotoAsset) => p.projectId === (param as ProjectRoute).id), open: (k: string, id: string) => this.open(k, id) }) }
        else { ProjectDetail({ state: this.state, route: param as ProjectRoute, project: this.state.projects.find((p: CosProject) => p.id === (param as ProjectRoute).id) || new CosProject(), open: (k: string, id: string) => this.open(k, id), edit: (k: string, id: string, parent: string) => this.edit(k, id, parent), remove: (k: string, id: string) => this.remove(k, id) }) }
      }
      else if (kind === 'asset') { AssetDetail({ state: this.state, asset: this.state.assets.find((a: Asset) => a.id === (param as string)) || new Asset(), open: (k: string, id: string) => this.open(k, id), edit: (k: string, id: string, parent: string) => this.edit(k, id, parent), remove: (k: string, id: string) => this.remove(k, id) }) }
      else if (kind === 'event') { EventDetail({ state: this.state, event: this.state.events.find((e: CosEvent) => e.id === (param as string)) || new CosEvent(), open: (k: string, id: string) => this.open(k, id), edit: (k: string, id: string, parent: string) => this.edit(k, id, parent), remove: (k: string, id: string) => this.remove(k, id) }) }
      else if (kind === 'photo') { PhotoDetail({ state: this.state, photo: this.state.photos.find((p: PhotoAsset) => p.id === (param as string)) || new PhotoAsset(), open: (k: string, id: string) => this.open(k, id), remove: (k: string, id: string) => this.remove(k, id) }) }
      else if (kind === 'projectPhotos') { Column({ space: 12 }) { PhotoGrid({ state: this.state, topInset: Theme.contentTop, sidePadding: Theme.pagePadding, photos: this.state.photos.filter((p: PhotoAsset) => p.projectId === (param as string)), open: (k: string, id: string) => this.open(k, id) }).layoutWeight(1) }.height('100%').width('100%') }
    }.width('100%').height('100%')
  }
  @Builder destination(kind: string, param: Object) {
    HdsNavDestination() {
      if (kind === 'settings') {
        SettingsPage({ state: this.state, bottomInset: 24, destructive: (k: string): void => { this.destructive(k); } })
      } else {
        HdsActionTabs({
          items: this.detailTools(kind, param), effects: this.state.settings.effects,
          materialLevel: this.state.settings.materialLevel, availableWidth: this.viewportWidth,
          busy: this.state.busy, content: (): void => { this.detailContent(kind, param); },
        })
      }
    }.titleBar(SystemCapability.titleBar(kind === 'project' ? '' : this.destinationTitle(kind, param as string), this.state.settings.effects, this.state.settings.materialLevel, kind === 'project' ? (): void => { this.projectSegment(param as ProjectRoute); } : undefined))
      .titleMode(HdsNavDestinationTitleMode.MINI).hideToolBar(true).backgroundColor(Theme.bg)
      .onHidden((): void => { this.outing = false; this.state.suspend(); })
  }

  private destinationTitle(kind: string, id: string): string {
    if (kind === 'settings') { return '设置'; }
    if (kind === 'character') { return this.state.characterName(id); }
    if (kind === 'project') { return this.state.projectName(id); }
    if (kind === 'event') { return this.state.events.find((e: CosEvent) => e.id === id)?.name || '漫展'; }
    if (kind === 'asset') { return this.state.assets.find((a: Asset) => a.id === id)?.name || '装备'; }
    return kind === 'projectPhotos' ? '计划照片' : '照片';
  }
  private chooseImport(): void {
    if (this.state.projects.length === 0) { this.edit('project'); this.state.reportNotice('先建立计划，再导入照片。'); }
    else { this.importOpen = true; }
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
      Text('选择照片所属计划').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
      List({ space: 10 }) {
        ForEach(this.state.projects, (p: CosProject) => {
          ListItem() { Button(p.name).width('100%').constraintSize({ minHeight: 56 }).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => { this.importOpen = false; this.state.importPhotos(p.id); }) }
        }, (p: CosProject) => p.id)
      }.layoutWeight(1).width('100%')
    }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface)
  }
  private rootTools(index: number): ToolbarItem[] {
    if (index === 1) { return [{ value: this.cosProjects ? '新建计划' : '添加角色', icon: Icons.add, action: () => this.edit(this.cosProjects ? 'project' : 'character') }]; }
    if (index === 2) { return [{ value: '记录漫展', icon: Icons.event, action: () => this.edit('event') }]; }
    if (index === 3) { return [{ value: this.libraryPhotos ? '导入照片' : '添加装备', icon: this.libraryPhotos ? Icons.importPhoto : Icons.add, action: () => { if (this.libraryPhotos) { this.chooseImport(); } else { this.edit('asset'); } } }]; }
    return [{ value: '新建计划', icon: Icons.add, action: () => this.edit('project') }, { value: '记漫展', icon: Icons.event, action: () => this.edit('event') }, { value: '导入照片', icon: Icons.importPhoto, action: () => this.chooseImport() }];
  }
  private rootMenus(index: number): HdsNavigationMenuItemOptions[] {
    if (index === 4) { return [{ content: { label: '设置', componentId: 'root-action-设置', icon: Icons.settings, isEnabled: this.state.ready && !this.state.busy, action: (): void => { this.open('settings', 'settings'); } } }]; }
    return this.rootTools(index).map((item: ToolbarItem): HdsNavigationMenuItemOptions => {
      return { content: { label: item.value, icon: item.icon as Resource, isEnabled: this.state.ready && !this.state.busy, action: item.action, componentId: 'root-action-' + item.value } };
    });
  }
  @Builder projectSegment(route: ProjectRoute) {
    Column() {
      HdsTitleBarSegment({ componentId: 'project-task-segment', items: new SegmentButtonV2Items(['准备', '打包', '照片'].map((label: string): SegmentButtonV2ItemOptions => { return { text: label, accessibilityText: label }; })), selectedIndexes: [route.section], normalWidth: '50%', experimentalWidth: '50%', onSelectedIndexChanged: (selected: number): void => { route.section = selected; route.outing = false; this.state.suspend(); }, onItemClicked: (): void => { HapticService.confirm(this.state.settings.haptic); } }).margin({ top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
  private detailTools(kind: string, param: Object): ToolbarItem[] {
    const id = kind === 'project' ? (param as ProjectRoute).id : param as string;
    if (kind === 'settings') { return []; }
    if (kind === 'project') {
      const route = param as ProjectRoute;
      if (route.section === 2) { return [{ value: '导入照片', icon: Icons.importPhoto, action: () => this.state.importPhotos(id) }]; }
      if (route.section === 1) {
        return [{ value: '添加物品', icon: Icons.add, action: () => this.edit('checklist', '', id) },
          { value: '常用物品', icon: Icons.check, action: () => this.state.generateChecklist(id) },
          { value: route.outing ? '结束出门' : '出门模式', icon: Icons.check, action: () => { route.outing = !route.outing; if (route.outing) { this.state.resume(); } else { this.state.suspend(); } } }];
      }
      return [{ value: '添加装备', icon: Icons.add, action: () => this.edit('asset', '', id) },
        { value: '从衣柜', icon: Icons.library, action: () => { route.linking = true; } },
        { value: '编辑', icon: Icons.edit, action: () => this.edit('project', id) },
        { value: '分享', icon: Icons.share, action: () => this.state.shareProject(id) },
        { value: '删除计划', icon: Icons.remove, action: () => this.remove('project', id) }];
    }
    if (kind === 'character') { return [{ value: '新建计划', symbolIcon: Icons.toolbarAdd(), action: () => this.edit('project', '', id) }, { value: '添加版本', symbolIcon: Icons.toolbarAdd(), action: () => this.edit('variant', '', id) }, { value: '编辑角色', icon: Icons.edit, action: () => this.edit('character', id) }, { value: '删除角色', icon: Icons.remove, action: () => this.remove('character', id) }]; }
    if (kind === 'event') { return [{ value: '新建计划', icon: Icons.add, action: () => this.edit('eventProject', '', id) }, { value: '编辑', icon: Icons.edit, action: () => this.edit(kind, id) }, { value: '删除', icon: Icons.remove, action: () => this.remove(kind, id) }]; }
    if (kind === 'asset') { return [{ value: '编辑', icon: Icons.edit, action: () => this.edit(kind, id) }, { value: '删除', icon: Icons.remove, action: () => this.remove(kind, id) }]; }
    if (kind === 'projectPhotos') { return [{ value: '导入照片', icon: Icons.importPhoto, action: () => this.state.importPhotos(id) }]; }
    return [{ value: '选中照片', icon: Icons.check, action: () => { const photo = this.state.photos.find((p: PhotoAsset) => p.id === id); if (photo) { this.state.setPhotoStatus(photo, PhotoStatus.SELECTED); } } }, { value: '设为封面', symbolIcon: Icons.toolbarCover(), action: () => { const photo = this.state.photos.find((p: PhotoAsset) => p.id === id); if (photo) { this.setCover(photo); } } }, { value: '删除', icon: Icons.remove, action: () => this.remove('photo', id) }];
  }

  @Builder titleSegment(index: number) {
    Column() {
    HdsTitleBarSegment({
      componentId: 'secondary-segment-' + index,
      items: new SegmentButtonV2Items((index === 1 ? ['角色', '计划'] : index === 2 ? ['即将', '过去', '想去'] : index === 3 ? ['装备', '照片'] : ['作品', '时间轴']).map((label: string): SegmentButtonV2ItemOptions => { return { text: label, accessibilityText: label === '即将' ? '即将参加' : label === '过去' ? '已过去' : label }; })),
      selectedIndexes: [index === 1 ? (this.cosProjects ? 1 : 0) : index === 2 ? this.eventFilter : index === 3 ? (this.libraryPhotos ? 1 : 0) : this.meSection],
      experimentalWidth: '50%',
      normalWidth: '50%',
      onSelectedIndexChanged: (selected: number) => {
        if (index === 1) { this.cosProjects = selected === 1; }
        else if (index === 2) { this.eventFilter = selected; }
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
  @Builder loadingOverlay() {
    if (this.state.busy) { LoadingProgress().width(40).height(40).color(Theme.accent).hitTestBehavior(HitTestMode.None).accessibilityText('操作进行中') }
  }
  @Builder mainNavigation(index: number) {
    HdsNavigation(this.stacks[index]) {
      Column() {
      if (!this.state.ready) {
        if (!this.state.busy && this.state.error) { EmptyState({ title: '暂时无法打开记录', message: '请重试加载本地数据。', button: '重试', action: (): void => { this.state.start(this.getUIContext().getHostContext() as common.UIAbilityContext); } }).margin({ top: Theme.contentTop, left: Theme.pagePadding, right: Theme.pagePadding }) }
      }
      else if (index === 0) { HomePage({ scroller: this.pageScrollers[index], state: this.state, topInset: Theme.contentTop, bottomInset: Theme.homeContentBottom, active: this.tab === index, open: (k: string, id: string) => this.open(k, id), add: (k: string, parent: string) => this.edit(k, '', parent) }) }
      else if (index === 1) { CosPage({ scroller: this.pageScrollers[index], state: this.state, topInset: Theme.contentTop, bottomInset: Theme.contentBottom, projects: this.cosProjects, selection: (projects: boolean) => { this.cosProjects = projects; }, open: (k: string, id: string) => this.open(k, id), add: (k: string, parent: string) => this.edit(k, '', parent) }) }
      else if (index === 2) { EventsPage({ scroller: this.pageScrollers[index], state: this.state, topInset: Theme.contentTop, bottomInset: Theme.contentBottom, filter: this.eventFilter, open: (k: string, id: string) => this.open(k, id), add: (k: string, parent: string) => this.edit(k, '', parent) }) }
      else if (index === 3) { LibraryPage({ scroller: this.pageScrollers[index], state: this.state, topInset: Theme.contentTop, bottomInset: Theme.contentBottom, photos: this.libraryPhotos, selection: (photos: boolean) => { this.libraryPhotos = photos; }, open: (k: string, id: string) => this.open(k, id), add: (k: string, parent: string) => this.edit(k, '', parent) }) }
      else { MePage({ scroller: this.pageScrollers[index], state: this.state, topInset: Theme.contentTop, bottomInset: Theme.contentBottom, section: this.meSection, open: (k: string, id: string) => this.open(k, id), destructive: (kind: string) => this.destructive(kind) }) }
      }.width('100%').height('100%')
    }.mode(NavigationMode.Stack)
      .customNavContentTransition((_from: NavContentInfo, _to: NavContentInfo, operation: NavigationOperation) => {
        if (operation === NavigationOperation.POP) { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); }
        return undefined;
      })
      .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
      .titleBar(SystemCapability.titleBar(['首页', 'Cos', '漫展', '衣柜', '我的'][index], this.state.settings.effects, this.state.settings.materialLevel, index > 0 ? (): void => { this.titleSegment(index); } : undefined, this.rootMenus(index)))
      .hideToolBar(true)
      .width('100%').height('100%').backgroundColor(Theme.bg)
  }

  @Builder mainTabs() {
        HdsTabs({ controller: this.tabsController, index: this.tab }) {
          TabContent() { this.mainNavigation(0) }.tabBar(new BottomTabBarStyle(Icons.home, '首页')).accessibilityText('首页标签页')
          TabContent() { this.mainNavigation(1) }.tabBar(new BottomTabBarStyle(Icons.cos, 'Cos')).accessibilityText('Cos标签页')
          TabContent() { this.mainNavigation(2) }.tabBar(new BottomTabBarStyle(Icons.event, '漫展')).accessibilityText('漫展标签页')
          TabContent() { this.mainNavigation(3) }.tabBar(new BottomTabBarStyle(Icons.library, '衣柜')).accessibilityText('衣柜标签页')
          TabContent() { this.mainNavigation(4) }.tabBar(new BottomTabBarStyle(Icons.me, '我的')).accessibilityText('我的标签页')
        }.id('main-tabs').barPosition(BarPosition.End).barWidth(Math.min(360, this.viewportWidth - 32)).cachedMaxCount(5, TabsCacheMode.CACHE_LATEST_SWITCHED)
          .scrollable(false).vertical(false).barOverlap(true)
          .blurStrategy(this.state.settings.effects ? BlurStrategy.ENABLE : BlurStrategy.DISABLE)
          .barFloatingStyle(SystemCapability.tabs(this.state.settings.effects, this.state.settings.materialLevel))
          .onTabBarClick((index: number): void => {
            if (index === this.tab && this.stacks[index].size() === 0) {
              HapticService.confirm(this.state.settings.haptic);
              try { this.pageScrollers[index].scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } }); } catch (error) { console.warn('Page scroll-to-top failed: ' + String(error)); }
            }
          })
          .onChange((index: number) => { this.tab = index; this.outing = false; this.state.suspend(); HapticService.confirm(this.state.settings.haptic, this.state.settings.hapticLevel); })
              .height(LayoutPolicy.matchParent).width('100%').ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]).backgroundColor(Theme.bg).accessibilityText('首页、Cos、漫展、衣柜、我的五个标签页').onAreaChange((_, area: Area): void => { this.viewportWidth = Number(area.width); })
  }
  build() {
    HdsNavigation(this.detailStack) {
      this.mainTabs()
    }.mode(NavigationMode.Stack).hideTitleBar(true).hideToolBar(true)
      .navDestination(this.destination)
      .customNavContentTransition((_from: NavContentInfo, _to: NavContentInfo, operation: NavigationOperation) => {
        if (operation === NavigationOperation.POP) { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); }
        return undefined;
      })
      .width('100%').height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Theme.bg).overlay(this.loadingOverlay, { align: Alignment.Center })
      .bindSheet(this.importOpen, this.importSheet(), { height: SheetSize.LARGE, showClose: true, maskColor: Theme.scrim, blurStyle: BlurStyle.COMPONENT_ULTRA_THICK, onDisappear: () => { this.importOpen = false; } })
      .bindSheet(this.formOpen, this.form(), { height: SheetSize.LARGE, showClose: false, maskColor: Theme.scrim, blurStyle: BlurStyle.COMPONENT_ULTRA_THICK, onDisappear: () => { this.formOpen = false; } })
  }
}
