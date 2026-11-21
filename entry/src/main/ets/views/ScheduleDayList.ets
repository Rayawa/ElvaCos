import { displayName } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { MetaRow } from '../components/MetaRow';
import { AppState } from '../viewmodels/ApplicationState';
import { CosEvent } from '../models/Entities';
import { ScheduleTaskItem, scheduleTaskRoute } from '../models/ScheduleView';
import { TaskQueueItem } from '../models/TaskQueue';
import { eventDateLabel } from '../models/Schedule';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { InteractiveCard, SectionHeading, EmptyState, PillTone } from '../components/Surfaces';

@ComponentV2
export struct ScheduleDayList {
    @Require @Param state: AppState;
    @Param date: string = '';
    @Param events: CosEvent[] = [];
    @Param tasks: ScheduleTaskItem[] = [];
    @Event open: (kind: string, id: string) => void = () => {};
    @Event openTask: (item: TaskQueueItem) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Local taskError: string = '';

    private async toggle(item: ScheduleTaskItem): Promise<void> {
        if (this.state.busy || this.state.staleScopes.length) {
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

    private taskTone(item: ScheduleTaskItem): PillTone {
        if (item.task.done) {
            return 'success';
        }
        if (item.waiting) {
            return 'brand';
        }
        if (item.overdue) {
            return 'danger';
        }
        return 'warning';
    }

    @Builder eventCardBody(event: CosEvent) {
        Row({ space: 12 }) {
            Column({ space: 3 }) {
                Text(event.timeMode === 'none' ? '全天' : event.startTime)
                    .fontSize(event.timeMode === 'none' ? 12 : 16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.accent)
                if (event.timeMode === 'range') {
                    Text(event.endTime).fontSize(11).fontColor(Theme.muted)
                }
            }.width(58)
                .padding({ top: 6, bottom: 6 })
                .borderRadius(Theme.slotRadius)
                .backgroundColor(Theme.tint)
                .alignItems(HorizontalAlign.Center)
            Column({ space: 5 }) {
                Text(displayName(event.name))
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                MetaRow({
                    icon: Icons.location,
                    text: [event.city, event.venue].filter((value: string) => Boolean(value)).join(' ') || '地点待定',
                })
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(14)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }

    build() {
        Column({ space: 12 }) {
            SectionHeading({
                title: this.date,
                icon: Icons.event,
                trailing: this.events.length + ' 场活动，' + this.tasks.length + ' 项任务',
            })
            if (this.taskError) {
                Row({ space: 8 }) {
                    SymbolGlyph(Icons.alert).fontSize(16).fontColor([Theme.danger]).accessibilityLevel('no')
                    Text(this.taskError)
                        .id('schedule-task-error')
                        .fontSize(13)
                        .fontColor(Theme.danger)
                        .layoutWeight(1)
                }.padding(12)
                    .width('100%')
                    .borderRadius(12)
                    .backgroundColor(Theme.dangerBg)
                    .accessibilityText(this.taskError)
            }
            ForEach(this.events, (event: CosEvent) => {
                InteractiveCard({
                    label: '打开活动 ' + event.name + '，' + eventDateLabel(event),
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
            ForEach(this.tasks, (item: ScheduleTaskItem) => {
                Row({ space: 10 }) {
                    Button({ type: ButtonType.Circle, stateEffect: false }) {
                        SymbolGlyph(item.task.done ? Icons.done : Icons.pending)
                            .fontSize(20)
                            .fontColor([item.task.done ? Theme.success : Theme.accent])
                            .accessibilityLevel('no')
                    }.width(40)
                        .height(40)
                        .backgroundColor(item.task.done ? Theme.successBg : Theme.tint)
                        .enabled(!this.state.busy && !this.state.staleScopes.length)
                        .onClick((): void => {
                            void this.toggle(item);
                        })
                        .accessibilityText(item.task.label + (item.task.done ? '，已完成，取消完成' : '，未完成，标记完成'))
                    Button({ type: ButtonType.Normal, stateEffect: false }) {
                        Column({ space: 4 }) {
                            ContextRow({
                                label: item.task.done ? '已完成' : item.waiting ? '在途' : item.overdue ? '逾期' : '准备任务',
                                text: item.task.label,
                                tone: this.taskTone(item),
                                prominent: true,
                            })
                            Text(displayName(item.projectName) + '，截止 ' + item.task.dueDate)
                                .fontSize(12)
                                .fontColor(Theme.muted)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }.width('100%')
                            .alignItems(HorizontalAlign.Start)
                    }.layoutWeight(1)
                        .constraintSize({ minHeight: 48 })
                        .backgroundColor(Color.Transparent)
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.openTask(scheduleTaskRoute(item));
                        })
                        .accessibilityText('打开准备任务 ' + item.task.label + '，所属计划 ' + item.projectName)
                    SymbolGlyph(Icons.chevronRightSymbol)
                        .fontSize(14)
                        .fontColor([Theme.muted])
                        .accessibilityLevel('no')
                }.id('schedule-task:' + item.task.id)
                    .width('100%')
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.line })
                    .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            }, (item: ScheduleTaskItem) => item.task.id)
            if (!this.events.length && !this.tasks.length) {
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
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }
}
