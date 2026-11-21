import { LengthMetrics } from '@kit.ArkUI';
import { daysUntil, displayName } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { MetaRow } from '../components/MetaRow';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { ScheduleRoute } from '../viewmodels/ScheduleRoute';
import { ScheduleView, buildScheduleView } from '../models/ScheduleView';
import { TaskQueueItem } from '../models/TaskQueue';
import { ScheduleDayList } from '../views/ScheduleDayList';
import { EventCalendar } from '../views/EventCalendar';
import { eventDateLabel, eventTimeLabel, ScheduleGroup, schedulePhase } from '../models/Schedule';
import { vibration } from '../ui/vibration';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { CosEvent } from '../models/Entities';
import { InteractiveCard, EmptyState, SectionHeading, StatusPill, PillTone } from '../components/Surfaces';

@ComponentV2
export struct EventsPage {
    @Param scroller: Scroller = new Scroller();
    @Param topInset: number = 100;
    @Param bottomInset: number = 110;
    @Require @Param state: AppState;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Require @Param route: ScheduleRoute;
    @Event openTask: (item: TaskQueueItem) => void = () => {};
    @Param entranceSession: MainEntranceSession = new MainEntranceSession();
    @Param active: boolean = false;
    private displayedMode: number = 0;
    private restoring: boolean = true;
    private restoreTimer: number = -1;
    @Local animStep: number = 0;
    private enterPlayed: boolean = false;
    private enterTimers: number[] = [];

    aboutToAppear(): void {
        this.restore();
        if (this.active) {
            this.enter();
        }
    }

    @Monitor('active')
    activeChanged(): void {
        if (this.active) {
            this.enter();
            this.restore();
        }
    }

    private enter(): void {
        if (this.enterPlayed) {
            return;
        }
        this.enterPlayed = true;
        if (!this.entranceSession.claim('EventsPage')) {
            this.animStep = 2;
            return;
        }
        this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => {
            this.animStep = step;
        });
    }

    aboutToDisappear(): void {
        cancelStaggerEnterAnimation(this.enterTimers);
        this.enterTimers = [];
        this.animStep = 2;
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
    }

    @Monitor('route.calendar')
    private modeChanged(): void {
        this.restore();
    }

    private restore(): void {
        this.restoring = true;
        this.displayedMode = this.route.calendar ? 1 : 0;
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedMode], animation: false });
            this.restoring = false;
        }, 0);
    }

    private resetPosition(): void {
        this.route.offsets[this.route.calendar ? 1 : 0] = 0;
        if (!this.restoring) {
            this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
        }
    }

    @Computed
    private get view(): ScheduleView {
        return buildScheduleView(this.state.events, this.state.readinessPlans, this.state.projects, this.route, this.state.localDate);
    }

    private groups(): ScheduleGroup[] {
        return this.view.groups;
    }

    private events(): CosEvent[] {
        return this.groups().reduce((events: CosEvent[], group: ScheduleGroup) => events.concat(group.events), []);
    }

    private typeOptions(): SelectOption[] {
        const options: SelectOption[] = [{ value: '全部类型' }];
        return options.concat(this.types().map((type: string): SelectOption => {
            return { value: type };
        }));
    }

    private types(): string[] {
        return Array.from(new Set(this.state.events.map((event: CosEvent) => event.eventType)));
    }

    private chooseDate(): void {
        vibration.dotVibration();
        this.getUIContext().showDatePickerDialog({
            selected: new Date(this.route.selectedDate + 'T12:00:00'),
            onDateAccept: (date: Date): void => {
                vibration.dotVibration();
                this.route.selectDate(String(date.getFullYear()) + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0'));
                this.resetPosition();
            },
        });
    }

    private countdownText(e: CosEvent): string {
        const phase = schedulePhase(e, this.state.localDate);
        if (phase === 'pending') {
            return '待定';
        }
        if (phase === 'today') {
            return '今天';
        }
        return phase === 'upcoming' ? daysUntil(e.date) + '天后' : '已过';
    }

    private countdownTone(e: CosEvent): PillTone {
        const phase = schedulePhase(e, this.state.localDate);
        return phase === 'today' ? 'warning' : phase === 'upcoming' ? 'brand' : 'neutral';
    }

    @Builder pendingEntryContent() {
        ContextRow({ label: '日期待定', text: this.view.pendingCount + ' 场活动待安排日程' })
    }

    @Builder eventCardBody(e: CosEvent) {
        Row({ space: 12 }) {
            Column({ space: 3 }) {
                Text(this.countdownText(e))
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.countdownTone(e) === 'warning' ? Theme.warning : this.countdownTone(e) === 'brand' ? Theme.accent : Theme.muted)
                Text(e.timeMode === 'none' ? '全天' : e.startTime)
                    .fontSize(11)
                    .fontColor(Theme.muted)
                if (e.timeMode === 'range') {
                    Text(e.endTime).fontSize(10).fontColor(Theme.muted)
                }
            }.width(64)
                .padding({ top: 8, bottom: 8 })
                .borderRadius(Theme.slotRadius)
                .backgroundColor(this.countdownTone(e) === 'warning' ? Theme.warningBg : Theme.tint)
                .alignItems(HorizontalAlign.Center)
            Column({ space: 5 }) {
                Row({ space: 8 }) {
                    Text(displayName(e.name))
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                    if (e.eventType) {
                        StatusPill({ label: e.eventType, tone: this.countdownTone(e), compact: true })
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Top)
                MetaRow({
                    icon: Icons.location,
                    text: [e.city, e.venue].filter((value: string) => Boolean(value)).join(' ') || '地点待定',
                })
            }.alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(14)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }

    build() {
        Column({ space: 12 }) {
            Scroll(this.scroller) {
                Column({ space: 14 }) {
                    Column({ space: 10 }) {
                        Blank().height(this.topInset).width('100%')
                        Flex({ space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }, wrap: FlexWrap.Wrap }) {
                            if (!this.route.calendar && !this.route.dateFocused) {
                                Select([{ value: '全部日期' }, { value: '已结束' }, { value: '日期待定' }, { value: '今天' }, { value: '即将到来' }])
                                    .value(['全部日期', '已结束', '日期待定', '今天', '即将到来'][this.route.filter])
                                    .constraintSize({ minHeight: 36 })
                                    .backgroundColor(Theme.surface)
                                    .borderRadius(12)
                                    .onSelect((index: number): void => {
                                        vibration.dotVibration();
                                        this.route.filter = index;
                                        this.route.dateFocused = false;
                                        this.resetPosition();
                                    })
                                    .id('event-list-filter')
                                    .accessibilityText('活动日期筛选')
                                    .controlSize(ControlSize.SMALL)
                                    .font({ size: 13 })
                            }
                            Select(this.typeOptions())
                                .value(this.route.eventType || '全部类型')
                                .constraintSize({ minHeight: 36 })
                                .backgroundColor(Theme.surface)
                                .borderRadius(12)
                                .onSelect((index: number): void => {
                                    vibration.dotVibration();
                                    this.route.eventType = index === 0 ? '' : this.types()[index - 1];
                                    this.resetPosition();
                                })
                                .accessibilityText('活动类型筛选')
                                .controlSize(ControlSize.SMALL)
                                .font({ size: 13 })
                        }.width('100%')
                        if (!this.route.calendar) {
                            Row({ space: 8 }) {
                                Button(this.route.dateFocused ? this.route.selectedDate : '选择日期', { type: ButtonType.Normal, stateEffect: false })
                                    .id('schedule-date-picker')
                                    .height(34)
                                    .padding({ left: 12, right: 12 })
                                    .borderRadius(12)
                                    .backgroundColor(Theme.tint)
                                    .fontSize(13)
                                    .fontColor(Theme.accent)
                                    .onClick((): void => {
                                        this.chooseDate();
                                    })
                                    .accessibilityText('选择要查看的日程日期')
                                if (this.route.dateFocused) {
                                    Button('全部日程', { type: ButtonType.Normal, stateEffect: false })
                                        .id('schedule-clear-date')
                                        .height(34)
                                        .padding({ left: 12, right: 12 })
                                        .borderRadius(12)
                                        .backgroundColor(Theme.surface)
                                        .border({ width: 0.8, color: Theme.line })
                                        .fontSize(13)
                                        .fontColor(Theme.muted)
                                        .onClick((): void => {
                                            vibration.dotVibration();
                                            this.route.clearDate();
                                            this.resetPosition();
                                        })
                                } else {
                                    Button('今天', { type: ButtonType.Normal, stateEffect: false })
                                        .height(34)
                                        .padding({ left: 12, right: 12 })
                                        .borderRadius(12)
                                        .backgroundColor(Theme.surface)
                                        .border({ width: 0.8, color: Theme.line })
                                        .fontSize(13)
                                        .fontColor(Theme.accent)
                                        .onClick((): void => {
                                            vibration.dotVibration();
                                            this.route.selectDate(this.state.localDate);
                                            this.resetPosition();
                                        })
                                }
                            }.width('100%')
                        }
                    }.width('100%')
                        .alignItems(HorizontalAlign.Start)
                        .opacity(this.animStep >= 1 ? 1 : 0)
                        .translate({ y: this.animStep >= 1 ? 0 : 20 })
                    Column({ space: 14 }) {
                        if (this.view.pendingCount > 0 && (this.route.calendar || this.route.dateFocused)) {
                            InteractiveCard({
                                label: '查看日期待定的 ' + this.view.pendingCount + ' 场活动',
                                effects: this.state.settings.effects,
                                contentPadding: 12,
                                action: (): void => {
                                    this.route.showPending();
                                    this.resetPosition();
                                },
                                content: (): void => {
                                    this.pendingEntryContent()
                                },
                            }).id('schedule-pending-entry')
                        }
                        if (this.route.calendar) {
                            EventCalendar({
                                state: this.state,
                                route: this.route,
                                view: this.view,
                                openTask: (item: TaskQueueItem): void => {
                                    this.openTask(item);
                                },
                                open: (kind: string, id: string): void => this.open(kind, id),
                                add: (kind: string, parent: string): void => this.add(kind, parent),
                            })
                        } else if (this.route.dateFocused) {
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
                        } else {
                            ForEach(this.groups(), (group: ScheduleGroup) => {
                                if (group.events.length > 0) {
                                    SectionHeading({ title: group.label, trailing: group.events.length + ' 场', icon: Icons.event })
                                }
                                ForEach(group.events, (event: CosEvent, index: number) => {
                                    if (event.dateMode !== 'pending' && (index === 0 || eventDateLabel(group.events[index - 1]) !== eventDateLabel(event))) {
                                        Text(eventDateLabel(event))
                                            .fontSize(14)
                                            .fontWeight(FontWeight.Medium)
                                            .fontColor(Theme.muted)
                                            .padding({ top: 6, bottom: 2 })
                                    }
                                    InteractiveCard({
                                        label: '打开活动 ' + event.name + '，' + eventDateLabel(event) + '，' + eventTimeLabel(event),
                                        hint: '双击查看活动详情',
                                        effects: this.state.settings.effects,
                                        contentPadding: 14,
                                        action: (): void => {
                                            this.open('event', event.id);
                                        },
                                        content: (): void => {
                                            this.eventCardBody(event);
                                        },
                                    }).id('schedule-event:' + event.id)
                                }, (event: CosEvent) => event.id)
                            }, (group: ScheduleGroup) => group.label)
                            if (this.events().length === 0) {
                                EmptyState({
                                    title: this.state.events.length ? '没有匹配的活动' : '下一场见面，值得期待',
                                    message: this.state.events.length ? '可以清除日期和类型筛选，查看全部活动。' : '记录活动日期，关联准备中的计划。',
                                    button: this.state.events.length ? '清除筛选' : '添加活动',
                                    icon: Icons.event,
                                    action: (): void => {
                                        if (this.state.events.length) {
                                            this.route.eventType = '';
                                            this.route.clearDate();
                                            this.resetPosition();
                                        } else {
                                            this.add('event', '');
                                        }
                                    },
                                })
                            }
                        }
                    }.width('100%')
                        .alignItems(HorizontalAlign.Start)
                        .opacity(this.animStep >= 2 ? 1 : 0)
                        .translate({ y: this.animStep >= 2 ? 0 : 20 })
                    Blank().height(this.bottomInset).width('100%')
                }.padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                    .width('100%')
                    .constraintSize({ maxWidth: Theme.contentMaxWidth })
            }.layoutWeight(1)
                .width('100%')
                .scrollBar(BarState.Off)
                .align(Alignment.Top)
                .edgeEffect(EdgeEffect.Spring)
                .onDidScroll((): void => {
                    if (!this.restoring) {
                        this.route.offsets[this.displayedMode] = this.scroller.currentOffset().yOffset;
                    }
                })
        }.width('100%')
            .height('100%')
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
