import { PressFeedback } from '../ui/pressFeedback';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { RESPONSIVE_BREAKPOINT_MEDIUM, RESPONSIVE_BREAKPOINT_LARGE } from '../ui/responsive';
import { vibration } from '../ui/vibration';
import { ScheduleRoute } from '../viewmodels/ScheduleRoute';
import { ScheduleView, ScheduleDayCell } from '../models/ScheduleView';
import { TaskQueueItem } from '../models/TaskQueue';
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

    private move(step: number): void {
        vibration.dotVibration();
        this.route.moveMonth(step);
    }

    private reset(): void {
        vibration.dotVibration();
        this.route.selectDate(this.state.localDate);
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    @Builder month() {
        Column({ space: 14 }) {
            Row({ space: 8 }) {
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.chevronLeftSymbol)
                        .fontSize(18)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(40)
                    .height(40)
                    .clip(false)
                    .backgroundColor(Theme.tint)
                    .onClick((): void => this.move(-1))
                    .id('calendar-previous')
                    .accessibilityText('上个月')
                    .visualEffect(this.feedback.effect('button-1', false))
                    .compositingFilter(this.feedback.filter('button-1', false))
                    .attributeModifier(this.feedback.control('button-1', false))
                Text(this.route.year + ' 年 ' + (this.route.month + 1) + ' 月')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.chevronRightSymbol)
                        .fontSize(18)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(40)
                    .height(40)
                    .clip(false)
                    .backgroundColor(Theme.tint)
                    .onClick((): void => this.move(1))
                    .id('calendar-next')
                    .accessibilityText('下个月')
                    .visualEffect(this.feedback.effect('button-2', false))
                    .compositingFilter(this.feedback.filter('button-2', false))
                    .attributeModifier(this.feedback.control('button-2', false))
                Button('今天', { type: ButtonType.Normal, stateEffect: false })
                    .height(34)
                    .padding({ left: 12, right: 12 })
                    .borderRadius(Theme.pillRadius)
                    .clip(false)
                    .accessibilityText('今天')
                    .backgroundColor(Theme.tint)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.accent)
                    .onClick((): void => this.reset())
                    .visualEffect(this.feedback.effect('button-3', false))
                    .compositingFilter(this.feedback.filter('button-3', false))
                    .attributeModifier(this.feedback.control('button-3', false))
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            Row() {
                ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string) => {
                    Text(day)
                        .width('14.285%')
                        .textAlign(TextAlign.Center)
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.muted)
                })
            }.width('100%')
            Grid() {
                ForEach(this.view.days, (cell: ScheduleDayCell) => {
                    GridItem() {
                        Button({ type: ButtonType.Normal, stateEffect: false }) {
                            Column({ space: 3 }) {
                                Text(String(cell.day.day))
                                    .fontSize(15)
                                    .fontWeight(this.route.selectedDate === cell.day.date || cell.day.date === this.state.localDate ? FontWeight.Bold : FontWeight.Regular)
                                    .fontColor(this.route.selectedDate === cell.day.date ? Theme.onAccent : cell.day.currentMonth ? Theme.ink : Theme.muted)
                                Row({ space: 3 }) {
                                    if (cell.events.length > 0) {
                                        Circle({ width: 5, height: 5 })
                                            .fill(this.route.selectedDate === cell.day.date ? Theme.onAccent : Theme.brand)
                                    }
                                    if (cell.tasks.length > 0) {
                                        Circle({ width: 5, height: 5 })
                                            .fill(this.route.selectedDate === cell.day.date ? Theme.onAccent : Theme.warning)
                                    }
                                }.height(6)
                                    .justifyContent(FlexAlign.Center)
                            }.justifyContent(FlexAlign.Center)
                        }.clip(false)
                            .id('calendar-day:' + cell.day.date)
                            .width('100%')
                            .height(48)
                            .borderRadius(Theme.pillRadius)
                            .backgroundColor(this.route.selectedDate === cell.day.date ? Theme.brand : cell.day.date === this.state.localDate ? Theme.tint : Color.Transparent)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.route.selectDate(cell.day.date);
                            })
                            .accessibilitySelected(this.route.selectedDate === cell.day.date)
                            .accessibilityText(cell.day.date + '，' + cell.events.length + ' 场活动，' + cell.tasks.length + ' 项准备任务截止')
                            .visualEffect(this.feedback.effect('button-4:' + cell.day.date, false))
                            .compositingFilter(this.feedback.filter('button-4:' + cell.day.date, false))
                            .attributeModifier(this.feedback.control('button-4:' + cell.day.date, false))
                    }
                }, (cell: ScheduleDayCell) => cell.day.date)
            }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
                .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
                .columnsGap(4)
                .rowsGap(4)
                .height(308)
                .width('100%')
            Row({ space: 16 }) {
                Row({ space: 6 }) {
                    Circle({ width: 7, height: 7 }).fill(Theme.brand)
                    Text('活动').fontSize(12).fontColor(Theme.muted)
                }.alignItems(VerticalAlign.Center)
                Row({ space: 6 }) {
                    Circle({ width: 7, height: 7 }).fill(Theme.warning)
                    Text('准备任务截止').fontSize(12).fontColor(Theme.muted)
                }.alignItems(VerticalAlign.Center)
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
    }

    @Builder selectedDay() {
        ScheduleDayList({
            state: this.state,
            date: this.route.selectedDate,
            events: this.view.selectedEvents,
            tasks: this.view.selectedTasks,
            open: (kind: string, id: string): void => {
                this.open(kind, id);
            },
            openTask: (item: TaskQueueItem): void => {
                this.openTask(item);
            },
            add: (kind: string, parent: string): void => {
                this.add(kind, parent);
            },
        })
    }

    build() {
        GridRow({
            columns: 12,
            gutter: 24,
            breakpoints: {
                value: [RESPONSIVE_BREAKPOINT_MEDIUM, RESPONSIVE_BREAKPOINT_LARGE],
                reference: BreakpointsReference.WindowSize,
            },
        }) {
            GridCol({ span: { xs: 12, sm: 12, md: 7 } }) {
                this.month()
            }
            GridCol({ span: { xs: 12, sm: 12, md: 5 } }) {
                this.selectedDay()
            }
        }.width('100%')
    }
}
