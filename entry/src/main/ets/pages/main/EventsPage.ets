import { LengthMetrics } from '@kit.ArkUI';
import { displayName } from '../../utils/format/format';
import { ContextRow } from '../../components/common/ContextRow';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../ui/animation/motion';
import { scrollByAxis } from '../../ui/layout/scroll';
import { ScheduleRoute } from '../../models/ScheduleRoute';
import { ScheduleView, buildScheduleView } from '../../domain/schedule/ScheduleView';
import { TaskQueueItem } from '../../domain/tasks/TaskQueue';
import { ScheduleDayList } from '../../components/schedule/ScheduleDayList';
import { EventCalendar } from '../../components/schedule/EventCalendar';
import { eventDateLabel, eventTimeLabel, ScheduleGroup } from '../../domain/schedule/Schedule';
import { vibration } from '../../ui/feedback/vibration';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { CosEvent } from '../../models/Entities';
import { EmptyState, SectionHeading } from '../../components/common/Surfaces';

@ComponentV2
export struct EventsPage {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
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
        this.feedback.dispose();
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
        this.getUIContext().showDatePickerDialog({ selected: new Date(this.route.selectedDate + 'T12:00:00'),
            onDateAccept: (date: Date): void => {
                this.route.selectDate(String(date.getFullYear()) + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0'));
                this.resetPosition();
            }
        });
    }

    @Builder content(e: CosEvent) {
        Row({ space: 12 }) {
            Column({ space: 5 }) {
                Text(e.timeMode === 'none' ? '未标记' : e.startTime)
                    .fontSize(e.timeMode === 'none' ? 12 : 17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.ink)
                if (e.timeMode === 'range') {
                    Text(e.endTime).fontSize(12).fontColor(Theme.muted)
                }
            }.width(60).alignItems(HorizontalAlign.Start)
            Rect().width(3).height(42).fill(Theme.brand).radius(2)
            Column({ space: 6 }) {
                Text(displayName(e.name)).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2)
                Text([e.city, e.venue].filter((value: string) => Boolean(value)).join(' ') || '地点待定')
                    .fontSize(14)
                    .fontColor(Theme.muted)
                    .maxLines(2)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').padding(16)
    }

    build() {
        Column({ space: 12 }) {
            Scroll(this.scroller) {
                Column({ space: 14 }) {
                    Column({ space: 14 }) {
                        Blank().height(this.topInset).width('100%')
                        Flex({ space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }, wrap: FlexWrap.Wrap }) {
                            if (!this.route.calendar && !this.route.dateFocused) {
                                Select([{ value: '全部日期' }, { value: '已结束' }, { value: '日期待定' }, { value: '今天' }, { value: '即将到来' }])
                                    .value(['全部日期', '已结束', '日期待定', '今天', '即将到来'][this.route.filter]).constraintSize({ minHeight: 48 })
                                    .onSelect((index: number): void => {
                                        vibration.dotVibration();
                                        this.route.filter = index;
                                        this.route.dateFocused = false;
                                        this.resetPosition();
                                    })
                                    .id('event-list-filter').accessibilityText('活动日期筛选')
                            }
                            Select(this.typeOptions()).value(this.route.eventType || '全部类型').constraintSize({ minHeight: 48 })
                                .onSelect((index: number): void => {
                                    this.route.eventType = index === 0 ? '' : this.types()[index - 1];
                                    this.resetPosition();
                                }).accessibilityText('活动类型筛选')
                        }.width('100%')
                        if (!this.route.calendar) {
                            Row({ space: 8 }) {
                                Button(this.route.dateFocused ? this.route.selectedDate : '选择日期')
                                    .id('schedule-date-picker')
                                    .type(ButtonType.Normal)
                                    .constraintSize({ minHeight: 48 })
                                    .backgroundColor(Color.Transparent).fontColor(Theme.accent).onClick((): void => {
                                        this.chooseDate();
                                    }).accessibilityText('选择要查看的日程日期')
                                if (this.route.dateFocused) {
                                    Button('全部日程')
                                        .id('schedule-clear-date')
                                        .type(ButtonType.Normal)
                                        .constraintSize({ minHeight: 48 })
                                        .backgroundColor(Color.Transparent)
                                        .fontColor(Theme.muted)
                                        .onClick((): void => {
                                            this.route.clearDate();
                                            this.resetPosition();
                                        })
                                } else {
                                    Button('今天')
                                        .type(ButtonType.Normal)
                                        .constraintSize({ minHeight: 48 })
                                        .backgroundColor(Color.Transparent)
                                        .fontColor(Theme.accent)
                                        .onClick((): void => {
                                            this.route.selectDate(this.state.localDate);
                                            this.resetPosition();
                                        })
                                }
                            }.width('100%')
                        }
                    }
                        .width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
                    Column({ space: 14 }) {
                        if (this.view.pendingCount > 0 && (this.route.calendar || this.route.dateFocused)) {
                            Button() {
                                ContextRow({ label: '日期待定', text: this.view.pendingCount + ' 场活动' })
                            }.type(ButtonType.Normal).id('schedule-pending-entry').width('100%').constraintSize({ minHeight: 48 })
                                .backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => {
                                    this.route.showPending();
                                    this.resetPosition();
                                })
                        }
                        if (this.route.calendar) {
                            EventCalendar({
                                state: this.state, route: this.route, view: this.view,
                                openTask: (item: TaskQueueItem): void => {
                                    this.openTask(item);
                                },
                                open: (kind: string, id: string): void => this.open(kind, id),
                                add: (kind: string, parent: string): void => this.add(kind, parent)
                            })
                        } else if (this.route.dateFocused) {
                            ScheduleDayList({ state: this.state, date: this.route.selectedDate, events: this.view.selectedEvents, tasks: this.view.selectedTasks,
                                open: (kind: string, id: string): void => {
                                    this.open(kind, id);
                                }, openTask: (item: TaskQueueItem): void => {
                                    this.openTask(item);
                                },
                                add: (kind: string, parent: string): void => {
                                    this.add(kind, parent);
                                }
                            })
                        } else {
                            ForEach(this.groups(), (group: ScheduleGroup) => {
                                if (group.events.length > 0) {
                                    SectionHeading({ title: group.label, trailing: group.events.length + ' 场' })
                                }
                                ForEach(group.events, (event: CosEvent, index: number) => {
                                    if (event.dateMode !== 'pending' && (index === 0 || eventDateLabel(group.events[index - 1]) !== eventDateLabel(event))) {
                                        Text(eventDateLabel(event)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink).padding({ top: 8, bottom: 2 })
                                    }
                                    Button() {
                                        this.content(event)
                                    }.id('schedule-event:' + event.id).type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 64 })
                                        .backgroundColor(Theme.surface).borderRadius(14).onClick((): void => {
                                            this.open('event', event.id);
                                        })
                                        .accessibilityText('打开活动 ' + event.name + '，' + eventDateLabel(event) + '，' + eventTimeLabel(event))
                                }, (event: CosEvent) => event.id)
                            }, (group: ScheduleGroup) => group.label)
                            if (this.events().length === 0) {
                                EmptyState({
                                    title: this.state.events.length ? '没有匹配的活动' : '下一场见面，值得期待',
                                    message: this.state.events.length ? '可以清除日期和类型筛选，查看全部活动。' : '记录活动日期，关联准备中的计划。',
                                    button: this.state.events.length ? '清除筛选' : '＋ 添加活动',
                                    action: (): void => {
                                        if (this.state.events.length) {
                                            this.route.eventType = '';
                                            this.route.clearDate();
                                            this.resetPosition();
                                        } else {
                                            this.add('event', '');
                                        }
                                    }
                                })
                            }
                        }
                    }
                        .width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
                    Blank().height(this.bottomInset).width('100%')
                }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth })
            }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
                .onDidScroll((): void => {
                    if (!this.restoring) {
                        this.route.offsets[this.displayedMode] = this.scroller.currentOffset().yOffset;
                    }
                })
        }.width('100%').height('100%')
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
