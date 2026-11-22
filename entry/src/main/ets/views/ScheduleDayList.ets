import { curves, SymbolGlyphModifier } from '@kit.ArkUI';
import { daysUntil, displayName } from '../utils/format';
import { AppState } from '../viewmodels/ApplicationState';
import { CosEvent } from '../models/Entities';
import { ScheduleTaskItem, scheduleTaskRoute } from '../models/ScheduleView';
import { TaskQueueItem } from '../models/TaskQueue';
import { eventDateLabel, eventTimeLabel, schedulePhase } from '../models/Schedule';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { SectionHeading, EmptyState, PillTone, StatusPill } from '../components/Surfaces';

export function eventPhaseText(event: CosEvent, localDate: string): string {
    const phase = schedulePhase(event, localDate);
    if (phase === 'pending') {
        return '待定';
    }
    if (phase === 'today') {
        return '今天';
    }
    return phase === 'upcoming' ? daysUntil(event.date) + '天后' : '已过';
}

export function eventPhaseTone(event: CosEvent, localDate: string): PillTone {
    const phase = schedulePhase(event, localDate);
    return phase === 'today' ? 'warning' : phase === 'upcoming' ? 'brand' : 'neutral';
}

export function eventRowKey(event: CosEvent): string {
    return [
        event.id, event.name, event.dateMode, event.date, event.endDate,
        event.timeMode, event.startTime, event.endTime, event.city, event.venue, event.eventType, event.status,
    ].join(':');
}

export async function toggleEventAttendance(state: AppState, event: CosEvent): Promise<void> {
    if (state.busy || state.staleScopes.length) {
        return;
    }
    vibration.dotVibration();
    const copy = JSON.parse(JSON.stringify(event)) as CosEvent;
    copy.status = event.status === 'Attended' ? 'Planned' : 'Attended';
    await state.saveEvent(copy);
}

export function createScheduleSwipeActionOptions(
    startBuilder: CustomBuilder,
    endBuilder: CustomBuilder,
    onFullStart: () => void,
    onFullEnd: () => void,
): SwipeActionOptions {
    return {
        start: {
            builder: startBuilder,
            actionAreaDistance: 84,
            onEnterActionArea: (): void => {
                vibration.lightVibration();
            },
            onExitActionArea: (): void => {
                vibration.lightVibration();
            },
            onStateChange: (swipeState: SwipeActionState): void => {
                if (swipeState === SwipeActionState.EXPANDED) {
                    vibration.lightVibration();
                }
            },
            onAction: (): void => {
                vibration.dotVibration();
                onFullStart();
            },
        },
        end: {
            builder: endBuilder,
            actionAreaDistance: 84,
            onEnterActionArea: (): void => {
                vibration.lightVibration();
            },
            onExitActionArea: (): void => {
                vibration.lightVibration();
            },
            onStateChange: (swipeState: SwipeActionState): void => {
                if (swipeState === SwipeActionState.EXPANDED) {
                    vibration.lightVibration();
                }
            },
            onAction: (): void => {
                vibration.dotVibration();
                onFullEnd();
            },
        },
        edgeEffect: SwipeEdgeEffect.Spring,
    };
}

/** 左侧滑出（右滑触发）：完成 / 取消完成圆形按钮，与右侧编辑/删除分居两侧。 */
@ComponentV2
export struct ScheduleSwipeStartAction {
    @Param done: boolean = false;
    @Param label: string = '标为已完成';
    @Param writable: boolean = true;
    @Event action: () => void = () => {};

    build() {
        Row() {
            Button({ type: ButtonType.Circle, stateEffect: false }) {
                SymbolGlyph(this.done ? Icons.pending : Icons.done)
                    .fontSize(20)
                    .fontColor([Theme.onAccent])
                    .accessibilityLevel('no')
            }.width(44)
                .height(44)
                .backgroundColor(this.done ? Theme.warning : Theme.success)
                .enabled(this.writable)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.action();
                })
                .accessibilityText(this.label)
        }.padding({ right: 10 })
            .alignItems(VerticalAlign.Center)
    }
}

/** 右侧滑出（左滑触发）：编辑与删除圆形按钮。 */
@ComponentV2
export struct ScheduleSwipeEndActions {
    @Param editLabel: string = '编辑';
    @Param deleteLabel: string = '删除';
    @Param writable: boolean = true;
    @Event onEdit: () => void = () => {};
    @Event onDelete: () => void = () => {};

    build() {
        Row({ space: 8 }) {
            Button({ type: ButtonType.Circle, stateEffect: false }) {
                SymbolGlyph(Icons.edit)
                    .fontSize(20)
                    .fontColor([Theme.onAccent])
                    .accessibilityLevel('no')
            }.width(44)
                .height(44)
                .backgroundColor(Theme.brand)
                .enabled(this.writable)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.onEdit();
                })
                .accessibilityText(this.editLabel)
            Button({ type: ButtonType.Circle, stateEffect: false }) {
                SymbolGlyph(Icons.remove)
                    .fontSize(20)
                    .fontColor([Theme.onAccent])
                    .accessibilityLevel('no')
            }.width(44)
                .height(44)
                .backgroundColor(Theme.danger)
                .enabled(this.writable)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.onDelete();
                })
                .accessibilityText(this.deleteLabel)
        }.padding({ left: 10 })
            .alignItems(VerticalAlign.Center)
    }
}

/** 统一日程活动卡片，供列表页与日历详情复用，支持点击跳转与长按操作菜单。 */
@ComponentV2
export struct ScheduleEventCard {
    @Require @Param state: AppState;
    @Require @Param event: CosEvent;
    @Param phaseMode: boolean = false;
    @Event open: () => void = () => {};
    @Event onToggleDone: () => void = () => {};
    @Event onEdit: () => void = () => {};
    @Event onDelete: () => void = () => {};
    @Local pressed: boolean = false;
    @Local menuShown: boolean = false;
    private longPressTriggered: boolean = false;

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    @Builder eventContextMenu() {
        Menu() {
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.event).fontSize(18).fontColor([Theme.accent]),
                content: '查看详情',
            }).onClick((): void => {
                this.menuShown = false;
                vibration.dotVibration();
                this.open();
            })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(this.event.status === 'Attended' ? Icons.pending : Icons.done)
                    .fontSize(18)
                    .fontColor([this.event.status === 'Attended' ? Theme.warning : Theme.success]),
                content: this.event.status === 'Attended' ? '标为未完成' : '标为已完成',
            }).enabled(this.writable())
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onToggleDone();
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.edit).fontSize(18).fontColor([Theme.ink]),
                content: '编辑活动',
            }).enabled(this.writable())
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onEdit();
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.remove).fontSize(18).fontColor([Theme.danger]),
                content: '删除活动',
            }).contentFontColor(Theme.danger)
                .enabled(this.writable())
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onDelete();
                })
        }
    }

    build() {
        Row({ space: 12 }) {
            Column({ space: 2 }) {
                if (this.phaseMode) {
                    Text(eventPhaseText(this.event, this.state.localDate))
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(eventPhaseTone(this.event, this.state.localDate) === 'warning' ? Theme.warning :
                            eventPhaseTone(this.event, this.state.localDate) === 'brand' ? Theme.accent : Theme.muted)
                    Text(this.event.timeMode === 'none' ? '全天' : this.event.startTime)
                        .fontSize(11)
                        .fontColor(Theme.muted)
                } else {
                    Text(this.event.timeMode === 'none' ? '全天' : this.event.startTime)
                        .fontSize(this.event.timeMode === 'none' ? 12 : 14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.accent)
                    if (this.event.timeMode === 'range') {
                        Text(this.event.endTime)
                            .fontSize(10)
                            .fontColor(Theme.muted)
                    }
                }
            }.width(56)
                .height(46)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .borderRadius(Theme.slotRadius)
                .backgroundColor(this.phaseMode && eventPhaseTone(this.event, this.state.localDate) === 'warning' ? Theme.warningBg : Theme.tint)
                .flexShrink(0)
            Column({ space: 4 }) {
                Text(displayName(this.event.name))
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.event.status === 'Attended' ? Theme.muted : Theme.ink)
                    .decoration({ type: this.event.status === 'Attended' ? TextDecorationType.LineThrough : TextDecorationType.None })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 4 }) {
                    SymbolGlyph(Icons.location)
                        .fontSize(12)
                        .fontColor([Theme.muted])
                        .accessibilityLevel('no')
                    Text([this.event.city, this.event.venue].filter((value: string) => Boolean(value)).join(' ') || '地点待定')
                        .fontSize(12)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            Row({ space: 6 }) {
                if (this.event.status === 'Attended') {
                    StatusPill({ label: '已完成', tone: 'success', compact: true })
                } else if (this.event.eventType) {
                    StatusPill({ label: this.event.eventType, tone: eventPhaseTone(this.event, this.state.localDate), compact: true })
                }
                SymbolGlyph(Icons.chevronRightSymbol)
                    .fontSize(13)
                    .fontColor([Theme.muted])
                    .accessibilityLevel('no')
            }.alignItems(VerticalAlign.Center)
                .flexShrink(0)
        }.id('schedule-event:' + this.event.id)
            .width('100%')
            .constraintSize({ minHeight: 72 })
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .backgroundColor(Theme.surface)
            .border({ width: 0.8, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
            .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            .alignItems(VerticalAlign.Center)
            .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
            .animation({ duration: 130, curve: curves.springMotion(0.35, 0.9) })
            .onTouch((touchEvent: TouchEvent): void => {
                if (touchEvent.type === TouchType.Down) {
                    this.pressed = true;
                    this.longPressTriggered = false;
                } else if (touchEvent.type === TouchType.Up || touchEvent.type === TouchType.Cancel) {
                    this.pressed = false;
                }
            })
            .gesture(
                LongPressGesture({ duration: 350 })
                    .onAction((): void => {
                        this.longPressTriggered = true;
                        this.pressed = false;
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
                this.open();
            })
            .bindContextMenu(this.menuShown, this.eventContextMenu, {
                preview: MenuPreviewMode.IMAGE,
                aboutToDisappear: (): void => {
                    this.menuShown = false;
                },
                onDisappear: (): void => {
                    this.menuShown = false;
                },
            })
            .focusable(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('打开活动 ' + this.event.name + '，' + eventDateLabel(this.event) + '，' + eventTimeLabel(this.event))
            .accessibilityLevel('yes')
    }
}

/** 日程准备任务卡片，支持左圆环点击切换、350ms 长按菜单与轻触觉提示。 */
@ComponentV2
struct ScheduleTaskCard {
    @Require @Param state: AppState;
    @Require @Param item: ScheduleTaskItem;
    @Param writable: boolean = true;
    @Event open: () => void = () => {};
    @Event onToggleDone: () => void = () => {};
    @Event onEdit: () => void = () => {};
    @Event onDelete: () => void = () => {};
    @Local pressed: boolean = false;
    @Local menuShown: boolean = false;
    private longPressTriggered: boolean = false;

    private taskTone(): PillTone {
        if (this.item.task.done) {
            return 'success';
        }
        if (this.item.waiting) {
            return 'brand';
        }
        if (this.item.overdue) {
            return 'danger';
        }
        return 'warning';
    }

    private taskStatusText(): string {
        if (this.item.task.done) {
            return '已完成';
        }
        if (this.item.waiting) {
            return '在途';
        }
        if (this.item.overdue) {
            return '逾期';
        }
        return '待准备';
    }

    @Builder taskContextMenu() {
        Menu() {
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.plan).fontSize(18).fontColor([Theme.accent]),
                content: '查看所属计划',
            }).onClick((): void => {
                this.menuShown = false;
                vibration.dotVibration();
                this.open();
            })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(this.item.task.done ? Icons.pending : Icons.done)
                    .fontSize(18)
                    .fontColor([this.item.task.done ? Theme.warning : Theme.success]),
                content: this.item.task.done ? '取消完成' : '标记完成',
            }).enabled(this.writable)
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onToggleDone();
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.edit).fontSize(18).fontColor([Theme.ink]),
                content: '编辑任务',
            }).enabled(this.writable)
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onEdit();
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.remove).fontSize(18).fontColor([Theme.danger]),
                content: '删除任务',
            }).contentFontColor(Theme.danger)
                .enabled(this.writable)
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.onDelete();
                })
        }
    }

    build() {
        Row({ space: 12 }) {
            Button({ type: ButtonType.Circle, stateEffect: false }) {
                SymbolGlyph(this.item.task.done ? Icons.done : Icons.pending)
                    .fontSize(20)
                    .fontColor([this.item.task.done ? Theme.success : Theme.accent])
                    .accessibilityLevel('no')
            }.width(40)
                .height(40)
                .backgroundColor(this.item.task.done ? Theme.successBg : Theme.tint)
                .enabled(this.writable)
                .onClick((): void => {
                    this.onToggleDone();
                })
                .accessibilityText(this.item.task.label + (this.item.task.done ? '，已完成，取消完成' : '，未完成，标记完成'))
                .flexShrink(0)
            Column({ space: 4 }) {
                Text(displayName(this.item.task.label))
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.item.task.done ? Theme.muted : Theme.ink)
                    .decoration({ type: this.item.task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(displayName(this.item.projectName) + '  截止 ' + this.item.task.dueDate)
                    .fontSize(12)
                    .fontColor(Theme.muted)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            Row({ space: 6 }) {
                StatusPill({
                    label: this.taskStatusText(),
                    tone: this.taskTone(),
                    compact: true,
                })
                SymbolGlyph(Icons.chevronRightSymbol)
                    .fontSize(13)
                    .fontColor([Theme.muted])
                    .accessibilityLevel('no')
            }.alignItems(VerticalAlign.Center)
                .flexShrink(0)
        }.id('schedule-task:' + this.item.task.id)
            .width('100%')
            .constraintSize({ minHeight: 70 })
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .backgroundColor(Theme.surface)
            .border({ width: 0.8, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
            .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            .alignItems(VerticalAlign.Center)
            .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
            .animation({ duration: 130, curve: curves.springMotion(0.35, 0.9) })
            .onTouch((touchEvent: TouchEvent): void => {
                if (touchEvent.type === TouchType.Down) {
                    this.pressed = true;
                    this.longPressTriggered = false;
                } else if (touchEvent.type === TouchType.Up || touchEvent.type === TouchType.Cancel) {
                    this.pressed = false;
                }
            })
            .gesture(
                LongPressGesture({ duration: 350 })
                    .onAction((): void => {
                        this.longPressTriggered = true;
                        this.pressed = false;
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
                this.open();
            })
            .bindContextMenu(this.menuShown, this.taskContextMenu, {
                preview: MenuPreviewMode.IMAGE,
                aboutToDisappear: (): void => {
                    this.menuShown = false;
                },
                onDisappear: (): void => {
                    this.menuShown = false;
                },
            })
            .focusable(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('打开准备任务 ' + this.item.task.label + '，所属计划 ' + this.item.projectName)
            .accessibilityLevel('yes')
    }
}

@ComponentV2
export struct ScheduleDayList {
    @Require @Param state: AppState;
    @Param date: string = '';
    @Param events: CosEvent[] = [];
    @Param tasks: ScheduleTaskItem[] = [];
    @Param topInset: number = 0;
    @Param bottomInset: number = 24;
    @Param maxWidth: number = Theme.contentMaxWidth;
    @Param horizontalPadding: number = 0;
    @Param listId: string = 'schedule-day-list';
    @Param scroller: ListScroller = new ListScroller();
    @Event open: (kind: string, id: string) => void = () => {};
    @Event openTask: (item: TaskQueueItem) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string, onSettled?: () => void) => void = () => {};
    @Event didScroll: () => void = () => {};
    @Param showTopContent: boolean = false;
    @BuilderParam topContent: () => void = this.emptyTopContent;
    @Local taskError: string = '';

    @Builder emptyTopContent() {
    }

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    private closeSwipes(): void {
        try {
            this.scroller.closeAllSwipeActions();
        } catch (error) {
        }
    }

    private async toggle(item: ScheduleTaskItem): Promise<void> {
        if (!this.writable()) {
            return;
        }
        vibration.dotVibration();
        this.taskError = '';
        const current = this.state.preparationTasks.find((task) => task.id === item.task.id && task.projectId === item.task.projectId);
        if (!current) {
            vibration.errorVibration();
            this.taskError = '任务已不存在，请刷新后继续';
            return;
        }
        if (!(await this.state.togglePreparation(current))) {
            vibration.errorVibration();
            this.taskError = this.state.error || '任务未保存，请重试';
        }
    }

    @Builder eventSwipeStart(event: CosEvent) {
        ScheduleSwipeStartAction({
            done: event.status === 'Attended',
            label: event.status === 'Attended' ? '标为未完成' : '标为已完成',
            writable: this.writable(),
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

    @Builder taskSwipeStart(item: ScheduleTaskItem) {
        ScheduleSwipeStartAction({
            done: item.task.done,
            label: item.task.done ? '取消完成' : '标记完成',
            writable: this.writable(),
            action: (): void => {
                this.closeSwipes();
                void this.toggle(item);
            },
        })
    }

    @Builder taskSwipeEnd(item: ScheduleTaskItem) {
        ScheduleSwipeEndActions({
            editLabel: '编辑准备任务',
            deleteLabel: '删除准备任务',
            writable: this.writable(),
            onEdit: (): void => {
                this.closeSwipes();
                this.edit('preparation', item.task.id, item.task.projectId);
            },
            onDelete: (): void => {
                this.closeSwipes();
                this.remove('preparation', item.task.id, (): void => {
                    this.closeSwipes();
                });
            },
        })
    }

    build() {
        List({ space: 10, scroller: this.scroller }) {
            if (this.topInset > 0) {
                ListItem() {
                    Column() {
                        Blank().height(this.topInset).width('100%')
                    }.width('100%')
                }
            }
            if (this.showTopContent) {
                ListItem() {
                    this.topContent()
                }
            }
            ListItem() {
                Row({ space: 8 }) {
                    SectionHeading({
                        title: this.date,
                        icon: Icons.event,
                        trailing: this.events.length + ' 场活动  ' + this.tasks.length + ' 项任务',
                    }).layoutWeight(1)
                }.width('100%')
            }
            if (this.events.length > 0 || this.tasks.length > 0) {
                ListItem() {
                    Text('右滑标记完成，左滑编辑或删除，长按更多操作')
                        .fontSize(11)
                        .fontColor(Theme.muted)
                }
            }
            if (this.taskError) {
                ListItem() {
                    Row({ space: 8 }) {
                        SymbolGlyph(Icons.alert).fontSize(16).fontColor([Theme.danger]).accessibilityLevel('no')
                        Text(this.taskError)
                            .id('schedule-task-error')
                            .fontSize(13)
                            .fontColor(Theme.danger)
                            .layoutWeight(1)
                    }.padding(12)
                        .width('100%')
                        .borderRadius(Theme.controlRadius)
                        .backgroundColor(Theme.dangerBg)
                        .accessibilityText(this.taskError)
                }
            }
            ForEach(this.events, (event: CosEvent) => {
                ListItem() {
                    ScheduleEventCard({
                        state: this.state,
                        event: event,
                        phaseMode: false,
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
                ))
            }, (event: CosEvent) => eventRowKey(event))
            ForEach(this.tasks, (item: ScheduleTaskItem) => {
                ListItem() {
                    ScheduleTaskCard({
                        state: this.state,
                        item: item,
                        writable: this.writable(),
                        open: (): void => {
                            this.openTask(scheduleTaskRoute(item));
                        },
                        onToggleDone: (): void => {
                            this.closeSwipes();
                            void this.toggle(item);
                        },
                        onEdit: (): void => {
                            this.closeSwipes();
                            this.edit('preparation', item.task.id, item.task.projectId);
                        },
                        onDelete: (): void => {
                            this.closeSwipes();
                            this.remove('preparation', item.task.id, (): void => {
                                this.closeSwipes();
                            });
                        },
                    })
                }.swipeAction(createScheduleSwipeActionOptions(
                    (): void => {
                        this.taskSwipeStart(item);
                    },
                    (): void => {
                        this.taskSwipeEnd(item);
                    },
                    (): void => {
                        this.closeSwipes();
                        void this.toggle(item);
                    },
                    (): void => {
                        this.closeSwipes();
                        if (this.writable()) {
                            this.remove('preparation', item.task.id, (): void => {
                                this.closeSwipes();
                            });
                        }
                    },
                ))
            }, (item: ScheduleTaskItem) => item.task.id + ':' + item.task.done + ':' + item.task.label + ':' + item.task.dueDate + ':' + item.projectName)
            if (!this.events.length && !this.tasks.length) {
                ListItem() {
                    EmptyState({
                        title: '这天没有活动或截止任务',
                        message: '多天活动会显示在覆盖的每一天；任务截止日期在所属计划中设置。',
                        button: '添加当天活动',
                        icon: Icons.event,
                        action: (): void => {
                            this.add('event', this.date);
                        },
                    })
                }
            }
            ListItem() {
                Column() {
                    Blank().height(this.bottomInset).width('100%')
                }.width('100%')
            }
        }.id(this.listId)
            .width('100%')
            .height('100%')
            .constraintSize({ maxWidth: this.maxWidth })
            .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onDidScroll((): void => {
                this.didScroll();
            })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
