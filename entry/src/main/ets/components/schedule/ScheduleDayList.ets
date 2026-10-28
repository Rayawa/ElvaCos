import { displayName } from '../../utils/format/format';
import { ContextRow } from '../common/ContextRow';
import { AppState } from '../../state/ApplicationState';
import { CosEvent } from '../../models/Entities';
import { ScheduleTaskItem, scheduleTaskRoute } from '../../domain/schedule/ScheduleView';
import { TaskQueueItem } from '../../domain/tasks/TaskQueue';
import { eventDateLabel } from '../../domain/schedule/Schedule';
import { Theme } from '../../ui/theme/Theme';
import { SectionHeading, EmptyState } from '../common/Surfaces';

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
        this.taskError = '';
        const current = this.state.preparationTasks.find((task) => task.id === item.task.id && task.projectId === item.task.projectId);
        if (!current) {
            this.taskError = '任务已不存在，请刷新后继续';
            return;
        }
        if (!(await this.state.togglePreparation(current))) {
            this.taskError = this.state.error || '任务未保存，请重试';
        }
    }

    build() {
        Column({ space: 14 }) {
            SectionHeading({ title: this.date, trailing: this.events.length + ' 场活动，' + this.tasks.length + ' 项截止任务' })
            if (this.taskError) {
                Text(this.taskError).id('schedule-task-error').fontSize(16).fontColor(Theme.accent).accessibilityText(this.taskError)
            }
            ForEach(this.events, (event: CosEvent) => {
                Button() {
                    Row({ space: 12 }) {
                        Column({ space: 5 }) {
                            Text(event.timeMode === 'none' ? '未标记' : event.startTime)
                                .fontSize(event.timeMode === 'none' ? 12 : 17)
                                .fontWeight(FontWeight.Medium)
                                .fontColor(Theme.ink)
                            if (event.timeMode === 'range') {
                                Text(event.endTime).fontSize(12).fontColor(Theme.muted)
                            }
                        }.width(60).alignItems(HorizontalAlign.Start)
                        Rect().width(3).height(42).fill(Theme.brand).radius(2)
                        Column({ space: 6 }) {
                            Text(displayName(event.name)).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2)
                            Text([event.city, event.venue].filter((value: string) => Boolean(value)).join(' ') || '地点待定')
                                .fontSize(14)
                                .fontColor(Theme.muted)
                                .maxLines(2)
                        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    }.width('100%').padding(16)
                }.id('schedule-event:' + event.id).width('100%').type(ButtonType.Normal).constraintSize({ minHeight: 48 })
                    .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).onClick((): void => {
                        this.open('event', event.id);
                    })
                    .accessibilityText('打开活动 ' + event.name + '，' + eventDateLabel(event))
            }, (event: CosEvent) => event.id)
            ForEach(this.tasks, (item: ScheduleTaskItem) => {
                Row({ space: 8 }) {
                    Button(item.task.done ? '✓' : '○').constraintSize({ minWidth: 48, minHeight: 48 }).fontColor(Theme.accent)
                        .backgroundColor(item.task.done ? Theme.tint : Theme.bg).enabled(!this.state.busy && !this.state.staleScopes.length)
                        .onClick((): void => {
                            this.toggle(item);
                        })
                        .accessibilityText(item.task.label + (item.task.done ? '，已完成，取消完成' : '，未完成，标记完成'))
                    Button() {
                        Column({ space: 6 }) {
                            ContextRow({ label: item.task.done ? '已完成' : item.waiting ? '在途' : item.overdue ? '逾期' : '准备任务', text: item.task.label, prominent: true })
                            Text(displayName(item.projectName) + '，截止 ' + item.task.dueDate).fontSize(14).fontColor(Theme.muted)
                        }.width('100%').alignItems(HorizontalAlign.Start)
                    }.layoutWeight(1).type(ButtonType.Normal).constraintSize({ minHeight: 48 }).fontColor(Theme.ink).backgroundColor(Theme.surface)
                        .onClick((): void => {
                            this.openTask(scheduleTaskRoute(item));
                        }).accessibilityText('打开准备任务 ' + item.task.label + '，所属计划 ' + item.projectName)
                }.id('schedule-task:' + item.task.id).width('100%').padding(12).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            }, (item: ScheduleTaskItem) => item.task.id)
            if (!this.events.length && !this.tasks.length) {
                EmptyState({ title: '这天没有活动或截止任务', message: '多天活动会显示在覆盖的每一天；任务截止日期在所属计划中设置。',
                    button: '＋ 添加当天活动', action: (): void => {
                        this.add('event', this.date);
                    }
                })
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
