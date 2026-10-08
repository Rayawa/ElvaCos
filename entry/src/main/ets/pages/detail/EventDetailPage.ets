import { ProjectShot } from '../../model/Shot';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, PROJECT_STATUSES, PROJECT_LABELS } from '../../common/constants';
import { Theme } from '../../common/Theme';
import { AppState } from '../../model/ApplicationState';
import { EventRoute } from '../../model/EventRoute';
import { CosEvent, CosProject, ChecklistItem } from '../../model/Entities';
import { TeamMember } from '../../model/Planning';
import { CollectedEntry, entryTitle } from '../../model/CollectedEntry';
import { eventDateLabel, eventTimeLabel } from '../../model/Schedule';
import { DayModule, DayTimelineItem, eventTimeline, planShootingLabel, hasEventShots, dayTitle, dayNumber, availableDayModules, assembledDayModules, orderedDayModules, reminderState } from '../../model/DayMode';
import { StaggerEntrance } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { confirm } from '../../common/Confirm';
import { operationCommitted } from '../../model/OperationResult';
import { SheetHeader } from '../../component/SheetHeader';
import { HdsViewTabs } from '../../component/HdsViewTabs';
import { Icons } from '../../common/Icons';
import { SectionHeading, StatusPill, FactRow, EmptyState } from '../../component/Surfaces';
import { EntryCollectionView } from '../../component/EntryCollectionView';
import { ManagedImage } from '../../component/ManagedImage';
import { ProjectCard } from '../../component/ProjectCard';

@ComponentV2
export struct EventDetail {
  @Require @Param state: AppState;
  @Require @Param route: EventRoute;
  @Param event: CosEvent = new CosEvent();
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Event open: (kind: string, id: string) => void = () => {};
  @Local shotError: string = '';
  @Event openShot: (projectId: string, shotId: string) => void = () => {};
  @Event openAsset: (id: string, projectId: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event back: () => void = () => {};
  @Local linking: boolean = false;
  @Local configuring: boolean = false;
  @Local recording: boolean = false;
  @Local recordKind: number = 0;
  @Local recordError: string = '';
  @Local recordText: string = '';
  @Local viewing: boolean = false;
  @Local credential: CollectedEntry = new CollectedEntry();
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  private scroller: Scroller = new Scroller();
  private displayedIndex: number = 0;
  private restoring: boolean = true;
  private measured: boolean = false;
  private restoreTimer: number = -1;
  private offsetIndex(): number { return this.route.dayMode ? 4 + this.route.section : this.route.section; }
  aboutToAppear(): void { this.displayedIndex = this.offsetIndex(); this.restoreScroll(); }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); } }
  @Monitor('route.section', 'route.dayMode')
  private viewChanged(): void {
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; }
    this.measured = false; this.restoring = true;
    this.displayedIndex = this.offsetIndex(); this.restoreScroll();
  }
  @Monitor('route.restoreVersion')
  private contextChanged(): void { this.restoreScroll(); }
  private restoreScroll(): void {
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoring = true;
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedIndex], animation: false }); this.restoring = false;
    }, 0);
  }
  private projects(): CosProject[] { return this.state.projects.filter((project: CosProject) => project.eventId === this.event.id); }
  private credentials(): CollectedEntry[] {
    return this.state.entries.filter((entry: CollectedEntry) => entry.scopeKind === 'event' && entry.scopeId === this.event.id && ['ticket', 'map', 'link'].includes(entry.kind));
  }
  private modules(): DayModule[] {
    return assembledDayModules(availableDayModules(this.event, this.state.projects, this.state.entries, this.state.team, this.state.clockTime, hasEventShots(this.event.id, this.state.projects, this.state.readinessPlans)), this.state.dayModules, this.route.section);
  }
  private async associate(project: CosProject): Promise<void> {
    const copy = JSON.parse(JSON.stringify(project)) as CosProject; copy.eventId = this.event.id;
    if (await this.state.saveProject(copy)) { this.linking = false; }
  }
  private async openLink(url: string): Promise<void> {
    try { await (this.getUIContext().getHostContext() as common.UIAbilityContext).openLink(url, { appLinkingOnly: false }); }
    catch (error) { this.state.reportError('无法打开链接，可复制后手动打开'); }
  }
  private async copyContact(member: TeamMember): Promise<void> {
    try { await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, member.notes)); this.state.reportNotice('已复制 ' + member.name + ' 的备注 / 联系方式'); }
    catch (error) { this.state.reportError('复制失败，请重试或长按备注复制'); }
  }
  private recordFor(project: CosProject): void {
    this.recording = false;
    if (this.recordKind === 0) { this.edit('expense', '', project.id); }
    else { this.state.importPhotos(project.id); }
  }
  private async captureText(): Promise<void> {
    this.recordError = '';
    const result = await this.state.captureEntry(this.recordText, 'event', this.event.id);
    if (operationCommitted(result)) { this.recordText = ''; }
    else { this.recordError = result.detail || '收录未保存，请重试'; }
  }
  private async captureImage(): Promise<void> {
    this.recordError = '';
    const result = await this.state.captureEntryImage('event', this.event.id);
    if (!operationCommitted(result)) { this.recordError = result.detail || '图片未收录，请重试'; }
  }
  private async canCloseSheet(): Promise<boolean> {
    if (this.state.busy) { return false; }
    if (this.recording && this.recordText.trim()) {
      if (!await confirm(this.getUIContext(), '放弃这条未保存的收录？', '取消可继续输入；已保存的收录会保留。', '放弃输入')) { return false; }
      this.recordText = '';
    }
    return true;
  }
  private closeSheets(): void { this.linking = false; this.configuring = false; this.recording = false; this.viewing = false; }
  private async requestClose(): Promise<void> { if (await this.canCloseSheet()) { this.closeSheets(); } }
  private sheetOptions(): SheetOptions {
    const options = appSheetOptions((): void => { this.closeSheets(); }, this.sheetEntrance, this.getUIContext());
    options.onWillDismiss = (action: DismissSheetAction): void => { this.canCloseSheet().then((allowed: boolean): void => { if (allowed) { action.dismiss(); } }); };
    return options;
  }
  @Builder linkSheet() {
    Column({ space: 14 }) {
      SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: '关联已有计划', hint: '只列出尚未关联活动的计划', close: (): void => { this.linking = false; } })
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.state.projects.filter((project: CosProject) => !project.eventId), (project: CosProject) => {
            Button(project.name).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.state.busy)
              .onClick((): void => { this.associate(project); })
          }, (project: CosProject) => project.id)
          if (!this.state.projects.some((project: CosProject) => !project.eventId)) { Text('没有待关联的计划，可以为本次活动新建计划。').fontColor(Theme.muted) }
        }.width('100%')
      }.layoutWeight(1).width('100%')
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder configurationSheet() {
    Column({ space: 16 }) {
      SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: '今天模式模块', hint: '两段固定；有对应内容的模块才会显示', close: (): void => { this.configuring = false; } })
      Scroll() {
        Column({ space: 16 }) {
          ForEach([0, 1], (section: number) => {
            SectionHeading({ title: section === 0 ? '出发前' : '现场' })
            ForEach(orderedDayModules(this.state.dayModules, section), (module: DayModule, index: number) => {
              Row({ space: 8 }) {
                Checkbox().height(64).select(this.state.dayModules[module.id]?.enabled !== false).enabled(!this.state.settingsBusy)
                  .onChange((enabled: boolean): void => { this.state.configureDayModule(module.id, enabled); }).accessibilityText(module.label + '模块开关')
                Text(module.label).layoutWeight(1).fontColor(Theme.ink)
                Button('上移').constraintSize({ minHeight: 64 }).enabled(index > 0 && !this.state.settingsBusy)
                  .onClick((): void => { this.state.configureDayModule(module.id, undefined, -1); }).accessibilityText(module.label + '上移')
                Button('下移').constraintSize({ minHeight: 64 }).enabled(index < orderedDayModules(this.state.dayModules, section).length - 1 && !this.state.settingsBusy)
                  .onClick((): void => { this.state.configureDayModule(module.id, undefined, 1); }).accessibilityText(module.label + '下移')
              }.width('100%').constraintSize({ minHeight: 64 })
            }, (module: DayModule) => module.id)
          })
        }.width('100%')
      }.layoutWeight(1).width('100%')
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder recordSheet() {
    Column({ space: 16 }) {
      SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: this.recordKind === 0 ? '记一笔 · 选择计划' : this.recordKind === 1 ? '收录一条' : '传照片 · 选择计划', close: (): void => { this.requestClose(); } })
      Scroll() {
        Column({ space: 12 }) {
          if (this.recordKind === 1) {
            TextArea({ text: this.recordText, placeholder: '粘贴链接或写一句话' }).height(120).enabled(!this.state.busy).onChange((value: string): void => { this.recordText = value; })
            if (this.recordError) { Text(this.recordError).id('day-record-error').fontSize(14).fontColor(Theme.danger).accessibilityText(this.recordError) }
            Button('收录').width('100%').constraintSize({ minHeight: 64 }).enabled(!this.state.busy && Boolean(this.recordText.trim())).onClick((): void => { this.captureText(); })
            Button('存一张图').width('100%').constraintSize({ minHeight: 64 }).enabled(!this.state.busy).onClick((): void => { void this.captureImage(); })
            Text('直接归到本次活动，标题和类型可以以后补充。').fontColor(Theme.muted)
          } else {
            ForEach(this.projects(), (project: CosProject) => {
              Button(project.name).width('100%').constraintSize({ minHeight: 64 }).enabled(!this.state.busy).onClick((): void => { this.recordFor(project); })
            }, (project: CosProject) => project.id)
            if (!this.projects().length) { EmptyState({ title: '先为本次活动建立计划', message: '花费和照片都属于具体计划。', button: '新建计划', action: (): void => { this.recording = false; this.edit('eventProject', '', this.event.id); } }) }
          }
        }.width('100%')
      }.layoutWeight(1).width('100%')
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder credentialSheet() {
    Column({ space: 12 }) {
      SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: entryTitle(this.credential), close: (): void => { this.viewing = false; } })
      Scroll() {
        Column({ space: 12 }) {
          if (this.credential.localPath) { ManagedImage({ sourcePath: this.credential.localPath, large: true, fit: ImageFit.Contain, label: entryTitle(this.credential) }).width('100%').height(480) }
          if (this.credential.text) { Text(this.credential.text).fontSize(18).fontColor(Theme.ink).copyOption(CopyOptions.LocalDevice) }
          if (this.credential.url) { Text(this.credential.url).fontColor(Theme.muted).copyOption(CopyOptions.LocalDevice)
            Button('打开链接').width('100%').constraintSize({ minHeight: 64 }).onClick((): void => { this.openLink(this.credential.url); }) }
          if (!this.credential.localPath && this.credential.kind !== 'link') { Text('没有本机图片；可在活动的收录区补充或修复。').fontColor(Theme.muted) }
        }.width('100%')
      }.layoutWeight(1).width('100%')
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder overview() {
    Column({ space: 14 }) {
      Text(this.event.name).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
      StatusPill({ label: this.event.ticketPurchased ? '门票已准备' : '门票待确认' })
      FactRow({ label: '类型', value: this.event.eventType })
      FactRow({ label: '日期', value: eventDateLabel(this.event) })
      FactRow({ label: '时间', value: eventTimeLabel(this.event) })
      FactRow({ label: '城市', value: this.event.city })
      FactRow({ label: '场馆', value: this.event.venue || '地点待定', copyable: true })
      if (this.event.url) { Button('打开官方链接').constraintSize({ minHeight: 48 }).onClick((): void => { this.openLink(this.event.url); }) }
      if (this.event.notes) { FactRow({ label: '备注', value: this.event.notes }) }
      Button('进入今天模式').width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.section = 0; this.route.dayMode = true; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder plans() {
    Column({ space: 14 }) {
      SectionHeading({ title: '本场计划', trailing: this.projects().length + ' 份' })
      Row({ space: 8 }) {
        Button('新建计划').constraintSize({ minHeight: 48 }).onClick((): void => { this.edit('eventProject', '', this.event.id); })
        Button('关联已有').constraintSize({ minHeight: 48 }).enabled(!this.state.busy).onClick((): void => { this.linking = true; })
      }
      ForEach(this.projects(), (project: CosProject) => { ProjectCard({ state: this.state, project: project, open: (): void => this.open('project', project.id) }) }, (project: CosProject) => project.id)
      if (!this.projects().length) { Text('新建计划会自动带入本次活动；也可以关联已有计划。').fontColor(Theme.muted) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder reminders() {
    Column({ space: 14 }) {
      SectionHeading({ title: '活动提醒' })
      Text(reminderState(this.event, this.state.clockTime)).fontSize(17).fontColor(Theme.ink)
      if (this.event.reminderMinutes >= 0) { FactRow({ label: '用户选择', value: this.event.reminderMinutes === 0 ? '开始时' : '提前 ' + this.event.reminderMinutes + ' 分钟' }) }
      Button('编辑提醒').constraintSize({ minHeight: 48 }).onClick((): void => { this.edit('event', this.event.id, ''); })
      Button('通知设置').constraintSize({ minHeight: 48 }).onClick((): void => { this.state.openReminderSettings(); })
      Button('添加到系统日历').constraintSize({ minHeight: 48 }).enabled(!this.state.busy).onClick((): void => { this.state.addEventToCalendar(this.event); })
      Text('在系统确认页选择账户。已添加的日程由系统日历独立管理；取消确认不会添加。').fontSize(14).fontColor(Theme.muted)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder dayHeader() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Button('返回').constraintSize({ minHeight: 64, minWidth: 64 }).onClick((): void => { this.back(); }).accessibilityText('返回来源页面')
        Text(dayTitle(this.event, this.state.clockTime)).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Theme.ink).layoutWeight(1)
        Select([{ value: '记一笔' }, { value: '收录一条' }, { value: '传照片' }]).value('记').height(64).constraintSize({ minWidth: 64 })
          .onSelect((index: number): void => { this.recordKind = index; this.recordError = ''; this.recording = true; }).accessibilityText('记一笔、收录一条或传照片')
      }.width('100%')
      Text((this.event.venue || this.event.city || '地点待定') + ' · ' + eventTimeLabel(this.event) + (dayNumber(this.event, this.state.clockTime) ? ' · ' + dayNumber(this.event, this.state.clockTime) : '')).fontSize(15).fontColor(Theme.muted).width('100%')
    }.padding({ top: 16, left: Theme.pagePadding, right: Theme.pagePadding, bottom: 12 }).width('100%').backgroundColor(Theme.bg)
  }
  @Builder packing(project: CosProject) {
    Column({ space: 10 }) {
      Text(project.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
      Text('已装包 ' + this.state.readiness(project.id).pack.packed + ' / ' + this.state.readiness(project.id).pack.total + ' 件').fontSize(14).fontColor(Theme.muted)
      if (!this.state.checklist.some((item: ChecklistItem) => item.projectId === project.id)) {
        Button('建立打包清单').constraintSize({ minHeight: 64 }).onClick((): void => { this.open('packing', project.id); })
      }
      ForEach(this.state.checklist.filter((item: ChecklistItem) => item.projectId === project.id).sort((a: ChecklistItem, b: ChecklistItem) => a.sortOrder - b.sortOrder), (item: ChecklistItem) => {
        Button((item.done ? '✓ 已装包 · ' : '○ 未装包 · ') + item.label).width('100%').constraintSize({ minHeight: 64 }).fontSize(18)
          .fontColor(item.done ? Theme.muted : Theme.ink).backgroundColor(Theme.surface).enabled(!this.state.busy)
          .onClick((): void => { this.state.toggleChecklist(item); }).accessibilityText(item.label + (item.done ? '，已装包，点击改为未装包' : '，未装包，点击确认装包'))
        if (item.assetId) { Button((this.state.assets.find((asset) => asset.id === item.assetId)?.location || '未记录位置') + ' · ' + (this.state.assets.find((asset) => asset.id === item.assetId)?.status ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.state.assets.find((asset) => asset.id === item.assetId)!.status)] : '装备已不存在')).fontColor(Theme.muted).fontSize(14).constraintSize({ minHeight: 64 }).width('100%').onClick((): void => { this.openAsset(item.assetId, project.id); }).accessibilityText('查看 ' + item.label + ' 的装备位置与状态') }
      }, (item: ChecklistItem) => item.id)
      Button('打开出门清单').constraintSize({ minHeight: 64 }).onClick((): void => { this.open('outing', project.id); })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  private async toggleShot(shot: ProjectShot): Promise<void> {
    this.shotError = ''; const result = await this.state.toggleShot(shot.id, shot.projectId, shot.done);
    if (!operationCommitted(result)) { this.shotError = this.state.error || '拍摄勾选未保存，请重试'; }
  }
  @Builder shots(project: CosProject) {
    Button(project.name + ' · 已拍 ' + this.state.readiness(project.id).shots.done + ' / ' + this.state.readiness(project.id).shots.total + ' 项').constraintSize({ minHeight: 64 }).width('100%').fontSize(18)
      .onClick((): void => { this.openShot(project.id, ''); })
    ForEach(this.state.readiness(project.id).shots.items, (shot: ProjectShot) => {
      Column({ space: 8 }) {
        Button((shot.done ? '✓ 已拍 · ' : '拍摄后勾选 · ') + shot.title).constraintSize({ minHeight: 64 }).width('100%').fontSize(18).enabled(!this.state.busy && !this.state.staleScopes.length)
          .onClick((): void => { void this.toggleShot(shot); }).accessibilityText((shot.done ? '取消已拍 ' : '标记已拍 ') + shot.title)
        if (shot.referenceId) { Button('查看这条拍摄参考').constraintSize({ minHeight: 64 }).width('100%').onClick((): void => { this.open('reference', shot.referenceId); }) }
        Button('查看所属计划拍摄事项').constraintSize({ minHeight: 64 }).width('100%').onClick((): void => { this.openShot(project.id, shot.id); }).accessibilityText('在计划照片中查看 ' + shot.title)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }, (shot: ProjectShot) => shot.id)
  }
  @Builder dayModule(module: DayModule) {
    Column({ space: 14 }) {
      SectionHeading({ title: module.label })
      if (module.id === 'packing') { ForEach(this.projects(), (project: CosProject) => { this.packing(project) }, (project: CosProject) => project.id) }
      else if (module.id === 'credentials') {
        ForEach(this.credentials(), (entry: CollectedEntry) => {
          Button() {
            Row({ space: 12 }) {
              if (entry.thumbnailPath || entry.localPath) { ManagedImage({ sourcePath: entry.thumbnailPath || entry.localPath, label: entryTitle(entry), ratio: 1 }).width(64).height(64) }
              Text(entryTitle(entry)).fontSize(18).layoutWeight(1).fontColor(Theme.ink)
            }.width('100%').padding(8)
          }.width('100%').constraintSize({ minHeight: 64 }).backgroundColor(Theme.tint).onClick((): void => { this.credential = entry; this.viewing = true; }).accessibilityText('打开凭证 ' + entryTitle(entry))
        }, (entry: CollectedEntry) => entry.id)
      } else if (module.id === 'people') {
        ForEach(this.projects(), (project: CosProject) => {
          ForEach(this.state.team.filter((member: TeamMember) => member.projectId === project.id), (member: TeamMember) => {
            Text(project.name + ' · ' + member.role + ' · ' + member.name).fontSize(18).fontColor(Theme.ink)
            if (member.notes) { Text(member.notes).fontColor(Theme.muted).copyOption(CopyOptions.LocalDevice)
              Button('复制备注 / 联系方式').constraintSize({ minHeight: 64 }).onClick((): void => { this.copyContact(member); }) }
          }, (member: TeamMember) => member.id)
        }, (project: CosProject) => project.id)
      } else if (module.id === 'plans') {
        ForEach(this.projects(), (project: CosProject) => {
          Button(project.name + ' · ' + PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)] + '\n' + planShootingLabel(project, this.state.events)).width('100%').constraintSize({ minHeight: 64 }).fontSize(18).onClick((): void => { this.open('project', project.id); })
        }, (project: CosProject) => project.id)
      } else if (module.id === 'shots') {
        if (this.shotError) { Text(this.shotError).fontSize(17).fontColor(Theme.danger) }
        ForEach(this.projects().filter((project: CosProject) => this.state.readiness(project.id).shots.total > 0), (project: CosProject) => { this.shots(project) }, (project: CosProject) => project.id)
      } else if (module.id === 'timeline') {
        ForEach(eventTimeline(this.event, this.state.projects), (item: DayTimelineItem) => {
          if (item.projectId) { Button((item.date || '日期待定') + ' · ' + item.time + ' · ' + item.label).id('day-timeline:' + item.id).constraintSize({ minHeight: 64 }).width('100%').fontSize(18)
            .onClick((): void => { this.open('project', item.projectId); }).accessibilityText('查看计划，' + (item.date || '日期待定') + '，' + item.time + '，' + item.label) }
          else { Text(item.date + ' · ' + item.time + ' · ' + item.label).id('day-timeline:' + item.id).fontSize(18).fontColor(Theme.ink) }
        }, (item: DayTimelineItem) => item.id)
      }
      else if (module.id === 'wrapup') { Text('今天结束了？选好所属计划后导入照片。').fontSize(18).fontColor(Theme.ink)
        Button('导入照片').constraintSize({ minHeight: 64 }).onClick((): void => { this.recordKind = 2; this.recording = true; }) }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
  }
  @Local availableWidth: number = 360;
  build() {
    Column() {
      if (this.route.dayMode) { this.dayHeader() }
      HdsViewTabs({ labels: this.route.dayMode ? ['出发前', '现场'] : ['概览', '本场计划', '收录', '提醒'],
        icons: this.route.dayMode ? [Icons.library, Icons.event] : [Icons.home, Icons.plan, Icons.importPhoto, Icons.event],
        selectedIndex: this.route.section, componentId: 'event-view-tabs', effects: this.state.settings.effects,
        materialLevel: this.state.settings.materialLevel, availableWidth: this.availableWidth,
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        changed: (index: number): void => { this.route.section = index; }, content: (): void => { this.viewContent(); } }).layoutWeight(1)
    }.width('100%').height('100%').onAreaChange((_, area: Area): void => { this.availableWidth = Number(area.width); })
  }
  @Builder viewContent() {
    Column() {
      if (!this.route.dayMode && this.route.section === 2) {
        EntryCollectionView({ state: this.state, route: this.route.entries, componentId: 'event-entries-scroll', restoreVersion: this.route.restoreVersion,
          topInset: Theme.detailTop, bottomInset: Theme.contentBottom, horizontalPadding: Theme.pagePadding, open: this.open }).layoutWeight(1)
      } else {
      Scroll(this.scroller) {
        Column({ space: Theme.sectionSpacing }) {
          if (!this.route.dayMode) {
            Blank().height(Theme.detailTop).width('100%')
            if (this.route.section === 0) { this.overview() }
            else if (this.route.section === 1) { this.plans() }
            else { this.reminders() }
          } else {
            ForEach(this.modules(), (module: DayModule) => { this.dayModule(module) }, (module: DayModule) => module.id)
            if (!this.modules().length) { Text('这一段暂时没有内容。可以在详情中关联计划、收录凭证，或开启已关闭的模块。').fontSize(17).fontColor(Theme.muted) }
            Button('模块开关与排序').constraintSize({ minHeight: 64 }).onClick((): void => { this.configuring = true; })
            Button('返回活动详情').constraintSize({ minHeight: 64 }).onClick((): void => { this.route.section = 0; this.route.dayMode = false; })
          }
          Blank().height(Theme.contentBottom).width('100%')
        }.width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).padding({ left: Theme.pagePadding, right: Theme.pagePadding }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .onAreaChange((_, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreScroll(); } })
        .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offsets[this.displayedIndex] = this.scroller.currentOffset().yOffset; } })
      }
    }.width('100%').height('100%')
      .bindSheet(this.linking || this.configuring || this.recording || this.viewing, this.activeSheet(), this.sheetOptions())
  }
  @Builder activeSheet() {
    if (this.linking) { this.linkSheet() }
    else if (this.configuring) { this.configurationSheet() }
    else if (this.recording) { this.recordSheet() }
    else { this.credentialSheet() }
  }
}
