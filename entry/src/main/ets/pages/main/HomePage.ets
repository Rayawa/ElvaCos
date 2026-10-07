import { MIN_SPLIT_HEIGHT } from '../../common/constants';
import { daysUntil, today } from '../../common/format';
import { PressFeedback } from '../../common/pressFeedback';
import { MainEntranceSession } from '../../common/motion';
import { TaskLinkCard } from '../../component/TaskLinkCard';
import { scrollByAxis } from '../../common/scroll';
import { DashboardSplitLayout } from '../../component/DashboardSplitLayout';
import { PreparationTask } from '../../model/Preparation';
import { eventEnd } from '../../model/Schedule';
import { expenseTotal } from '../../model/Planning';
import { ManagedImage } from '../../component/ManagedImage';
import { getDeviceName } from '../../common/storage';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { CosProject, ProjectStatus, CosEvent, ChecklistItem, PhotoAsset, PhotoStatus } from '../../model/Entities';
import { SectionHeading, InteractiveCard, EmptyState, StatusPill } from '../../component/Surfaces';
import { nextPlan, planDate } from '../../model/Rules';
import { ProjectCard } from '../../component/ProjectCard';

@ComponentV2
export struct HomePage {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Require @Param state: AppState;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = false;
  @Local animStep: number = 0;
  @Local contentWidth: number = 0;
  @Local contentHeight: number = 0;
  // 一级页面：进入应用后只播放一次，切回不再重播。
  private enterAnimationPlayed: boolean = false;
  private enterAnimationTimers: number[] = [];
  aboutToAppear(): void { if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); } }
  private enter(): void {
    if (this.enterAnimationPlayed) { return; }
    this.enterAnimationPlayed = true;
    if (!this.entranceSession.claim('HomePage')) { this.animStep = 3; return; }
    this.enterAnimationTimers = startStaggerEnterAnimation(this.getUIContext(), 3, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterAnimationTimers); this.animStep = 3; }
  private current(): CosProject | undefined { return nextPlan(this.state.projects, this.state.events, today()); }
  private packingTasks(): ChecklistItem[] { const currentId = this.current()?.id; return this.state.checklist.filter((item: ChecklistItem) => !item.done && this.state.projects.some((project: CosProject) => project.id === item.projectId && project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED))
    .sort((a: ChecklistItem, b: ChecklistItem) => Number(b.projectId === currentId) - Number(a.projectId === currentId) || a.sortOrder - b.sortOrder); }
  private preparationTasks(): PreparationTask[] {
    const current = this.current()?.id || '';
    return this.state.preparationTasks.filter((task: PreparationTask) => !task.done && this.state.projects.some((p: CosProject) => p.id === task.projectId && p.status !== ProjectStatus.COMPLETED && p.status !== ProjectStatus.ARCHIVED))
      .sort((a: PreparationTask, b: PreparationTask) => Number(b.projectId === current) - Number(a.projectId === current) || (a.dueDate || '9999')
        .localeCompare(b.dueDate || '9999') || a.sortOrder - b.sortOrder);
  }
  private next(): CosEvent | undefined { return this.state.events.filter((e: CosEvent) => e.status === 'Planned' && e.dateMode !== 'pending' && eventEnd(e) >= today())
    .sort((a: CosEvent, b: CosEvent) => a.date.localeCompare(b.date))[0]; }
  @Builder eventContent() {
    Row({ space: 12 }) {
      Column({ space: 3 }) { Text(String(Math.max(0, daysUntil(this.next()?.date || today()))))
        .id('home-event-countdown')
        .width('100%')
        .fontSize(32)
        .minFontSize(16)
        .maxFontSize(32)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .fontWeight(FontWeight.Lighter)
        .fontColor(Theme.accent); Text(daysUntil(this.next()?.date || today()) <= 0 ? '进行中' : '天后见')
        .id('home-event-caption')
        .fontSize(12)
        .fontColor(Theme.muted) }.width(64).alignItems(HorizontalAlign.Center)
      Column({ space: 6 }) { Text(this.next()?.name || '')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.ink).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(`${this.next()?.date} · ${this.next()?.city || '地点待定'}`)
        .fontSize(13)
        .fontColor(Theme.muted).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }); StatusPill({ label: this.next()?.ticketPurchased ? '门票已准备' : '记得确认门票' }) }.layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      Text('›').fontSize(24).fontColor(Theme.muted).accessibilityLevel('no')
    }.width('100%')
  }
  private greeting(): string {
    const hour = new Date().getHours();
    if (hour >= 6 && hour < 12) { return '上午好'; }
    if (hour >= 12 && hour < 18) { return '下午好'; }
    return '晚上好';
  }
  @Builder greetingHeader() {
    Column({ space: 5 }) {
      Text(`${this.greeting()}，${this.state.settings.username || getDeviceName()}`)
        .fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        .accessibilityText(`${this.greeting()}，${this.state.settings.username || getDeviceName()}`)
      Text($r('app.string.home_welcome')).fontSize(14).fontColor(Theme.muted)
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 4, right: 4 }).accessibilityGroup(true)
  }
  @Builder overview() {
    Column({ space: 16 }) {
      this.greetingHeader()
      Button('花费统计 · ¥' + (expenseTotal(this.state.expenses) / 100)
        .toFixed(2))
        .accessibilityText('查看花费统计，实际花费 ' + (expenseTotal(this.state.expenses) / 100)
        .toFixed(2) + ' 元')
        .id('home-expenses')
        .width('100%')
        .backgroundColor(Theme.tint)
        .fontColor(Theme.accent)
        .onClick((): void => { vibration.dotVibration(); this.open('expenseStats', 'all'); })
        .visualEffect(this.feedback.effect('button-1'))
        .compositingFilter(this.feedback.filter('button-1'))
        .attributeModifier(this.feedback.control('button-1'))
      if (this.state.projects.length === 0 && this.state.characters.length === 0) {
        EmptyState({
          title: '开始你的第一份 Cos 计划',
          message: '选择角色，准备装备，再打包出门。角色可以在新建时一起填写。',
          button: '＋ 新建 Cos 计划',
          action: (): void => this.add('project', '')
        })
      }
      if (this.current()) {
        SectionHeading({
          title: '接下来这份计划',
          trailing: planDate(this.current() as CosProject, this.state.events) ? planDate(this.current() as CosProject, this.state.events) : '日期待定'
        })
        ProjectCard({
          state: this.state,
          project: this.current() as CosProject,
          hero: true,
          open: () => this.open('project', this.current()?.id || '')
        })
        Row({ space: 10 }) {
          Button('继续准备')
            .accessibilityText('继续准备')
            .layoutWeight(1)
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .onClick((): void => { vibration.dotVibration(); this.open('project', this.current()?.id || ''); })
            .visualEffect(this.feedback.effect('button-2'))
            .compositingFilter(this.feedback.filter('button-2'))
            .attributeModifier(this.feedback.control('button-2'))
          Button('开始打包')
            .accessibilityText('开始打包')
            .layoutWeight(1)
            .backgroundColor(Theme.brand)
            .fontColor(Theme.onAccent)
            .onClick((): void => { vibration.dotVibration(); this.open('packing', this.current()?.id || ''); })
            .visualEffect(this.feedback.effect('button-3'))
            .compositingFilter(this.feedback.filter('button-3'))
            .attributeModifier(this.feedback.control('button-3'))
        }.width('100%')

      } else if (this.state.characters.length > 0) {
        EmptyState({
          title: '开始下一份计划',
          message: '已有角色可以直接复用。',
          button: '＋ 新建 Cos 计划',
          action: (): void => this.add('project', '')
        })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
  }
  @Builder nextActions() {
    Column({ space: 16 }) {
      if (this.next()) {
        SectionHeading({ title: '下一场活动' })
        InteractiveCard({
          label: this.next()?.name || '',
          effects: this.state.settings.effects,
          action: () => this.open('event', this.next()?.id || ''),
          content: (): void => this.eventContent()
        })
      }
      if (this.preparationTasks()
        .length > 0 || this.packingTasks()
        .length > 0 || this.state.photos.some((p: PhotoAsset) => p.status === PhotoStatus.IMPORTED || p.status === PhotoStatus.RAW)) {
        SectionHeading({ title: '下一步' })
        ForEach(this.preparationTasks().slice(0, 2), (task: PreparationTask) => {
          TaskLinkCard({
            title: (this.state.preparationCategories.find((c) => c.id === task.categoryId)?.name || '准备') + ' · ' + task.label,
            detail: this.state.projectName(task.projectId) + (task.dueDate ? ' · 截止 ' + task.dueDate : ''),
            label: '继续准备 ' + task.label, hint: '双击继续准备', effects: this.state.settings.effects,
            action: (): void => { this.open('project', task.projectId); },
          })
        }, (task: PreparationTask) => task.id)
        ForEach(this.packingTasks().slice(0, 3), (item: ChecklistItem) => {
          TaskLinkCard({
            title: item.label, detail: this.state.projectName(item.projectId),
            label: '待办 ' + item.label, hint: '双击继续打包', effects: this.state.settings.effects,
            action: (): void => { this.open('packing', item.projectId); },
          })
        }, (item: ChecklistItem) => item.id)
        ForEach(this.state.projects.filter((project: CosProject) => this.state.photos.some((photo: PhotoAsset) => photo.projectId === project.id && (photo.status === PhotoStatus.IMPORTED || photo.status === PhotoStatus.RAW)))
          .slice(0, 2), (project: CosProject) => {
          TaskLinkCard({
            title: '选片 · ' + project.name,
            detail: this.state.photos.filter((photo: PhotoAsset) => photo.projectId === project.id && (photo.status === PhotoStatus.IMPORTED || photo.status === PhotoStatus.RAW))
              .length + ' 张照片待选',
            label: '打开 ' + project.name + ' 的选片', hint: '双击继续选片', effects: this.state.settings.effects,
            action: (): void => { this.open('projectPhotos', project.id); },
          })
        }, (project: CosProject) => project.id)

      }

    }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
  }
  @Builder recentPhotoContent(photo: PhotoAsset) {
    if (photo.thumbnailPath) {
      ManagedImage({ sourcePath: photo.thumbnailPath, label: this.state.projectName(photo.projectId) + '照片' })
        .width('100%').aspectRatio(0.8).borderRadius(14)
    } else {
      Text('照片待恢复').fontColor(Theme.muted).width('100%').aspectRatio(0.8)
        .textAlign(TextAlign.Center).backgroundColor(Theme.surface).borderRadius(14)
    }
  }
  @Builder recentPhotos() {
    Column({ space: 16 }) {
      if (this.state.photos.length > 0) {
        SectionHeading({ title: '最近照片', trailing: `${this.state.photos.length} 张` })
        Row({ space: 10 }) {
          ForEach(this.state.photos.slice(0, 3), (photo: PhotoAsset) => {
            InteractiveCard({
              label: this.state.projectName(photo.projectId) + '照片', hint: '双击打开最近照片',
              effects: this.state.settings.effects, contentPadding: 0,
              action: (): void => { this.open('photo', photo.id); },
              content: (): void => { this.recentPhotoContent(photo); },
            }).layoutWeight(1)
          }, (photo: PhotoAsset) => photo.id)
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 3 ? 1 : 0).translate({ y: this.animStep >= 3 ? 0 : 20 })
  }
  @Builder wideContent() {
    Column({ space: Theme.sectionSpacing }) {
      this.nextActions()
      this.recentPhotos()
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.contentWidth >= Theme.wideBreakpoint && this.contentHeight >= MIN_SPLIT_HEIGHT) {
        DashboardSplitLayout({
          scroller: this.scroller, bottomInset: this.bottomInset,
          layoutId: 'home-wide-layout', overviewId: 'home-fixed-overview', scrollId: 'home-wide-scroll',
          overviewLabel: '固定显示的问候与当前计划', scrollLabel: '可滚动的活动、待办与最近照片',
          overview: (): void => { this.overview(); }, content: (): void => { this.wideContent(); },
        })
      } else {
        Scroll(this.scroller) {
          Column({ space: Theme.sectionSpacing }) {
            Blank().height(this.topInset).width('100%')
            this.overview()
            this.nextActions()
            this.recentPhotos()
            Blank().height(this.bottomInset).width('100%')
          }.width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth })
            .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        }.id('home-phone-scroll').width('100%').height('100%').scrollBar(BarState.Off)
          .align(Alignment.Top).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Center)
      .onAreaChange((_, area: Area): void => { this.contentWidth = Number(area.width); this.contentHeight = Number(area.height); })
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
