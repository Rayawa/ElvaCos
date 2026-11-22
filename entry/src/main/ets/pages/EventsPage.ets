import { LengthMetrics } from '@kit.ArkUI';
import { ContextRow } from '../components/ContextRow';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { RESPONSIVE_MEDIUM_WIDTH } from '../ui/responsive';
import { ScheduleRoute } from '../viewmodels/ScheduleRoute';
import { ScheduleView, buildScheduleView } from '../models/ScheduleView';
import { TaskQueueItem } from '../models/TaskQueue';
import { ScheduleDayList, ScheduleEventCard, ScheduleSwipeStartAction, ScheduleSwipeEndActions, createScheduleSwipeActionOptions, eventRowKey, toggleEventAttendance } from '../views/ScheduleDayList';
import { EventCalendar } from '../views/EventCalendar';
import { eventDateLabel, ScheduleGroup } from '../models/Schedule';
import { vibration } from '../ui/vibration';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { CosEvent } from '../models/Entities';
import { InteractiveCard, EmptyState, SectionHeading } from '../components/Surfaces';

@ComponentV2
export struct EventsPage {
    @Param scroller: ListScroller = new ListScroller();
    @Param topInset: number = 100;
    @Param bottomInset: number = 110;
    @Require @Param state: AppState;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string, onSettled?: () => void) => void = () => {};
    @Require @Param route: ScheduleRoute;
    @Event openTask: (item: TaskQueueItem) => void = () => {};
    @Param entranceSession: MainEntranceSession = new MainEntranceSession();
    @Param active: boolean = false;
    private wideDayScroller: ListScroller = new ListScroller();
    private displayedMode: number = 0;
    private restoring: boolean = true;
    private restoreTimer: number = -1;
    @Local animStep: number = 0;
    @Local contentWidth: number = 360;
    @Local activeSwipeKey: string = '';
    @Local activeStartKey: string = '';
    @Local activeDeleteKey: string = '';
    @Local activePullExtra: number = 0;
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

    @Builder pendingEntryContent() {
        ContextRow({ label: '日期待定', text: this.view.pendingCount + ' 场活动待安排日程' })
    }

    @Builder filterControls() {
        Column({ space: 10 }) {
            Flex({ space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }, wrap: FlexWrap.Wrap }) {
                if (!this.route.calendar && !this.route.dateFocused) {
                    Select([{ value: '全部日期' }, { value: '已结束' }, { value: '日期待定' }, { value: '今天' }, { value: '即将到来' }])
                        .value(['全部日期', '已结束', '日期待定', '今天', '即将到来'][this.route.filter])
                        .constraintSize({ minHeight: 34 })
                        .backgroundColor(Theme.surface)
                        .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                        .borderRadius(Theme.pillRadius)
                        .clip(true)
                        .onSelect((index: number): void => {
                            vibration.dotVibration();
                            this.route.filter = index;
                            this.route.dateFocused = false;
                            this.resetPosition();
                        })
                        .id('event-list-filter')
                        .accessibilityText('活动日期筛选')
                        .controlSize(ControlSize.SMALL)
                        .font({ size: 12 })
                }
                Select(this.typeOptions())
                    .value(this.route.eventType || '全部类型')
                    .constraintSize({ minHeight: 34 })
                    .backgroundColor(Theme.surface)
                    .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                    .borderRadius(Theme.pillRadius)
                    .clip(true)
                    .onSelect((index: number): void => {
                        vibration.dotVibration();
                        this.route.eventType = index === 0 ? '' : this.types()[index - 1];
                        this.resetPosition();
                    })
                    .accessibilityText('活动类型筛选')
                    .controlSize(ControlSize.SMALL)
                    .font({ size: 12 })
            }.width('100%')
            if (!this.route.calendar) {
                Row({ space: 8 }) {
                    Button(this.route.dateFocused ? this.route.selectedDate : '选择日期', { type: ButtonType.Capsule, stateEffect: false })
                        .id('schedule-date-picker')
                        .height(32)
                        .padding({ left: 12, right: 12 })
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(Theme.tint)
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.accent)
                        .onClick((): void => {
                            this.chooseDate();
                        })
                        .accessibilityText('选择要查看的日程日期')
                    if (this.route.dateFocused) {
                        Button('全部日程', { type: ButtonType.Capsule, stateEffect: false })
                            .id('schedule-clear-date')
                            .height(32)
                            .padding({ left: 12, right: 12 })
                            .backgroundColor(Theme.surface)
                            .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                            .borderRadius(Theme.pillRadius)
                            .fontSize(12)
                            .fontColor(Theme.muted)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.route.clearDate();
                                this.resetPosition();
                            })
                    } else {
                        Button('今天', { type: ButtonType.Capsule, stateEffect: false })
                            .height(32)
                            .padding({ left: 12, right: 12 })
                            .backgroundColor(Theme.surface)
                            .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                            .borderRadius(Theme.pillRadius)
                            .fontSize(12)
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
    }

    @Builder pendingBanner() {
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
    }

    @Builder calendarTopContent() {
        Column({ space: 12 }) {
            this.filterControls()
            this.pendingBanner()
            if (this.route.calendar) {
                EventCalendar({
                    state: this.state,
                    route: this.route,
                    view: this.view,
                    addEvent: (date: string): void => {
                        this.add('event', date);
                    },
                })
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
            .opacity(this.animStep >= 2 ? 1 : 0)
    }

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    private closeSwipes(): void {
        this.activeSwipeKey = '';
        this.activeStartKey = '';
        this.activeDeleteKey = '';
        this.activePullExtra = 0;
        try {
            this.scroller.closeAllSwipeActions();
        } catch (error) {
        }
    }

    private updateSwipeOffset(key: string, offset: number): void {
        if (offset === 0 && this.activeSwipeKey === key) {
            this.activeSwipeKey = '';
            this.activePullExtra = 0;
            return;
        }
        if (offset < 0) {
            this.activeSwipeKey = key;
            const baseWidth = 98 + Theme.pagePadding;
            const nextExtra = offset < -baseWidth ? Math.min(120, Math.round(-offset - baseWidth)) : 0;
            if (nextExtra !== this.activePullExtra) {
                this.activePullExtra = nextExtra;
            }
        }
    }

    @Builder eventSwipeStart(event: CosEvent) {
        ScheduleSwipeStartAction({
            done: event.status === 'Attended',
            label: event.status === 'Attended' ? '标为未完成' : '标为已完成',
            writable: this.writable(),
            actionActive: this.activeStartKey === 'event:' + event.id,
            edgePadding: Theme.pagePadding,
            action: (): void => {
                this.closeSwipes();
                void toggleEventAttendance(this.state, event);
            },
        })
    }

    @Builder eventSwipeEnd(event: CosEvent) {
        ScheduleSwipeEndActions({
            editLabel: '编辑活动',
            deleteLabel: '删除活动',
            writable: this.writable(),
            deleteActive: this.activeDeleteKey === 'event:' + event.id,
            pullExtra: this.activeSwipeKey === 'event:' + event.id ? this.activePullExtra : 0,
            edgePadding: Theme.pagePadding,
            onEdit: (): void => {
                this.closeSwipes();
                this.edit('event', event.id, '');
            },
            onDelete: (): void => {
                this.closeSwipes();
                this.remove('event', event.id, (): void => {
                    this.closeSwipes();
                });
            },
        })
    }

    @Builder wideCalendarLayout() {
        Row({ space: 20 }) {
            Scroll() {
                Column({ space: 14 }) {
                    Blank().height(this.topInset).width('100%')
                    this.filterControls()
                    this.pendingBanner()
                    EventCalendar({
                        state: this.state,
                        route: this.route,
                        view: this.view,
                        addEvent: (date: string): void => {
                            this.add('event', date);
                        },
                    })
                    Blank().height(this.bottomInset).width('100%')
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
                    .opacity(this.animStep >= 2 ? 1 : 0)
            }.layoutWeight(7)
                .height('100%')
                .padding({ left: Theme.pagePadding })
                .align(Alignment.Top)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
            Column() {
                ScheduleDayList({
                    state: this.state,
                    date: this.route.selectedDate,
                    events: this.view.selectedEvents,
                    tasks: this.view.selectedTasks,
                    topInset: this.topInset,
                    bottomInset: this.bottomInset,
                    horizontalPadding: Theme.pagePadding,
                    leadingPadding: 0,
                    scroller: this.wideDayScroller,
                    showTopContent: false,
                    open: (kind: string, id: string): void => {
                        this.open(kind, id);
                    },
                    openTask: (item: TaskQueueItem): void => {
                        this.openTask(item);
                    },
                    add: (kind: string, parent: string): void => {
                        this.add(kind, parent);
                    },
                    edit: (kind: string, id: string, parent: string): void => {
                        this.edit(kind, id, parent);
                    },
                    remove: (kind: string, id: string, onSettled?: () => void): void => {
                        this.remove(kind, id, onSettled);
                    },
                })
            }.layoutWeight(5)
                .height('100%')
        }.width('100%')
            .height('100%')
            .constraintSize({ maxWidth: Theme.contentMaxWidth })
            .alignItems(VerticalAlign.Top)
    }

    @Builder listModeLayout() {
        List({ space: 10, scroller: this.scroller }) {
            if (this.topInset > 0) {
                ListItem() {
                    Column() {
                        Blank().height(this.topInset).width('100%')
                    }.width('100%')
                }
            }
            ListItem() {
                Column() {
                    this.filterControls()
                }.width('100%')
                    .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
            }
            if (this.events().length > 0) {
                ListItem() {
                    Text('右滑标记完成，左滑可编辑、继续左拉到底删除，长按更多操作')
                        .width('100%')
                        .fontSize(11)
                        .fontColor(Theme.muted)
                        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                }
            }
            ForEach(this.groups(), (group: ScheduleGroup) => {
                if (group.events.length > 0) {
                    ListItem() {
                        Column() {
                            SectionHeading({
                                title: group.label,
                                trailing: group.events.length + ' 场',
                                icon: Icons.event,
                            })
                        }.width('100%')
                            .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                    }
                    ForEach(group.events, (event: CosEvent, index: number) => {
                        if (event.dateMode !== 'pending' && (index === 0 || eventDateLabel(group.events[index - 1]) !== eventDateLabel(event))) {
                            ListItem() {
                                Text(eventDateLabel(event))
                                    .width('100%')
                                    .fontSize(13)
                                    .fontWeight(FontWeight.Medium)
                                    .fontColor(Theme.muted)
                                    .padding({ left: Theme.pagePadding, right: Theme.pagePadding, top: 4, bottom: 2 })
                            }
                        }
                        ListItem() {
                            Column() {
                                ScheduleEventCard({
                                    state: this.state,
                                    event: event,
                                    phaseMode: true,
                                    open: (): void => {
                                        this.open('event', event.id);
                                    },
                                    onToggleDone: (): void => {
                                        this.closeSwipes();
                                        void toggleEventAttendance(this.state, event);
                                    },
                                    onEdit: (): void => {
                                        this.closeSwipes();
                                        this.edit('event', event.id, '');
                                    },
                                    onDelete: (): void => {
                                        this.closeSwipes();
                                        this.remove('event', event.id, (): void => {
                                            this.closeSwipes();
                                        });
                                    },
                                })
                            }.width('100%')
                                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                        }.swipeAction(createScheduleSwipeActionOptions(
                            (): void => {
                                this.eventSwipeStart(event);
                            },
                            (): void => {
                                this.eventSwipeEnd(event);
                            },
                            (): void => {
                                this.closeSwipes();
                                void toggleEventAttendance(this.state, event);
                            },
                            (): void => {
                                this.closeSwipes();
                                if (this.writable()) {
                                    this.remove('event', event.id, (): void => {
                                        this.closeSwipes();
                                    });
                                }
                            },
                            (active: boolean): void => {
                                this.activeStartKey = active ? 'event:' + event.id : (this.activeStartKey === 'event:' + event.id ? '' : this.activeStartKey);
                            },
                            (active: boolean): void => {
                                this.activeDeleteKey = active ? 'event:' + event.id : (this.activeDeleteKey === 'event:' + event.id ? '' : this.activeDeleteKey);
                            },
                            (offset: number): void => {
                                this.updateSwipeOffset('event:' + event.id, offset);
                            },
                        ))
                    }, (event: CosEvent) => eventRowKey(event))
                }
            }, (group: ScheduleGroup) => group.label + ':' + group.events.map((event: CosEvent) => eventRowKey(event)).join('|'))
            if (this.events().length === 0) {
                ListItem() {
                    Column() {
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
                    }.width('100%')
                        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                }
            }
            ListItem() {
                Column() {
                    Blank().height(this.bottomInset).width('100%')
                }.width('100%')
            }
        }.id('schedule-event-list')
            .width('100%')
            .height('100%')
            .constraintSize({ maxWidth: Theme.readingMaxWidth })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onDidScroll((): void => {
                if (!this.restoring) {
                    this.route.offsets[this.displayedMode] = this.scroller.currentOffset().yOffset;
                }
            })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }

    build() {
        Column() {
            if (this.route.calendar && this.contentWidth >= RESPONSIVE_MEDIUM_WIDTH) {
                this.wideCalendarLayout()
            } else if (this.route.calendar || this.route.dateFocused) {
                ScheduleDayList({
                    state: this.state,
                    date: this.route.selectedDate,
                    events: this.view.selectedEvents,
                    tasks: this.view.selectedTasks,
                    topInset: this.topInset,
                    bottomInset: this.bottomInset,
                    maxWidth: Theme.contentMaxWidth,
                    horizontalPadding: Theme.pagePadding,
                    scroller: this.scroller,
                    showTopContent: true,
                    topContent: (): void => {
                        this.calendarTopContent();
                    },
                    open: (kind: string, id: string): void => {
                        this.open(kind, id);
                    },
                    openTask: (item: TaskQueueItem): void => {
                        this.openTask(item);
                    },
                    add: (kind: string, parent: string): void => {
                        this.add(kind, parent);
                    },
                    edit: (kind: string, id: string, parent: string): void => {
                        this.edit(kind, id, parent);
                    },
                    remove: (kind: string, id: string, onSettled?: () => void): void => {
                        this.remove(kind, id, onSettled);
                    },
                    didScroll: (): void => {
                        if (!this.restoring) {
                            this.route.offsets[this.displayedMode] = this.scroller.currentOffset().yOffset;
                        }
                    },
                })
            } else {
                this.listModeLayout()
            }
        }.width('100%')
            .height('100%')
            .alignItems(HorizontalAlign.Center)
            .onAreaChange((_old: Area, area: Area): void => {
                this.contentWidth = Number(area.width);
            })
    }
}
