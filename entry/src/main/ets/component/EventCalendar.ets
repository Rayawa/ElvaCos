import { today } from '../common/format';
import { PressFeedback } from '../common/pressFeedback';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { CosEvent } from '../model/Entities';
import { CalendarDay, calendarDays, eventsOnDate, eventDateLabel, eventTimeLabel } from '../model/Schedule';
import { SectionHeading, EmptyState } from './Surfaces';

@ComponentV2
export struct EventCalendar {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Local year: number = new Date().getFullYear();
  @Local month: number = new Date().getMonth();
  @Local selected: string = today();
  private move(step: number): void { 
  vibration.dotVibration(); 
  const date = new Date(this.year, this.month + step, 1, 12); 
  this.year = date.getFullYear(); 
  this.month = date.getMonth(); 
}
  private reset(): void { 
  vibration.dotVibration(); 
  const date = new Date(); 
  this.year = date.getFullYear(); 
  this.month = date.getMonth(); 
  this.selected = today(); 
}
  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Button('‹')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .onClick((): void => this.move(-1))
          .id('calendar-previous')
          .accessibilityText('上个月')
          .attributeModifier(this.feedback.control('button-1'))
        Text(this.year + ' 年 ' + (this.month + 1) + ' 月').fontSize(17).fontColor(Theme.ink).layoutWeight(1).textAlign(TextAlign.Center)
        Button('›')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .onClick((): void => this.move(1))
          .id('calendar-next')
          .accessibilityText('下个月')
          .attributeModifier(this.feedback.control('button-2'))
        Button('今天')
          .accessibilityText('今天')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .onClick((): void => this.reset())
          .attributeModifier(this.feedback.control('button-3'))
      }.width('100%')
      Row() { ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string) => { Text(day)
        .width('14.285%')
        .textAlign(TextAlign.Center)
        .fontSize(13)
        .fontColor(Theme.muted) }) }.width('100%')
      Grid() {
        ForEach(calendarDays(this.year, this.month), (day: CalendarDay) => {
          GridItem() {
            Button() {
              Column({ space: 2 }) {
                Text(String(day.day)).fontSize(15).fontColor(this.selected === day.date ? Theme.onAccent : day.currentMonth ? Theme.ink : Theme.muted)
                Text(eventsOnDate(this.state.events, day.date)
                  .length > 0 ? '●' : ' ')
                  .fontSize(8)
                  .fontColor(this.selected === day.date ? Theme.onAccent : Theme.accent)
              }
            }.type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .borderRadius(14)
              .backgroundColor(this.selected === day.date ? Theme.accent : day.date === today() ? Theme.tint : Theme.transparent)
              .onClick((): void => { vibration.dotVibration(); this.selected = day.date; })
              .accessibilitySelected(this.selected === day.date)
                .accessibilityText(day.date + '，' + eventsOnDate(this.state.events, day.date)
                .length + ' 场活动')
                .attributeModifier(this.feedback.control('button-4' + ":" + day.date))
          }
        }, (day: CalendarDay) => day.date)
      }.
    columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr').columnsGap(4).rowsGap(4).height(308).width('100%')
      SectionHeading({ title: this.selected, trailing: eventsOnDate(this.state.events, this.selected).length + ' 场活动' })
      ForEach(eventsOnDate(this.state.events, this.selected), (event: CosEvent) => {
        Button() {
          Column({ space: 6 }) {
            Text(event.name).fontSize(17).fontColor(Theme.ink)
            Text(event.eventType + ' · ' + eventDateLabel(event)).fontSize(12).fontColor(Theme.muted)
            Text(eventTimeLabel(event) + ' · ' + (event.venue || event.city || '地点待定')).fontSize(12).fontColor(Theme.muted)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        }.width('100%')
          .type(ButtonType.Normal)
          .backgroundColor(Theme.surface)
          .borderRadius(Theme.cardRadius)
          .onClick((): void => { vibration.dotVibration(); this.open('event', event.id); })
          .accessibilityText('打开活动 ' + event.name)
          .attributeModifier(this.feedback.control('button-5' + ":" + event.id, true))
      }, (event: CosEvent) => event.id)
      if (eventsOnDate(this.state.events, this.selected).length === 0) { EmptyState({
          title: '这天还没有安排',
          message: '多天活动会显示在覆盖的每一天。',
          button: '＋ 添加当天活动',
          action: (): void => this.add('event', this.selected)
        }) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
