import { SymbolGlyphModifier } from '@kit.ArkUI';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { ScheduleRoute } from '../viewmodels/ScheduleRoute';
import { ScheduleView, ScheduleDayCell } from '../models/ScheduleView';

@ComponentV2
struct CalendarDayCell {
    @Require @Param cell: ScheduleDayCell;
    @Param selected: boolean = false;
    @Param isToday: boolean = false;
    @Param writable: boolean = true;
    @Event onSelect: () => void = () => {};
    @Event onAddEvent: () => void = () => {};
    @Local menuShown: boolean = false;
    private longPressTriggered: boolean = false;

    @Builder dayMenu() {
        Menu() {
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.event).fontSize(18).fontColor([Theme.accent]),
                content: '查看当天日程',
            }).onClick((): void => {
                this.menuShown = false;
                vibration.dotVibration();
                this.onSelect();
            })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.add).fontSize(18).fontColor([Theme.ink]),
                content: '添加当天活动',
            }).enabled(this.writable)
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onAddEvent();
                })
        }
    }

    build() {
        Button({ type: ButtonType.Capsule, stateEffect: false }) {
            Column({ space: 3 }) {
                Text(String(this.cell.day.day))
                    .fontSize(15)
                    .fontWeight(this.selected || this.isToday ? FontWeight.Bold : FontWeight.Regular)
                    .fontColor(this.selected ? Theme.onAccent : this.cell.day.currentMonth ? Theme.ink : Theme.muted)
                Row({ space: 3 }) {
                    if (this.cell.events.length > 0) {
                        Circle({ width: 5, height: 5 })
                            .fill(this.selected ? Theme.onAccent : Theme.brand)
                    }
                    if (this.cell.tasks.length > 0) {
                        Circle({ width: 5, height: 5 })
                            .fill(this.selected ? Theme.onAccent : Theme.warning)
                    }
                }.height(6)
                    .justifyContent(FlexAlign.Center)
            }.justifyContent(FlexAlign.Center)
        }.id('calendar-day:' + this.cell.day.date)
            .width('100%')
            .height(46)
            .borderRadius(Theme.pillRadius)
            .backgroundColor(this.selected ? Theme.brand : this.isToday ? Theme.tint : Color.Transparent)
            .onTouch((event: TouchEvent): void => {
                if (event.type === TouchType.Down) {
                    this.longPressTriggered = false;
                }
            })
            .gesture(
                LongPressGesture({ duration: 350 })
                    .onAction((): void => {
                        this.longPressTriggered = true;
                        vibration.lightVibration();
                        this.menuShown = true;
                    })
            )
            .onClick((): void => {
                if (this.longPressTriggered) {
                    this.longPressTriggered = false;
                    return;
                }
                vibration.dotVibration();
                this.onSelect();
            })
            .bindContextMenu(this.menuShown, this.dayMenu, {
                preview: MenuPreviewMode.IMAGE,
                aboutToDisappear: (): void => {
                    this.menuShown = false;
                },
                onDisappear: (): void => {
                    this.menuShown = false;
                },
            })
            .accessibilitySelected(this.selected)
            .accessibilityText(this.cell.day.date + '，' + this.cell.events.length + ' 场活动，' + this.cell.tasks.length + ' 项准备任务截止')
    }
}

@ComponentV2
export struct EventCalendar {
    @Require @Param state: AppState;
    @Require @Param route: ScheduleRoute;
    @Require @Param view: ScheduleView;
    @Event addEvent: (date: string) => void = () => {};

    private move(step: number): void {
        vibration.dotVibration();
        this.route.moveMonth(step);
    }

    private reset(): void {
        vibration.dotVibration();
        this.route.selectDate(this.state.localDate);
    }

    build() {
        Column({ space: 14 }) {
            Row({ space: 8 }) {
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.chevronLeftSymbol)
                        .fontSize(18)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(38)
                    .height(38)
                    .backgroundColor(Theme.tint)
                    .onClick((): void => this.move(-1))
                    .id('calendar-previous')
                    .accessibilityText('上个月')
                Text(this.route.year + ' 年 ' + (this.route.month + 1) + ' 月')
                    .fontSize(19)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.chevronRightSymbol)
                        .fontSize(18)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(38)
                    .height(38)
                    .backgroundColor(Theme.tint)
                    .onClick((): void => this.move(1))
                    .id('calendar-next')
                    .accessibilityText('下个月')
                Button('今天', { type: ButtonType.Capsule, stateEffect: false })
                    .height(34)
                    .padding({ left: 12, right: 12 })
                    .borderRadius(Theme.pillRadius)
                    .accessibilityText('回到今天')
                    .backgroundColor(Theme.tint)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.accent)
                    .onClick((): void => this.reset())
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
                }, (day: string) => day)
            }.width('100%')
            Grid() {
                ForEach(this.view.days, (cell: ScheduleDayCell) => {
                    GridItem() {
                        CalendarDayCell({
                            cell: cell,
                            selected: this.route.selectedDate === cell.day.date,
                            isToday: cell.day.date === this.state.localDate,
                            writable: !this.state.busy && !this.state.staleScopes.length,
                            onSelect: (): void => {
                                this.route.selectDate(cell.day.date);
                            },
                            onAddEvent: (): void => {
                                this.addEvent(cell.day.date);
                            },
                        })
                    }
                }, (cell: ScheduleDayCell) => cell.day.date + ':' + cell.events.length + ':' + cell.tasks.length + ':' + (this.route.selectedDate === cell.day.date ? '1' : '0'))
            }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
                .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
                .columnsGap(4)
                .rowsGap(4)
                .height(296)
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
            .border({ width: 0.8, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
            .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
    }
}
