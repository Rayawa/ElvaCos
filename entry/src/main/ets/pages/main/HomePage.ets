import { ContextRow } from '../../component/ContextRow';
import { StatusPill } from '../../component/Surfaces';
import { WorkCard } from '../../component/WorkCard';
import { ProjectWork, recentWork } from '../../model/ProjectWork';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { MainEntranceSession } from '../../common/motion';
import { CosProject, CosEvent } from '../../model/Entities';
import { TaskQueueItem } from '../../model/TaskQueue';
import { HomeTaskRow, homeCandidates, advanceHomeSnapshot, reconcileHomeRows, homeTaskCapacity, visiblePreparationUndos } from '../../model/HomeSummary';
import { nextPlan } from '../../model/Rules';
import { daysUntil, displayName } from '../../common/format';
import { eventEnd } from '../../model/Schedule';
import { dayTitle } from '../../model/DayMode';
import { SectionHeading, EmptyState } from '../../component/Surfaces';
import { ManagedImage } from '../../component/ManagedImage';

@ComponentV2
export struct HomePage {
  @Require @Param state: AppState;
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = false;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Event openTask: (item: TaskQueueItem) => void = () => {};
  @Local snapshot: TaskQueueItem[] = [];
  @Local taskError: string = '';
  @Local viewportHeight: number = 800;
  @Local nextHeight: number = 150;
  @Local recentHeight: number = 160;
  @Local rowHeight: number = 64;
  private snapshotDate: string = '';
  aboutToAppear(): void { this.capture(); }
  @Monitor('state.taskQueue', 'state.localDate', 'state.clockTime')
  queueChanged(): void {
    // Keep the visit's order after a completion or a child-page return.
    // A new date (or the first data load) starts a new summary.
    if (this.snapshotDate !== this.state.localDate || !this.snapshot.length) { this.capture(); return; }
    const next = advanceHomeSnapshot(this.snapshot, this.state.taskQueue, this.state.preparationUndos, this.state.clockTime);
    if (next.length !== this.snapshot.length || next.some((item: TaskQueueItem, index: number) => item.id !== this.snapshot[index]?.id)) { this.snapshot = next; }
  }
  private capture(): void { this.snapshotDate = this.state.localDate; this.snapshot = homeCandidates(this.state.taskQueue); }
  @Computed
  get rows(): HomeTaskRow[] {
    return reconcileHomeRows(this.snapshot, this.state.taskQueue,
      visiblePreparationUndos(this.state.preparationUndos, this.state.preparationTasks, this.state.projects, this.state.clockTime, this.state.busy || !!this.state.staleScopes.length), this.state.clockTime)
      .slice(0, Math.min(2, homeTaskCapacity(this.viewportHeight, this.topInset, this.bottomInset, this.nextHeight, this.recentHeight, this.rowHeight)));
  }
  @Computed
  get upcoming(): CosProject | undefined { return nextPlan(this.state.projects, this.state.events, this.state.localDate); }
  private nextEvent(): CosEvent | undefined {
    return this.state.events.filter((event: CosEvent) => event.dateMode !== 'pending' && eventEnd(event) >= this.state.localDate && event.status !== 'Attended').sort((a: CosEvent, b: CosEvent) => a.date.localeCompare(b.date))[0];
  }
  private recent(): ProjectWork | undefined { return recentWork(this.state.workCards, this.state.localDate); }
  private planDateLabel(project: CosProject): string {
    const readiness = this.state.readiness(project.id);
    if (!readiness.date) { return '日期待定'; }
    return readiness.date;
  }
  private planDateContext(project: CosProject): string {
    const readiness = this.state.readiness(project.id);
    if (!readiness.date) { return ''; }
    if (readiness.dateFromEvent) { return '活动日期'; }
    const days = daysUntil(readiness.date);
    return days > 0 ? days + ' 天后' : days === 0 ? '今天' : '日期已过';
  }
  private versionLabel(project: CosProject): string {
    return this.state.characterName(project.characterId) + (project.variantId ? ' / ' + (this.state.variants.find((variant) => variant.id === project.variantId)?.name || '版本已不存在') : '');
  }
  private async complete(row: HomeTaskRow): Promise<void> {
    this.taskError = '';
    const result = await this.state.completeHomePreparation(row.item.focusId, row.item.projectId);
    if (result.status === 'failed') { this.taskError = result.detail || '完成状态未保存，请重试'; }
  }
  private async undo(row: HomeTaskRow): Promise<void> {
    if (!row.undo) { return; }
    this.taskError = '';
    const result = await this.state.undoHomePreparation(row.undo.id);
    if (result.status === 'failed') { this.taskError = result.detail || '撤销未保存，请重试'; }
  }
  @Builder planHero(project: CosProject) {
    Button() {
      Row({ space: 12 }) {
        if (this.state.characters.find((character) => character.id === project.characterId)?.cover) {
          ManagedImage({ sourcePath: this.state.characters.find((character) => character.id === project.characterId)?.cover || '', label: this.versionLabel(project) + '封面' }).width(64).height(80).borderRadius(12)
        } else { Text(this.state.characterName(project.characterId).slice(0, 1)).width(64).height(80).textAlign(TextAlign.Center).fontSize(28).fontColor(Theme.accent).backgroundColor(Theme.tint).borderRadius(12).accessibilityLevel('no') }
        Column({ space: 8 }) {
          Text(displayName(project.name)).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 8 }) {
            if (this.planDateContext(project)) { StatusPill({ label: this.planDateContext(project) }) }
            Text(this.planDateLabel(project)).id('home-plan-date').fontSize(14).fontColor(Theme.muted)
          }
          if (this.state.readiness(project.id).hint) {
            ContextRow({ label: this.state.readiness(project.id).hint!.label, text: displayName(this.state.readiness(project.id).hint!.text) })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(16)
    }.id('home-next-plan').width('100%').type(ButtonType.Normal).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
      .onClick((): void => { this.open('project', project.id); }).accessibilityText('打开计划 ' + project.name + '，' + this.versionLabel(project) + '，' + this.planDateLabel(project))
  }
  @Builder next() {
    Column({ space: 8 }) {
      SectionHeading({ title: '接下来' })
      if (this.state.todayEvents.length) {
        Button(dayTitle(this.state.todayEvents[0], this.state.clockTime) + (this.state.todayEvents.length > 1 ? '，还有 ' + (this.state.todayEvents.length - 1) + ' 个' : ''))
          .id('home-day-entry').width('100%').constraintSize({ minHeight: 64 }).fontSize(18).fontColor(Theme.accent).backgroundColor(Theme.tint)
          .onClick((): void => { this.open('dayEvent', this.state.todayEvents[0]?.id || ''); })
      }
      if (this.upcoming) { this.planHero(this.upcoming!) }
      else if (!this.state.todayEvents.length && this.nextEvent()) {
        Button(displayName(this.nextEvent()?.name || '')).width('100%').constraintSize({ minHeight: 48 })
          .onClick((): void => { this.open('event', this.nextEvent()?.id || ''); })
      } else if (!this.state.todayEvents.length) { Button('新建计划').constraintSize({ minHeight: 48 }).onClick((): void => { this.add('project', ''); }) }
    }.id('home-next').width('100%').alignItems(HorizontalAlign.Start)
      .onAreaChange((_, area: Area): void => { this.nextHeight = Number(area.height); })
  }
  @Builder taskRow(row: HomeTaskRow) {
    Column() {
      Row({ space: 8 }) {
        if (row.undo) {
          Button('撤销').id('home-undo:' + row.item.focusId).constraintSize({ minWidth: 48, minHeight: 48 }).fontSize(14).fontColor(Theme.accent).backgroundColor(Theme.tint)
            .enabled(!this.state.busy && !this.state.staleScopes.length).onClick((): void => { this.undo(row); })
            .accessibilityText('撤销完成 ' + row.undo.label)
        } else if (row.item.source === 'preparation') {
          Button('○').id('home-complete:' + row.item.focusId).constraintSize({ minWidth: 48, minHeight: 48 }).fontColor(Theme.accent).backgroundColor(Theme.bg)
            .enabled(!this.state.busy && !this.state.staleScopes.length).onClick((): void => { this.complete(row); })
            .accessibilityText(row.item.title + '，未完成，标记完成')
        }
        Button() {
          Column({ space: 3 }) {
            ContextRow({ label: row.undo ? '已完成' : row.item.kind === 'waiting' ? '在途' : row.item.group === 'overdue' ? '逾期' : '待办', text: displayName(row.item.title), prominent: true })
            Text(row.undo ? this.state.staleScopes.length ? '已保存，显示待刷新' : '10 秒内可撤销' : displayName(row.item.projectName)).fontSize(14).fontColor(Theme.muted)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.id('home-task-open:' + row.item.focusId).layoutWeight(1).type(ButtonType.Normal).constraintSize({ minHeight: 48 }).backgroundColor(Theme.surface)
          .onClick((): void => { this.openTask(row.item); }).accessibilityText('打开事项 ' + row.item.title + '，所属计划 ' + row.item.projectName + (row.undo ? '，已完成' : '，' + row.item.detail))
      }.width('100%').padding({ left: 8, right: 8, top: 4, bottom: 4 }).constraintSize({ minHeight: 56 }).backgroundColor(Theme.surface).borderRadius(12)
        .onAreaChange((_, area: Area): void => { this.rowHeight = Math.max(this.rowHeight, Number(area.height) + 8); })
    }.id('home-task:' + row.item.focusId).width('100%').height(row.retired ? 0 : undefined).margin({ bottom: row.retired ? 0 : 8 }).opacity(row.retired ? 0 : 1).clip(true)
      .animation({ duration: this.state.settings.effects ? 180 : 0, curve: Curve.EaseOut })
      .hitTestBehavior(row.retired ? HitTestMode.None : HitTestMode.Default).accessibilityLevel(row.retired ? 'no-hide-descendants' : 'auto')
  }
  @Builder tasks() {
    Column() {
      Row({ space: 12 }) {
        Text('在途与待办').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.muted).layoutWeight(1)
        Button('全部待办 ' + this.state.taskQueue.length + ' 项').id('home-all-tasks').constraintSize({ minHeight: 48 }).fontSize(14)
          .fontColor(Theme.muted).backgroundColor(Color.Transparent).onClick((): void => { this.open('tasks', 'all'); })
      }.width('100%').margin({ bottom: 8 })
      if (this.taskError) { Text(this.taskError).id('home-task-error').fontSize(16).fontColor(Theme.accent).margin({ bottom: 8 }).accessibilityText(this.taskError) }
      ForEach(this.rows, (row: HomeTaskRow) => { this.taskRow(row) }, (row: HomeTaskRow) => row.key)
      if (!this.rows.some((row: HomeTaskRow) => !row.retired)) { Text('当前摘要已处理；未定期和其他事项可在全部待办查看。').fontSize(14).fontColor(Theme.muted).margin({ bottom: 8 }) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder recentSection() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text('最近').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.muted).layoutWeight(1)
        Button('搜索').id('home-search').constraintSize({ minWidth: 48, minHeight: 48 }).fontSize(14).fontColor(Theme.muted)
          .backgroundColor(Color.Transparent).onClick((): void => { this.open('search', 'all'); }).accessibilityText('打开全局搜索')
      }.width('100%')
      if (this.recent()) { WorkCard({ work: this.recent()!, compact: true, open: (): void => { this.open('project', this.recent()?.value.projectId || ''); } }) }
      else { Text('完成计划或整理成片后，在这里回看。').fontSize(14).fontColor(Theme.muted) }
      Row({ space: 12 }) {
        Button('记一笔').layoutWeight(1).fontSize(16).constraintSize({ minHeight: 48 }).fontColor(Theme.ink).backgroundColor(Theme.surface)
          .onClick((): void => { this.add('expense', ''); })
        Button() {
          Column({ space: 2 }) {
            Text('收录一条').fontSize(16).fontColor(Theme.ink)
            if (this.state.untriagedEntries.length) { Text('未归位 ' + this.state.untriagedEntries.length).fontSize(12).fontColor(Theme.muted) }
          }.padding({ top: 6, bottom: 6 })
        }.id('home-inbox').layoutWeight(1).constraintSize({ minHeight: 48 }).backgroundColor(Theme.surface)
          .onClick((): void => { this.open('inbox', 'global'); })
      }.width('100%')
      Button() {
        Row({ space: 12 }) {
          Text('本月已记录支出 ¥' + (this.state.monthSpendingCents / 100).toFixed(2)).fontSize(14).fontColor(Theme.muted).layoutWeight(1)
          Text('花费统计 ›').fontSize(14).fontColor(Theme.muted)
        }.width('100%')
      }.id('home-expenses').width('100%').type(ButtonType.Normal).constraintSize({ minHeight: 48 }).backgroundColor(Color.Transparent)
        .onClick((): void => { this.open('expenseStats', 'all'); })
        .accessibilityText('本月已记录支出 ' + (this.state.monthSpendingCents / 100).toFixed(2) + ' 元，打开花费统计')
    }.id('home-recent').width('100%').alignItems(HorizontalAlign.Start)
      .onAreaChange((_, area: Area): void => { this.recentHeight = Number(area.height); })
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        Blank().height(this.topInset).width('100%')
        if (!this.state.projects.length && !this.state.events.length && !this.state.assets.length && !this.state.characters.length && !this.state.entries.length) {
          EmptyState({ title: '从一次想出的角色开始', message: '建立计划，添加准备任务，再安排活动和整理照片。', button: '新建计划', action: (): void => { this.add('project', ''); } })
          Row({ space: 12 }) {
            Button('先收录一个想法').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('inbox', 'global'); })
            Button('搜索').id('home-search').constraintSize({ minWidth: 48, minHeight: 48 }).onClick((): void => { this.open('search', 'all'); }).accessibilityText('打开全局搜索')
          }
        } else { this.next(); Blank().height(24); this.tasks(); Blank().height(24); this.recentSection() }
        Blank().height(this.bottomInset).width('100%')
      }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).alignItems(HorizontalAlign.Start)
    }.id('home-scroll').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .onAreaChange((_, area: Area): void => { this.viewportHeight = Number(area.height); })
  }
}
