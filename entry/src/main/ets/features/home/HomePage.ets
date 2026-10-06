import { ManagedImage } from '../../components/ManagedImage';
import { getDeviceName } from '../../common/storage';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { AppState } from '../../common/AppState';
import { Theme, daysUntil, today } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { CosProject, ProjectStatus, CosEvent, ChecklistItem, PhotoAsset, PhotoStatus } from '../../model/Entities';
import { SectionHeading, InteractiveCard, EmptyState, StatusPill } from '../../components/Surfaces';
import { nextPlan, planDate } from '../../model/Rules';
import { ProjectCard } from '../../components/ProjectCard';

@ComponentV2
export struct HomePage {
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param state: AppState = new AppState();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param active: boolean = false;
  @Local animStep: number = 0;
  // 一级页面：进入应用后只播放一次，切回不再重播。
  private enterAnimationPlayed: boolean = false;
  private enterAnimationTimers: number[] = [];
  aboutToAppear(): void { if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); } }
  private enter(): void {
    if (this.enterAnimationPlayed) { return; }
    this.enterAnimationPlayed = true;
    this.enterAnimationTimers = startStaggerEnterAnimation(this.getUIContext(), 3, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterAnimationTimers); this.animStep = 3; }
  private current(): CosProject | undefined { return nextPlan(this.state.projects, this.state.events, today()); }
  private packingTasks(): ChecklistItem[] { const currentId = this.current()?.id; return this.state.checklist.filter((item: ChecklistItem) => !item.done && this.state.projects.some((project: CosProject) => project.id === item.projectId && project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED)).sort((a: ChecklistItem, b: ChecklistItem) => Number(b.projectId === currentId) - Number(a.projectId === currentId) || a.sortOrder - b.sortOrder); }
  private next(): CosEvent | undefined { return this.state.events.filter((e: CosEvent) => e.status === 'Planned' && e.date >= today()).sort((a: CosEvent, b: CosEvent) => a.date.localeCompare(b.date))[0]; }
  @Builder eventContent() {
    Row({ space: 16 }) {
      Column({ space: 3 }) { Text(String(Math.max(0, daysUntil(this.next()?.date || today())))).fontSize(32).fontWeight(FontWeight.Lighter).fontColor(Theme.accent); Text('天后见').fontSize(12).fontColor(Theme.muted) }.width(64)
      Column({ space: 6 }) { Text(this.next()?.name || '').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.ink); Text(`${this.next()?.date} · ${this.next()?.city}`).fontSize(13).fontColor(Theme.muted); StatusPill({ label: this.next()?.ticketPurchased ? '门票已准备' : '记得确认门票' }) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
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
    Text(`${this.greeting()}，${this.state.settings.username || getDeviceName()}`)
      .fontSize(21).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
      .width('100%').textAlign(TextAlign.Start)
      .padding({ left: 4, right: 4, top: 4, bottom: 4 })
      .accessibilityText(`${this.greeting()}，${this.state.settings.username || getDeviceName()}，欢迎回到绮秀`)
  }
  build() {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(this.topInset).width('100%')
        Column({ space: 16 }) {
        this.greetingHeader()
        if (this.state.projects.length === 0 && this.state.characters.length === 0) {
          EmptyState({ title: '开始你的第一份 Cos 计划', message: '选择角色，准备装备，再打包出门。角色可以在新建时一起填写。', button: '＋ 新建 Cos 计划', action: (): void => this.add('project', '') })
        }
        if (this.current()) {
          SectionHeading({ title: '接下来这份计划', trailing: planDate(this.current() as CosProject, this.state.events) ? planDate(this.current() as CosProject, this.state.events) : '日期待定' })
          ProjectCard({ state: this.state, project: this.current() as CosProject, hero: true, open: () => this.open('project', this.current()?.id || '') })
          Row({ space: 10 }) {
            Button(this.state.projectAssets(this.current()?.id || '').length === 0 ? '准备装备' : '检查装备').layoutWeight(1).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.open('project', this.current()?.id || ''); })
            Button('开始打包').layoutWeight(1).backgroundColor(Theme.accent).fontColor(Theme.onAccent).onClick((): void => { vibration.dotVibration(); this.open('packing', this.current()?.id || ''); })
          }.width('100%')

        } else if (this.state.characters.length > 0) {
          EmptyState({ title: '开始下一份计划', message: '已有角色可以直接复用。', button: '＋ 新建 Cos 计划', action: (): void => this.add('project', '') })
        }
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
        Column({ space: 16 }) {
        if (this.next()) {
          SectionHeading({ title: '下一场漫展' })
          InteractiveCard({ label: this.next()?.name || '', effects: this.state.settings.effects, action: () => this.open('event', this.next()?.id || ''), content: (): void => this.eventContent() })
        }
        if (this.packingTasks().length > 0 || this.state.photos.some((p: PhotoAsset) => p.status === PhotoStatus.IMPORTED || p.status === PhotoStatus.RAW)) {
          SectionHeading({ title: '下一步' })
          ForEach(this.packingTasks().slice(0, 3), (item: ChecklistItem) => {
            Button() { Row({ space: 12 }) { Text('○').fontSize(20).fontColor(Theme.accent).accessibilityLevel('no'); Column({ space: 4 }) { Text(item.label).fontSize(15).fontColor(Theme.ink); Text(this.state.projectName(item.projectId)).fontSize(12).fontColor(Theme.muted) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('›').fontColor(Theme.muted).accessibilityLevel('no') }.width('100%').padding(16) }
              .width('100%').backgroundColor(Theme.surface).borderRadius(18).onClick((): void => { vibration.dotVibration(); this.open('packing', item.projectId); }).accessibilityText('待办 ' + item.label)
          }, (item: ChecklistItem) => item.id)
          ForEach(this.state.projects.filter((project: CosProject) => this.state.photos.some((photo: PhotoAsset) => photo.projectId === project.id && (photo.status === PhotoStatus.IMPORTED || photo.status === PhotoStatus.RAW))).slice(0, 2), (project: CosProject) => {
            Button('选片 · ' + project.name).width('100%').constraintSize({ minHeight: 52 }).backgroundColor(Theme.surface).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.open('projectPhotos', project.id); }).accessibilityText('打开 ' + project.name + ' 的选片')
          }, (project: CosProject) => project.id)

        }

        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
        Column({ space: 16 }) {
        if (this.state.photos.length > 0) {
          SectionHeading({ title: '最近照片', trailing: `${this.state.photos.length} 张` })
          Row({ space: 10 }) {
            ForEach(this.state.photos.slice(0, 3), (photo: PhotoAsset) => {
              Column({ space: 6 }) {
                if (photo.thumbnailPath) { ManagedImage({ sourcePath: photo.thumbnailPath, label: this.state.projectName(photo.projectId) + '照片' }).width('100%').aspectRatio(0.8).borderRadius(14).accessibilityText(this.state.projectName(photo.projectId) + '照片') }
                else { Text('照片待恢复').fontColor(Theme.muted).width('100%').aspectRatio(0.8).textAlign(TextAlign.Center).backgroundColor(Theme.surface).borderRadius(14) }
              }.layoutWeight(1).onClick((): void => { vibration.dotVibration(); this.open('photo', photo.id); })
            }, (photo: PhotoAsset) => photo.id)
          }.width('100%')
        }
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 3 ? 1 : 0).translate({ y: this.animStep >= 3 ? 0 : 20 })
        Blank().height(this.bottomInset).width('100%')
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
  }
}
