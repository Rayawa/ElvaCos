import { ContextRow } from '../components/ContextRow';
import { DashboardSplitLayout } from '../views/DashboardSplitLayout';
import { MetaRow } from '../components/MetaRow';
import { RollingNumber } from '../components/RollingNumber';
import { MIN_SPLIT_HEIGHT } from '../models/constants';
import { InteractiveCard, PillTone, StatusPill, SectionHeading, EmptyState } from '../components/Surfaces';
import { WorkCard } from '../components/WorkCard';
import { ProjectWork, recentWork } from '../models/ProjectWork';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { MainEntranceSession, StaggerEntrance } from '../ui/motion';
import { PressFeedback } from '../ui/pressFeedback';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { CosProject, CosEvent } from '../models/Entities';
import { TaskQueueItem } from '../models/TaskQueue';
import { HomeTaskRow, homeCandidates, advanceHomeSnapshot, reconcileHomeRows, homeTaskCapacity, visiblePreparationUndos } from '../models/HomeSummary';
import { nextPlan } from '../models/Rules';
import { daysUntil, displayName } from '../utils/format';
import { eventEnd } from '../models/Schedule';
import { dayTitle, dayContext } from '../models/DayMode';
import { ManagedImage } from '../components/ManagedImage';

@ComponentV2
export struct HomePage {
    @Param dayEntryInSnack: boolean = false;
    @Require @Param state: AppState;
    @Param scroller: Scroller = new Scroller();
    @Param topInset: number = 100;
    @Param bottomInset: number = 110;
    @Param entranceSession: MainEntranceSession = new MainEntranceSession();
    @Param active: boolean = false;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Event openTask: (item: TaskQueueItem) => void = () => {};
    @Local snapshot: TaskQueueItem[] = [];
    @Local taskError: string = '';
    @Local viewportWidth: number = 360;
    @Local viewportHeight: number = 800;
    @Local nextHeight: number = 180;
    @Local recentHeight: number = 180;
    @Local rowHeight: number = 64;
    @Local entrance: StaggerEntrance = new StaggerEntrance();
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    private snapshotDate: string = '';

    aboutToAppear(): void {
        this.capture();
        if (this.entranceSession.claim('home')) {
            this.entrance.play(this.getUIContext(), 4);
        } else {
            this.entrance.finish(4);
        }
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
        this.entrance.reset();
    }

    @Monitor('state.taskQueue', 'state.localDate', 'state.clockTime')
    queueChanged(): void {
        // Keep the visit's order after a completion or a child-page return.
        // A new date (or the first data load) starts a new summary.
        if (this.snapshotDate !== this.state.localDate || !this.snapshot.length) {
            this.capture();
            return;
        }
        const next = advanceHomeSnapshot(this.snapshot, this.state.taskQueue, this.state.preparationUndos, this.state.clockTime);
        if (next.length !== this.snapshot.length || next.some((item: TaskQueueItem, index: number) => item.id !== this.snapshot[index]?.id)) {
            this.snapshot = next;
        }
    }

    private capture(): void {
        this.snapshotDate = this.state.localDate;
        this.snapshot = homeCandidates(this.state.taskQueue);
    }

    @Computed
    get rows(): HomeTaskRow[] {
        return reconcileHomeRows(this.snapshot, this.state.taskQueue,
            visiblePreparationUndos(this.state.preparationUndos, this.state.preparationTasks, this.state.projects, this.state.clockTime, this.state.busy || !!this.state.staleScopes.length), this.state.clockTime)
            .slice(0, Math.min(3, homeTaskCapacity(this.viewportHeight, this.topInset, this.bottomInset, this.nextHeight, this.recentHeight, this.rowHeight)));
    }

    @Computed
    get upcoming(): CosProject | undefined {
        return nextPlan(this.state.projects, this.state.events, this.state.localDate);
    }

    @Computed
    private get upcomingEvent(): CosEvent | undefined {
        return this.state.events.filter((event: CosEvent) => event.dateMode !== 'pending' && eventEnd(event) >= this.state.localDate && event.status !== 'Attended')
            .sort((a: CosEvent, b: CosEvent) => a.date.localeCompare(b.date))[0];
    }

    @Computed
    private get recentWorkCard(): ProjectWork | undefined {
        return recentWork(this.state.workCards, this.state.localDate);
    }

    @Computed
    private get isSplitLayout(): boolean {
        return this.viewportWidth >= Theme.wideBreakpoint && this.viewportHeight >= MIN_SPLIT_HEIGHT;
    }

    private planDateLabel(project: CosProject): string {
        const readiness = this.state.readiness(project.id);
        return readiness.date || '日期待定';
    }

    private planCountdownDays(project: CosProject): number | undefined {
        const readiness = this.state.readiness(project.id);
        if (!readiness.date) {
            return undefined;
        }
        return daysUntil(readiness.date);
    }

    private planDateContext(project: CosProject): string {
        const readiness = this.state.readiness(project.id);
        if (!readiness.date) {
            return '';
        }
        if (readiness.dateFromEvent) {
            return '活动日期';
        }
        const days = daysUntil(readiness.date);
        return days > 0 ? days + ' 天后' : days === 0 ? '今天' : '日期已过';
    }

    private planDateTone(project: CosProject): PillTone {
        const days = this.planCountdownDays(project);
        if (days === undefined) {
            return 'neutral';
        }
        if (days === 0) {
            return 'warning';
        }
        if (days < 0) {
            return 'danger';
        }
        return 'brand';
    }

    private versionLabel(project: CosProject): string {
        return this.state.characterName(project.characterId) + (project.variantId ? ' / ' + (this.state.variants.find((variant) => variant.id === project.variantId)?.name || '版本已不存在') : '');
    }

    private async complete(row: HomeTaskRow): Promise<void> {
        vibration.dotVibration();
        this.taskError = '';
        const result = await this.state.completeHomePreparation(row.item.focusId, row.item.projectId);
        if (result.status === 'failed') {
            vibration.errorVibration();
            this.taskError = result.detail || '完成状态未保存，请重试';
        }
    }

    private async undo(row: HomeTaskRow): Promise<void> {
        if (!row.undo) {
            return;
        }
        vibration.dotVibration();
        this.taskError = '';
        const result = await this.state.undoHomePreparation(row.undo.id);
        if (result.status === 'failed') {
            vibration.errorVibration();
            this.taskError = result.detail || '撤销未保存，请重试';
        }
    }

    private greeting(): string {
        const hour = new Date(this.state.clockTime).getHours();
        if (hour < 6) {
            return '凌晨好';
        }
        if (hour < 12) {
            return '早上好';
        }
        if (hour < 14) {
            return '中午好';
        }
        if (hour < 18) {
            return '下午好';
        }
        return '晚上好';
    }

    @Builder welcomeBlock() {
        Column({ space: 12 }) {
            Column({ space: 4 }) {
                Text(this.greeting() + (this.state.settings.username.trim() ? '，' + displayName(this.state.settings.username) : ''))
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.state.lastMetadataExport ? '欢迎来到绮秀，最近备份已保存在本机' : '欢迎来到绮秀，管理计划、日程与写真')
                    .fontSize(14)
                    .fontColor(Theme.muted)
                    .maxLines(2)
            }.width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 4, right: 4 })
            Row({ space: 8 }) {
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 6 }) {
                        SymbolGlyph(Icons.settings)
                            .fontSize(15)
                            .fontColor([Theme.accent])
                            .accessibilityLevel('no')
                        Text('设置与数据备份')
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.ink)
                        SymbolGlyph(Icons.chevronRightSymbol)
                            .fontSize(12)
                            .fontColor([Theme.muted])
                            .accessibilityLevel('no')
                    }.padding({ left: 12, right: 12 })
                }.id('home-greeting-settings')
                    .height(36)
                    .borderRadius(Theme.pillRadius)
                    .backgroundColor(Theme.surface)
                    .border({ width: 0.8, color: Theme.line })
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.open('settings', 'settings');
                    })
                    .accessibilityText((this.state.settings.username.trim() || '欢迎板块') + '，打开设置与数据备份')
                    .accessibilityDescription('双击打开设置页')
                    .visualEffect(this.feedback.effect('welcome-settings', false))
                    .compositingFilter(this.feedback.filter('welcome-settings', false))
                    .attributeModifier(this.feedback.control('welcome-settings', false))
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(Icons.share)
                            .fontSize(14)
                            .fontColor([Theme.accent])
                            .accessibilityLevel('no')
                        Text('导出备份')
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.accent)
                    }.padding({ left: 12, right: 12 })
                }.id('home-welcome-backup')
                    .height(36)
                    .borderRadius(Theme.pillRadius)
                    .backgroundColor(Theme.tint)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.state.exportData();
                    })
                    .accessibilityText('导出本机元数据备份')
                    .visualEffect(this.feedback.effect('welcome-backup', false))
                    .compositingFilter(this.feedback.filter('welcome-backup', false))
                    .attributeModifier(this.feedback.control('welcome-backup', false))
            }.width('100%')
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder planHeroBody(project: CosProject) {
        Column({ space: 12 }) {
            Row({ space: 14 }) {
                if (this.state.characters.find((character) => character.id === project.characterId)?.cover) {
                    ManagedImage({ sourcePath: this.state.characters.find((character) => character.id === project.characterId)?.cover || '', label: this.versionLabel(project) + '封面', radius: 12 })
                        .width(68)
                        .height(92)
                } else {
                    Stack({ alignContent: Alignment.Center }) {
                        Text(this.state.characterName(project.characterId).slice(0, 1))
                            .fontSize(28)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.accent)
                    }.width(68)
                        .height(92)
                        .backgroundColor(Theme.tint)
                        .borderRadius(12)
                        .accessibilityLevel('no')
                }
                Column({ space: 6 }) {
                    Row({ space: 8 }) {
                        Text(displayName(project.name))
                            .fontSize(19)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.ink)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                        if (this.planCountdownDays(project) !== undefined && this.planCountdownDays(project)! > 0) {
                            Row({ space: 2 }) {
                                Text('还剩')
                                    .fontSize(11)
                                    .fontColor(Theme.accent)
                                RollingNumber({
                                    value: this.planCountdownDays(project)!,
                                    fontSize: 16,
                                    color: Theme.accent,
                                    accessibilityLabel: '距离目标日还有',
                                })
                                Text('天')
                                    .fontSize(11)
                                    .fontColor(Theme.accent)
                            }.padding({ left: 8, right: 8, top: 4, bottom: 4 })
                                .borderRadius(Theme.controlRadius)
                                .backgroundColor(Theme.tint)
                                .alignItems(VerticalAlign.Bottom)
                        } else if (this.planDateContext(project)) {
                            StatusPill({ label: this.planDateContext(project), tone: this.planDateTone(project), compact: true })
                        }
                    }.width('100%')
                        .alignItems(VerticalAlign.Top)
                    Text(displayName(this.versionLabel(project)))
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 10 }) {
                        MetaRow({
                            icon: Icons.event,
                            text: this.planDateLabel(project),
                        }).id('home-plan-date')
                        if (this.state.readiness(project.id).prep.total > 0) {
                            MetaRow({
                                icon: Icons.check,
                                text: '准备 ' + this.state.readiness(project.id).prep.done + '/' + this.state.readiness(project.id).prep.total,
                                color: this.state.readiness(project.id).prep.done >= this.state.readiness(project.id).prep.total ? Theme.success : Theme.accent,
                            })
                        }
                    }
                    if (this.state.readiness(project.id).prep.total > 0) {
                        Progress({
                            value: this.state.readiness(project.id).prep.done,
                            total: Math.max(1, this.state.readiness(project.id).prep.total),
                            type: ProgressType.Linear,
                        }).width('100%')
                            .color(this.state.readiness(project.id).prep.done >= this.state.readiness(project.id).prep.total ? Theme.success : Theme.brand)
                            .backgroundColor(Theme.tint)
                            .style({ strokeWidth: 4 })
                    }
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
            }.width('100%')
            if (this.state.readiness(project.id).hint) {
                ContextRow({
                    label: this.state.readiness(project.id).hint!.label,
                    text: displayName(this.state.readiness(project.id).hint!.text),
                })
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder dayEntryBody() {
        Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.bell)
                    .fontSize(19)
                    .fontColor([Theme.warning])
                    .accessibilityLevel('no')
            }.width(40)
                .height(40)
                .borderRadius(12)
                .backgroundColor(Theme.warningBg)
            Column({ space: 3 }) {
                Row({ space: 8 }) {
                    StatusPill({ label: dayContext(this.state.todayEvents[0], this.state.clockTime), tone: 'warning', compact: true })
                    Text(displayName(this.state.todayEvents[0].name))
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                }.width('100%')
                Text(this.state.todayEvents.length > 1 ?
                    '还有 ' + (this.state.todayEvents.length - 1) + ' 场活动，进入今天模式' :
                    '点击进入出发前与现场模式')
                    .fontSize(12)
                    .fontColor(Theme.muted)
                    .maxLines(1)
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(14)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }

    @Builder eventHeroBody(event: CosEvent) {
        Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.event)
                    .fontSize(20)
                    .fontColor([Theme.accent])
                    .accessibilityLevel('no')
            }.width(42)
                .height(42)
                .borderRadius(12)
                .backgroundColor(Theme.tint)
            Column({ space: 3 }) {
                Text(displayName(event.name))
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                MetaRow({
                    icon: Icons.location,
                    text: (event.city ? event.city + ' ' : '') + (event.date || '即将举行'),
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

    @Builder next() {
        Column({ space: 10 }) {
            SectionHeading({ title: '接下来', icon: Icons.plan })
            if (this.state.todayEvents.length && !this.dayEntryInSnack) {
                InteractiveCard({
                    label: '进入' + dayTitle(this.state.todayEvents[0], this.state.clockTime) + '的今天模式',
                    hint: '双击打开今天模式',
                    effects: this.state.settings.effects,
                    elevated: true,
                    contentPadding: 14,
                    action: (): void => {
                        this.open('dayEvent', this.state.todayEvents[0]?.id || '');
                    },
                    content: (): void => this.dayEntryBody(),
                }).id('home-day-entry')
            }
            if (this.upcoming) {
                InteractiveCard({
                    label: '打开计划 ' + this.upcoming!.name + '，' + this.versionLabel(this.upcoming!) + '，' + this.planDateLabel(this.upcoming!),
                    hint: '双击打开计划详情',
                    effects: this.state.settings.effects,
                    hero: true,
                    contentPadding: 16,
                    action: (): void => {
                        this.open('project', this.upcoming!.id);
                    },
                    content: (): void => this.planHeroBody(this.upcoming!),
                }).id('home-next-plan')
            } else if (!this.state.todayEvents.length && this.upcomingEvent) {
                InteractiveCard({
                    label: '打开活动 ' + this.upcomingEvent!.name,
                    hint: '双击查看活动详情',
                    effects: this.state.settings.effects,
                    hero: true,
                    contentPadding: 16,
                    action: (): void => {
                        this.open('event', this.upcomingEvent?.id || '');
                    },
                    content: (): void => this.eventHeroBody(this.upcomingEvent!),
                })
            } else if (!this.state.todayEvents.length || this.dayEntryInSnack) {
                InteractiveCard({
                    label: '新建计划',
                    hint: '双击创建新的 Cosplay 计划',
                    effects: this.state.settings.effects,
                    contentPadding: 14,
                    action: (): void => {
                        this.add('project', '');
                    },
                    content: (): void => this.createPlanActionBody(),
                })
            }
        }.id('home-next')
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .onAreaChange((_, area: Area): void => {
                this.nextHeight = Number(area.height);
            })
    }

    @Builder createPlanActionBody() {
        Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.add).fontSize(18).fontColor([Theme.onAccent]).accessibilityLevel('no')
            }.width(36).height(36).borderRadius(12).backgroundColor(Theme.brand)
            Column({ space: 2 }) {
                Text('新建计划').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                Text('选定角色与活动日程，开始逐项准备').fontSize(12).fontColor(Theme.muted)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            SymbolGlyph(Icons.chevronRightSymbol).fontSize(14).fontColor([Theme.muted]).accessibilityLevel('no')
        }.width('100%')
    }

    @Builder expensesStatBody() {
        Column({ space: 6 }) {
            Row({ space: 6 }) {
                SymbolGlyph(Icons.wallet).fontSize(15).fontColor([Theme.accent]).accessibilityLevel('no')
                Text('本月支出').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.muted).layoutWeight(1)
                SymbolGlyph(Icons.chevronRightSymbol).fontSize(12).fontColor([Theme.muted]).accessibilityLevel('no')
            }.width('100%')
            RollingNumber({
                value: this.state.monthSpendingCents / 100,
                decimals: 2,
                prefix: '¥',
                fontSize: 22,
                color: Theme.ink,
                accessibilityLabel: '本月支出金额',
            })
            Text('点按查看统计').fontSize(11).fontColor(Theme.muted)
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder tasksStatBody() {
        Column({ space: 6 }) {
            Row({ space: 6 }) {
                SymbolGlyph(Icons.list).fontSize(15).fontColor([Theme.warning]).accessibilityLevel('no')
                Text('待办事项').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.muted).layoutWeight(1)
                SymbolGlyph(Icons.chevronRightSymbol).fontSize(12).fontColor([Theme.muted]).accessibilityLevel('no')
            }.width('100%')
            Row({ space: 4 }) {
                RollingNumber({
                    value: this.state.taskQueue.length,
                    fontSize: 22,
                    color: this.state.taskQueue.length > 0 ? Theme.accent : Theme.success,
                    accessibilityLabel: '当前待办总数',
                })
                Text('项').fontSize(13).fontColor(Theme.muted).margin({ bottom: 2 })
            }.alignItems(VerticalAlign.Bottom)
            Text(this.state.taskQueue.length > 0 ? '查看全部排期' : '已全部清空').fontSize(11).fontColor(Theme.muted)
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder bentoStats() {
        Row({ space: 10 }) {
            InteractiveCard({
                label: '本月已记录支出 ' + (this.state.monthSpendingCents / 100).toFixed(2) + ' 元，打开花费统计',
                hint: '双击打开花费统计',
                effects: this.state.settings.effects,
                contentPadding: 14,
                action: (): void => {
                    this.open('expenseStats', 'all');
                },
                content: (): void => this.expensesStatBody(),
            }).id('home-expenses').layoutWeight(1)
            InteractiveCard({
                label: '全部待办 ' + this.state.taskQueue.length + ' 项',
                hint: '双击打开全部待办',
                effects: this.state.settings.effects,
                contentPadding: 14,
                action: (): void => {
                    this.open('tasks', 'all');
                },
                content: (): void => this.tasksStatBody(),
            }).id('home-all-tasks').layoutWeight(1)
        }.width('100%')
    }

    @Builder quickExpenseBody() {
        Row({ space: 10 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.creditcard).fontSize(17).fontColor([Theme.accent]).accessibilityLevel('no')
            }.width(32).height(32).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
            Text('记一笔').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1)
        }.width('100%')
    }

    @Builder quickInboxBody() {
        Row({ space: 10 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.folder).fontSize(17).fontColor([Theme.accent]).accessibilityLevel('no')
            }.width(32).height(32).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
            Column({ space: 1 }) {
                Text('收录箱').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                if (this.state.untriagedEntries.length > 0) {
                    Text('未归位 ' + this.state.untriagedEntries.length).fontSize(11).fontColor(Theme.warning)
                } else {
                    Text('随手保存').fontSize(11).fontColor(Theme.muted)
                }
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%')
    }

    @Builder quickActions() {
        Row({ space: 10 }) {
            InteractiveCard({
                label: '记一笔花费',
                hint: '双击记一笔花费',
                effects: this.state.settings.effects,
                contentPadding: 12,
                action: (): void => {
                    this.add('expense', '');
                },
                content: (): void => this.quickExpenseBody(),
            }).layoutWeight(1)
            InteractiveCard({
                label: '打开收录箱' + (this.state.untriagedEntries.length ? '，未归位 ' + this.state.untriagedEntries.length + ' 条' : ''),
                hint: '双击打开收录箱',
                effects: this.state.settings.effects,
                contentPadding: 12,
                action: (): void => {
                    this.open('inbox', 'global');
                },
                content: (): void => this.quickInboxBody(),
            }).id('home-inbox').layoutWeight(1)
        }.width('100%')
    }

    private taskTone(row: HomeTaskRow): PillTone {
        if (row.undo) {
            return 'success';
        }
        if (row.item.kind === 'waiting') {
            return 'brand';
        }
        if (row.item.group === 'overdue') {
            return 'danger';
        }
        return 'warning';
    }

    @Builder taskRow(row: HomeTaskRow, showDivider: boolean) {
        Column() {
            Row({ space: 8 }) {
                if (row.undo) {
                    Button('撤销', { type: ButtonType.Normal, stateEffect: false })
                        .id('home-undo:' + row.item.focusId)
                        .constraintSize({ minWidth: 48, minHeight: 38 })
                        .borderRadius(12)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.accent)
                        .backgroundColor(Theme.tint)
                        .enabled(!this.state.busy && !this.state.staleScopes.length)
                        .onClick((): void => {
                            void this.undo(row);
                        })
                        .accessibilityText('撤销完成 ' + row.undo.label)
                } else if (row.item.source === 'preparation') {
                    Button({ type: ButtonType.Circle, stateEffect: false }) {
                        SymbolGlyph(Icons.pending)
                            .fontSize(20)
                            .fontColor([Theme.accent])
                            .accessibilityLevel('no')
                    }.id('home-complete:' + row.item.focusId)
                        .width(40)
                        .height(40)
                        .backgroundColor(Theme.tint)
                        .enabled(!this.state.busy && !this.state.staleScopes.length)
                        .onClick((): void => {
                            void this.complete(row);
                        })
                        .accessibilityText(row.item.title + '，未完成，标记完成')
                }
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Column({ space: 3 }) {
                        ContextRow({
                            label: row.undo ? '已完成' : row.item.kind === 'waiting' ? '在途' : row.item.group === 'overdue' ? '逾期' : '待办',
                            text: displayName(row.item.title),
                            tone: this.taskTone(row),
                            prominent: true,
                        })
                        Text(row.undo ? this.state.staleScopes.length ? '已保存，显示待刷新' : '10 秒内可撤销' : displayName(row.item.projectName))
                            .fontSize(13)
                            .fontColor(Theme.muted)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }.width('100%')
                        .alignItems(HorizontalAlign.Start)
                }.id('home-task-open:' + row.item.focusId)
                    .layoutWeight(1)
                    .constraintSize({ minHeight: 48 })
                    .backgroundColor(Color.Transparent)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.openTask(row.item);
                    })
                    .accessibilityText('打开事项 ' + row.item.title + '，所属计划 ' + row.item.projectName + (row.undo ? '，已完成' : '，' + row.item.detail))
                SymbolGlyph(Icons.chevronRightSymbol)
                    .fontSize(13)
                    .fontColor([Theme.muted])
                    .accessibilityLevel('no')
            }.width('100%')
                .padding({ top: 8, bottom: 8 })
                .constraintSize({ minHeight: 56 })
                .onAreaChange((_, area: Area): void => {
                    this.rowHeight = Math.max(this.rowHeight, Number(area.height) + 8);
                })
            if (showDivider) {
                Divider().color(Theme.groupDivider)
            }
        }.id('home-task:' + row.item.focusId)
            .width('100%')
            .height(row.retired ? 0 : undefined)
            .opacity(row.retired ? 0 : 1)
            .clip(true)
            .animation({ duration: this.state.settings.effects ? 180 : 0, curve: Curve.EaseOut })
            .hitTestBehavior(row.retired ? HitTestMode.None : HitTestMode.Default)
            .accessibilityLevel(row.retired ? 'no-hide-descendants' : 'auto')
    }

    @Builder tasks() {
        Column({ space: 8 }) {
            SectionHeading({
                title: '在途与待办',
                icon: Icons.check,
                trailing: this.state.taskQueue.length ? '共 ' + this.state.taskQueue.length + ' 项' : '',
            })
            if (this.taskError) {
                Row({ space: 8 }) {
                    SymbolGlyph(Icons.alert).fontSize(16).fontColor([Theme.danger]).accessibilityLevel('no')
                    Text(this.taskError)
                        .id('home-task-error')
                        .fontSize(13)
                        .fontColor(Theme.danger)
                        .layoutWeight(1)
                }.padding(12)
                    .width('100%')
                    .borderRadius(12)
                    .backgroundColor(Theme.dangerBg)
                    .accessibilityText(this.taskError)
            }
            Column() {
                if (this.rows.some((row: HomeTaskRow) => !row.retired)) {
                    ForEach(this.rows, (row: HomeTaskRow, index: number) => {
                        this.taskRow(row, index < this.rows.length - 1 && !this.rows[index + 1]?.retired)
                    }, (row: HomeTaskRow) => row.key)
                } else {
                    Row({ space: 10 }) {
                        SymbolGlyph(Icons.done).fontSize(18).fontColor([Theme.success]).accessibilityLevel('no')
                        Text('当前摘要已处理；未定期事项可在上方待办统计查看。')
                            .fontSize(13)
                            .fontColor(Theme.muted)
                            .layoutWeight(1)
                    }.padding({ top: 12, bottom: 12 })
                }
            }.width('100%')
                .padding({ left: 14, right: 14, top: 4, bottom: 4 })
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder recentSection() {
        Column({ space: 10 }) {
            Row({ space: 8 }) {
                Text('最近完成')
                    .fontSize(Theme.sectionTitleSize)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 4 }) {
                        SymbolGlyph(Icons.search).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('全局搜索').fontSize(13).fontColor(Theme.accent)
                    }.padding({ left: 10, right: 10, top: 6, bottom: 6 })
                        .borderRadius(12)
                        .backgroundColor(Theme.tint)
                }.id('home-search')
                    .constraintSize({ minHeight: 34 })
                    .backgroundColor(Color.Transparent)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.open('search', 'all');
                    })
                    .accessibilityText('打开全局搜索')
            }.width('100%')
            if (this.recentWorkCard) {
                WorkCard({
                    work: this.recentWorkCard!,
                    compact: true,
                    effects: this.state.settings.effects,
                    open: (): void => {
                        this.open('project', this.recentWorkCard?.value.projectId || '');
                    },
                })
            } else {
                Column() {
                    Text('完成计划或整理成片后，在这里快速回看。')
                        .fontSize(13)
                        .fontColor(Theme.muted)
                }.width('100%')
                    .padding(16)
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.line })
                    .alignItems(HorizontalAlign.Start)
            }
        }.id('home-recent')
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .onAreaChange((_, area: Area): void => {
                this.recentHeight = Number(area.height);
            })
    }

    @Builder splitOverviewPane() {
        Column({ space: 14 }) {
            this.welcomeBlock()
            this.next()
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
            .attributeModifier(this.entrance.group(1))
    }

    @Builder splitContentPane() {
        Column({ space: Theme.sectionSpacing }) {
            Column({ space: 10 }) {
                this.bentoStats()
                this.quickActions()
            }.width('100%').attributeModifier(this.entrance.group(2))
            Column() {
                this.tasks()
            }.width('100%').attributeModifier(this.entrance.group(3))
            Column() {
                this.recentSection()
            }.width('100%').attributeModifier(this.entrance.group(4))
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder narrowContent() {
        Scroll(this.scroller) {
            Column({ space: 18 }) {
                Blank().height(this.topInset).width('100%')
                if (!this.state.projects.length && !this.state.events.length && !this.state.assets.length && !this.state.characters.length && !this.state.entries.length) {
                    this.welcomeBlock()
                    EmptyState({
                        title: '从一次想出的角色开始',
                        message: '建立计划，添加准备任务，再安排活动和整理照片。',
                        button: '新建计划',
                        icon: Icons.plan,
                        action: (): void => {
                            this.add('project', '');
                        },
                    })
                    Row({ space: 10 }) {
                        InteractiveCard({
                            label: '先收录一个想法',
                            effects: this.state.settings.effects,
                            contentPadding: 14,
                            action: (): void => {
                                this.open('inbox', 'global');
                            },
                            content: (): void => this.quickInboxBody(),
                        }).layoutWeight(1)
                        InteractiveCard({
                            label: '打开全局搜索',
                            effects: this.state.settings.effects,
                            contentPadding: 14,
                            action: (): void => {
                                this.open('search', 'all');
                            },
                            content: (): void => this.emptySearchBody(),
                        }).id('home-search').layoutWeight(1)
                    }.width('100%')
                } else {
                    Column() {
                        this.welcomeBlock()
                    }.width('100%').attributeModifier(this.entrance.group(1))
                    Column() {
                        this.next()
                    }.width('100%').attributeModifier(this.entrance.group(1))
                    Column({ space: 10 }) {
                        this.bentoStats()
                        this.quickActions()
                    }.width('100%').attributeModifier(this.entrance.group(2))
                    Column() {
                        this.tasks()
                    }.width('100%').attributeModifier(this.entrance.group(3))
                    Column() {
                        this.recentSection()
                    }.width('100%').attributeModifier(this.entrance.group(4))
                }
                Blank().height(this.bottomInset).width('100%')
            }.padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .width('100%')
                .constraintSize({ maxWidth: Theme.contentMaxWidth })
                .alignItems(HorizontalAlign.Start)
        }.id('home-scroll')
            .width('100%')
            .height('100%')
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }

    @Builder emptySearchBody() {
        Row({ space: 10 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.search).fontSize(17).fontColor([Theme.accent]).accessibilityLevel('no')
            }.width(32).height(32).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
            Text('搜索').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1)
        }.width('100%')
    }

    build() {
        Stack() {
            if (this.isSplitLayout && Boolean(this.state.projects.length || this.state.events.length || this.state.assets.length || this.state.characters.length || this.state.entries.length)) {
                DashboardSplitLayout({
                    scroller: this.scroller,
                    overviewTop: Theme.wideOverviewTop,
                    scrollTop: Theme.wideScrollTop,
                    bottomInset: this.bottomInset,
                    layoutId: 'home-split',
                    overviewId: 'home-split-overview',
                    scrollId: 'home-scroll',
                    overviewLabel: '首页概览',
                    scrollLabel: '首页待办与最近动态',
                    overview: (): void => this.splitOverviewPane(),
                    content: (): void => this.splitContentPane(),
                })
            } else {
                this.narrowContent()
            }
        }.width('100%')
            .height('100%')
            .onAreaChange((_, area: Area): void => {
                this.viewportHeight = Number(area.height);
                const width = Number(area.width);
                if (this.viewportWidth !== width) {
                    this.viewportWidth = width;
                }
            })
    }
}
