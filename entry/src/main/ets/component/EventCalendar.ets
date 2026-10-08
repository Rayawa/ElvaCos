import { PressFeedback } from '../common/pressFeedback';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { ScheduleRoute } from '../model/ScheduleRoute';
import { ScheduleView, ScheduleDayCell } from '../model/ScheduleView';
import { TaskQueueItem } from '../model/TaskQueue';
import { ScheduleDayList } from './ScheduleDayList';

@ComponentV2
export struct EventCalendar {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Require @Param route: ScheduleRoute;
  @Require @Param view: ScheduleView;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Event openTask: (item: TaskQueueItem) => void = () => {};
  private move(step: number): void { vibration.dotVibration(); this.route.moveMonth(step); }
  private reset(): void { vibration.dotVibration(); this.route.selectDate(this.state.localDate); }
  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Button('‹')
          .constraintSize({ minWidth: 48, minHeight: 48 }).clip(false)
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .onClick((): void => this.move(-1))
          .id('calendar-previous')
          .accessibilityText('上个月')
          .visualEffect(this.feedback.effect('button-1'))
          .compositingFilter(this.feedback.filter('button-1'))
          .attributeModifier(this.feedback.control('button-1'))
        Text(this.route.year + ' 年 ' + (this.route.month + 1) + ' 月').fontSize(17).fontColor(Theme.ink).layoutWeight(1).textAlign(TextAlign.Center)
        Button('›')
          .constraintSize({ minWidth: 48, minHeight: 48 }).clip(false)
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .onClick((): void => this.move(1))
          .id('calendar-next')
          .accessibilityText('下个月')
          .visualEffect(this.feedback.effect('button-2'))
          .compositingFilter(this.feedback.filter('button-2'))
          .attributeModifier(this.feedback.control('button-2'))
        Button('今天')
          .constraintSize({ minWidth: 48, minHeight: 48 }).clip(false)
          .accessibilityText('今天')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .onClick((): void => this.reset())
          .visualEffect(this.feedback.effect('button-3'))
          .compositingFilter(this.feedback.filter('button-3'))
          .attributeModifier(this.feedback.control('button-3'))
      }.width('100%')
      Row() { ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string) => { Text(day)
        .width('14.285%')
        .textAlign(TextAlign.Center)
        .fontSize(13)
        .fontColor(Theme.muted) }) }.width('100%')
      Grid() {
        ForEach(this.view.days, (cell: ScheduleDayCell) => {
          GridItem() {
            Button() {
              Column({ space: 2 }) {
                Text(String(cell.day.day)).fontSize(15).fontColor(this.route.selectedDate === cell.day.date ? Theme.onAccent : cell.day.currentMonth ? Theme.ink : Theme.muted)
                Text((cell.events.length > 0 ? '●' : '') + (cell.tasks.length > 0 ? ' ◆' : ''))
                  .fontSize(10)
                  .fontColor(this.route.selectedDate === cell.day.date ? Theme.onAccent : Theme.accent)
              }
            }.type(ButtonType.Normal)
              .clip(false)
              .id('calendar-day:' + cell.day.date)
              .width('100%')
              .height(48)
              .borderRadius(14)
              .backgroundColor(this.route.selectedDate === cell.day.date ? Theme.brand : cell.day.date === this.state.localDate ? Theme.tint : Theme.surface)
              .onClick((): void => { vibration.dotVibration(); this.route.selectDate(cell.day.date); })
              .accessibilitySelected(this.route.selectedDate === cell.day.date)
                .accessibilityText(cell.day.date + '，' + cell.events.length + ' 场活动，' + cell.tasks.length + ' 项准备任务截止')
                .visualEffect(this.feedback.effect('button-4' + ":" + cell.day.date))
                .compositingFilter(this.feedback.filter('button-4' + ":" + cell.day.date))
                .attributeModifier(this.feedback.control('button-4' + ":" + cell.day.date))
          }
        }, (cell: ScheduleDayCell) => cell.day.date)
      }.
    columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr').columnsGap(4).rowsGap(4).height(308).width('100%')
      Text('● 活动　◆ 准备任务截止').fontSize(14).fontColor(Theme.muted)
      ScheduleDayList({ state: this.state, date: this.route.selectedDate, events: this.view.selectedEvents, tasks: this.view.selectedTasks,
        open: (kind: string, id: string): void => { this.open(kind, id); }, openTask: (item: TaskQueueItem): void => { this.openTask(item); },
        add: (kind: string, parent: string): void => { this.add(kind, parent); } })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
