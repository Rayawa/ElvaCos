import { daysUntil } from '../../common/format';
import { PressFeedback } from '../../common/pressFeedback';
import { StaggerEntrance } from '../../common/motion';
import { eventDateLabel, eventTimeLabel, reminderTime } from '../../model/Schedule';
import { pageTransition } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { SheetHeader } from '../../component/SheetHeader';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { CosEvent, CosProject } from '../../model/Entities';
import { SectionHeading, StatusPill, FactRow } from '../../component/Surfaces';
import { ProjectCard } from '../../component/ProjectCard';

@ComponentV2
export struct EventDetail {
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Param event: CosEvent = new CosEvent();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local linking: boolean = false;
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  aboutToAppear(): void { if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (!this.entrance.managed) { this.entrance.reset(); } }
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
      }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
      List({ space: 10 }) {
        ForEach(this.state.projects.filter((p: CosProject) => !p.eventId), (p: CosProject) => {
          ListItem() { Button(p.name)
            .width('100%')
            .constraintSize({ minHeight: 56 })
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .enabled(!this.state.busy)
            .onClick((): void => { vibration.dotVibration(); this.associate(p); })
            .accessibilityText('关联计划 ' + p.name)
            .visualEffect(this.feedback.effect('link-project:' + p.id, true))
            .compositingFilter(this.feedback.filter('link-project:' + p.id, true))
            .attributeModifier(this.feedback.control('link-project:' + p.id, true)) }
        }, (p: CosProject) => p.id)
      }.layoutWeight(1).width('100%').opacity(this.sheetEntrance.step >= 2 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
      if (!this.state.projects.some((p: CosProject) => !p.eventId)) { Text('没有待关联的计划，可以为本次活动新建计划。').fontSize(13).fontColor(Theme.muted) }
      Button('完成')
        .accessibilityText('完成')
        .width('100%')
        .backgroundColor(Theme.brand)
        .fontColor(Theme.onAccent)
        .onClick((): void => { vibration.dotVibration(); this.linking = false; })
        .visualEffect(this.feedback.effect('button-2'))
        .compositingFilter(this.feedback.filter('button-2'))
        .attributeModifier(this.feedback.control('button-2'))
        .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
        .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }

  @Builder header() {
    Row({ space: 10 }) {
      Text(this.event.name)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.ink)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      StatusPill({ label: this.event.ticketPurchased ? '门票已准备' : '门票待确认' })
    }.width('100%').alignItems(VerticalAlign.Center)
    Text(this.event.dateMode === 'pending' ? '日期待定' : daysUntil(this.event.date) >= 0 ? `还有 ${daysUntil(this.event.date)} 天` : '已留下的回忆')
      .fontSize(13)
      .fontColor(Theme.accent)
  }

  @Builder information() {
    Column({ space: 12 }) {
      FactRow({ label: '类型', value: this.event.eventType })
      FactRow({ label: '日期', value: eventDateLabel(this.event) })
      FactRow({ label: '时间', value: eventTimeLabel(this.event) })
      FactRow({
        label: '提醒',
        value: this.event.reminderId < 0 ? '未开启' : reminderTime(this.event) <= Date.now() ? '提醒时间已过' : this.event.reminderMinutes === 0 ? '开始时' : '提前 ' + this.event.reminderMinutes + ' 分钟'
      })
      if (this.event.dateMode !== 'pending' && this.event.reminderId < 0) {
        Button('通知设置')
          .accessibilityText('通知设置')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.state.openReminderSettings(); })
          .visualEffect(this.feedback.effect('button-4'))
          .compositingFilter(this.feedback.filter('button-4'))
          .attributeModifier(this.feedback.control('button-4'))
        Text('开启通知后，在编辑活动中选择提醒时间。').fontSize(12).fontColor(Theme.muted)
      }
      Text('可通过下方「设备日历」带入日期、地点和提醒；在系统确认页选择账户，已添加的日程由系统日历独立管理。').fontSize(12).fontColor(Theme.muted)
      FactRow({ label: '城市', value: this.event.city })
      FactRow({ label: '场馆', value: this.event.venue })
      if (this.event.url) { FactRow({ label: '官方链接', value: this.event.url, copyable: true }) }
      if (this.event.notes) { FactRow({ label: '备注', value: this.event.notes }) }
    }.padding(18)
      .width('100%')
      .backgroundColor(Theme.surface)
      .borderRadius(Theme.cardRadius)
      .alignItems(HorizontalAlign.Start)
      .visualEffect(this.feedback.effect('column-3', true))
      .compositingFilter(this.feedback.filter('column-3', true))
      .attributeModifier(this.feedback.control('column-3', true))
  }

  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Column({ space: 10 }) {
          this.header()
          this.information()
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.entrance.step >= 1 ? 1 : 0).translate({ y: this.entrance.step >= 1 ? 0 : 20 })

        Column({ space: Theme.sectionSpacing }) {
          Row({ space: 10 }) {
            SectionHeading({
              title: '本场计划',
              trailing: this.state.projects.filter((p: CosProject) => p.eventId === this.event.id).length + ' 份'
            }).layoutWeight(1)
            Button('关联已有').backgroundColor(Theme.tint).fontColor(Theme.accent).fontSize(13).constraintSize({ minHeight: 36 })
              .onClick((): void => { vibration.dotVibration(); this.linking = true; })
                .accessibilityText('关联已有计划')
                .visualEffect(this.feedback.effect('button-5'))
                .compositingFilter(this.feedback.filter('button-5'))
                .attributeModifier(this.feedback.control('button-5'))
          }.width('100%').alignItems(VerticalAlign.Center)
          if (!this.state.projects.some((p: CosProject) => p.eventId === this.event.id)) { Text('使用标题栏的「新建计划」，本次活动和日期会自动填入。')
            .fontSize(13)
            .fontColor(Theme.muted) }
          ForEach(this.state.projects.filter((p: CosProject) => p.eventId === this.event.id), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
        Blank().height(Theme.contentBottom).width('100%')
      }.
    constraintSize({ maxWidth: Theme.contentMaxWidth }).width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
      .bindSheet(this.linking, this.linkSheet(), appSheetOptions((): void => { this.linking = false; }, this.sheetEntrance, this.getUIContext()))
  }
}
