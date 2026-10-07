import { eventDateLabel, eventTimeLabel, reminderTime } from '../../model/Schedule';
import { pageTransition, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { SheetHeader } from '../../components/SheetHeader';
import { AppState } from '../../common/AppState';
import { Theme, daysUntil } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { CosEvent, CosProject } from '../../model/Entities';
import { SectionHeading, StatusPill, FactRow } from '../../components/Surfaces';
import { ProjectCard } from '../../components/ProjectCard';

@ComponentV2
export struct EventDetail {
  @Param state: AppState = new AppState();
  @Param event: CosEvent = new CosEvent();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local linking: boolean = false;
  @Local animStep: number = 0;
  private enterTimers: number[] = [];
  // 二级页面：每次进入都重新播放入场动画。
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 0; }
  private async associate(project: CosProject): Promise<void> {
    const copy = JSON.parse(JSON.stringify(project)) as CosProject; copy.eventId = this.event.id;
    if (await this.state.saveProject(copy)) { this.linking = false; }
  }
  @Builder linkSheet() {
    Column({ space: 14 }) {
      SheetHeader({
        title: '关联已有计划', hint: '只列出尚未关联活动的计划',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.linking = false; },
      })
      List({ space: 10 }) {
        ForEach(this.state.projects.filter((p: CosProject) => !p.eventId), (p: CosProject) => {
          ListItem() { Button(p.name).width('100%').constraintSize({ minHeight: 56 }).backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.associate(p); }).accessibilityText('关联计划 ' + p.name) }
        }, (p: CosProject) => p.id)
      }.layoutWeight(1).width('100%')
      if (!this.state.projects.some((p: CosProject) => !p.eventId)) { Text('没有待关联的计划，可以为本次活动新建计划。').fontSize(13).fontColor(Theme.muted) }
      Button('完成').width('100%').backgroundColor(Theme.accent).fontColor(Theme.onAccent).onClick((): void => { vibration.dotVibration(); this.linking = false; })
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }

  @Builder header() {
    Row({ space: 10 }) {
      Text(this.event.name).fontSize(19).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      StatusPill({ label: this.event.ticketPurchased ? '门票已准备' : '门票待确认' })
    }.width('100%').alignItems(VerticalAlign.Center)
    Text(this.event.dateMode === 'pending' ? '日期待定' : daysUntil(this.event.date) >= 0 ? `还有 ${daysUntil(this.event.date)} 天` : '已留下的回忆').fontSize(13).fontColor(Theme.accent)
  }

  @Builder information() {
    Column({ space: 12 }) {
      FactRow({ label: '类型', value: this.event.eventType })
      FactRow({ label: '日期', value: eventDateLabel(this.event) })
      FactRow({ label: '时间', value: eventTimeLabel(this.event) })
      FactRow({ label: '提醒', value: this.event.reminderId < 0 ? '未开启' : reminderTime(this.event) <= Date.now() ? '提醒时间已过' : this.event.reminderMinutes === 0 ? '开始时' : '提前 ' + this.event.reminderMinutes + ' 分钟' })
      if (this.event.dateMode !== 'pending' && this.event.reminderId < 0) {
        Button('通知设置').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.state.openReminderSettings(); })
        Text('开启通知后，在编辑活动中选择提醒时间。').fontSize(12).fontColor(Theme.muted)
      }
      Text('可通过下方「设备日历」带入日期、地点和提醒；在系统确认页选择账户，已添加的日程由系统日历独立管理。').fontSize(12).fontColor(Theme.muted)
      FactRow({ label: '城市', value: this.event.city })
      FactRow({ label: '场馆', value: this.event.venue })
      if (this.event.url) { FactRow({ label: '官方链接', value: this.event.url, copyable: true }) }
      if (this.event.notes) { FactRow({ label: '备注', value: this.event.notes }) }
    }.padding(18).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Column({ space: 10 }) {
          this.header()
          this.information()
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })

        Column({ space: Theme.sectionSpacing }) {
          Row({ space: 10 }) {
            SectionHeading({ title: '本场计划', trailing: this.state.projects.filter((p: CosProject) => p.eventId === this.event.id).length + ' 份' }).layoutWeight(1)
            Button('关联已有').backgroundColor(Theme.tint).fontColor(Theme.accent).fontSize(13).constraintSize({ minHeight: 36 })
              .onClick((): void => { vibration.dotVibration(); this.linking = true; }).accessibilityText('关联已有计划')
          }.width('100%').alignItems(VerticalAlign.Center)
          if (!this.state.projects.some((p: CosProject) => p.eventId === this.event.id)) { Text('使用标题栏的「新建计划」，本次活动和日期会自动填入。').fontSize(13).fontColor(Theme.muted) }
          ForEach(this.state.projects.filter((p: CosProject) => p.eventId === this.event.id), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
        Blank().height(Theme.contentBottom).width('100%')
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
      .bindSheet(this.linking, this.linkSheet(), appSheetOptions((): void => { this.linking = false; }))
  }
}
