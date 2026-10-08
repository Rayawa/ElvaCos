import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { MainEntranceSession } from '../../common/motion';
import { CosProject, CosEvent } from '../../model/Entities';
import { TaskQueueItem } from '../../model/TaskQueue';
import { eventEnd } from '../../model/Schedule';
import { dayTitle } from '../../model/DayMode';
import { SectionHeading, EmptyState } from '../../component/Surfaces';
import { ProjectCard } from '../../component/ProjectCard';

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
  private recentPlans(): CosProject[] {
    return this.state.projects.filter((project: CosProject) => this.state.readiness(project.id).active).sort((a: CosProject, b: CosProject) => (this.state.readiness(a.id).date || '9999').localeCompare(this.state.readiness(b.id).date || '9999')).slice(0, 3);
  }
  private nextEvent(): CosEvent | undefined {
    return this.state.events.filter((event: CosEvent) => event.dateMode !== 'pending' && eventEnd(event) >= this.state.localDate && event.status !== 'Attended').sort((a: CosEvent, b: CosEvent) => a.date.localeCompare(b.date))[0];
  }
  private summaryItems(): TaskQueueItem[] { return this.state.waitingItems.concat(this.state.actionItems).slice(0, 5); }
  private recent(): CosProject | undefined {
    return this.state.projects.filter((project: CosProject) => this.state.readiness(project.id).photos.byStage[4] > 0).sort((a: CosProject, b: CosProject) => (this.state.readiness(b.id).date || '').localeCompare(this.state.readiness(a.id).date || '') || b.updatedAt - a.updatedAt)[0];
  }
  @Builder next() {
    SectionHeading({ title: '接下来' })
    if (this.state.todayEvents.length) {
      Button(dayTitle(this.state.todayEvents[0], this.state.clockTime) + (this.state.todayEvents.length > 1 ? ' · 还有 ' + (this.state.todayEvents.length - 1) + ' 个' : ''))
        .id('home-day-entry').width('100%').constraintSize({ minHeight: 64 }).fontSize(18).fontColor(Theme.accent).backgroundColor(Theme.tint)
        .onClick((): void => { this.open('dayEvent', this.state.todayEvents[0]?.id || ''); })
    } else if (this.nextEvent()) {
      Button((this.nextEvent()?.date || '') + ' · ' + (this.nextEvent()?.name || '')).width('100%').constraintSize({ minHeight: 48 })
        .onClick((): void => { this.open('event', this.nextEvent()?.id || ''); })
    }
    ForEach(this.recentPlans(), (project: CosProject) => { ProjectCard({ state: this.state, project: project, open: (): void => { this.open('project', project.id); } }) }, (project: CosProject) => project.id)
    if (!this.recentPlans().length) { Button('新建计划').constraintSize({ minHeight: 48 }).onClick((): void => { this.add('project', ''); }) }
  }
  @Builder tasks() {
    SectionHeading({ title: '在途与待办', trailing: '需要处理 ' + this.state.actionItems.length + ' 项' })
    ForEach(this.summaryItems(), (item: TaskQueueItem) => {
      Button() {
        Column({ space: 4 }) {
          Text((item.kind === 'waiting' ? '在途 · ' : item.group === 'overdue' ? '逾期 · ' : '') + item.title).fontSize(16).fontColor(Theme.ink)
          Text(item.projectName + ' · ' + item.detail).fontSize(13).fontColor(Theme.muted)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
      }.width('100%').constraintSize({ minHeight: 48 }).backgroundColor(Theme.surface).onClick((): void => { this.openTask(item); })
    }, (item: TaskQueueItem) => item.id)
    if (!this.summaryItems().length) { Text('当前没有需要处理的事项；未定期和更远的任务可在全部待办查看。').fontSize(14).fontColor(Theme.muted) }
    Button('全部待办 ' + this.state.taskQueue.length + ' 项').id('home-all-tasks').width('100%').constraintSize({ minHeight: 48 }).fontColor(Theme.accent).backgroundColor(Theme.tint).onClick((): void => { this.open('tasks', 'all'); })
  }
  @Builder recentSection() {
    SectionHeading({ title: '最近' })
    if (this.recent()) { Button('最近作品 · ' + (this.recent()?.name || '') + ' · 成片 ' + this.state.readiness(this.recent()?.id || '').photos.byStage[4] + ' 张').width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('projectPhotos', this.recent()?.id || ''); }) }
    else { Text('整理成片后，可以在这里回看。').fontSize(14).fontColor(Theme.muted) }
    Row({ space: 10 }) {
      Button('记一笔').constraintSize({ minHeight: 48 }).onClick((): void => { this.add('expense', ''); })
      Button('收录一条').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('inbox', 'global'); })
    }
    if (this.state.untriagedEntries.length) { Button('收录箱 · 未归位 ' + this.state.untriagedEntries.length + ' 条').id('home-inbox').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('inbox', 'global'); }) }
    Row({ space: 8 }) {
      Button('本月已记录支出 ¥' + (this.state.monthSpendingCents / 100).toFixed(2) + ' · 花费统计').fontSize(14).layoutWeight(1).id('home-expenses').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('expenseStats', 'all'); })
      Button('角色库').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('characters', 'all'); })
    }
  }
  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Blank().height(this.topInset).width('100%')
        if (!this.state.projects.length && !this.state.events.length && !this.state.assets.length && !this.state.characters.length && !this.state.entries.length) {
          EmptyState({ title: '从一次想出的角色开始', message: '建立计划，添加准备任务，再安排活动和整理照片。', button: '新建计划', action: (): void => { this.add('project', ''); } })
          Button('先收录一个想法').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('inbox', 'global'); })
        } else { this.next(); this.tasks(); this.recentSection() }
        Blank().height(this.bottomInset).width('100%')
      }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
  }
}
