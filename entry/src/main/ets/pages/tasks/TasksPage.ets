import { ContextRow } from '../../components/common/ContextRow';
import { StatusPill, SectionHeading, EmptyState } from '../../components/common/Surfaces';
import { displayName } from '../../utils/format/format';
import { AppState } from '../../state/ApplicationState';
import { TaskRoute, TaskQueueItem, filterTaskQueue } from '../../domain/tasks/TaskQueue';
import { CosProject } from '../../models/Entities';
import { Theme } from '../../ui/theme/Theme';
const CATEGORIES: string[] = ['action', 'preparation', 'packing', 'photo', 'waiting', 'all'];
const CATEGORY_LABELS: string[] = ['需要行动', '准备', '打包', '照片', '在途', '全部类别'];
const RANGES: string[] = ['action', 'all', 'overdue', 'today', 'week', 'undated'];
const RANGE_LABELS: string[] = ['需要处理', '全部日期', '逾期', '今天', '未来七天', '未定期'];

@ComponentV2
export struct TasksPage {
    @Require @Param state: AppState;
    @Require @Param route: TaskRoute;
    @Event openItem: (item: TaskQueueItem) => void = () => {};
    @Event addPlan: () => void = () => {};
    private scroller: Scroller = new Scroller();
    private restoreTimer: number = -1;
    private measured: boolean = false;
    private restoring: boolean = true;

    private restoreOffset(): void {
        if (!this.measured) {
            return;
        }
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoring = true;
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false });
            this.restoring = false;
        }, 0);
    }

    @Monitor('route.restoreVersion')
    restoreChanged(): void {
        this.restoreOffset();
    }

    aboutToDisappear(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
    }

    @Monitor('route.category', 'route.projectId', 'route.range')
    private filterChanged(): void {
        this.route.offset = 0;
        this.restoreOffset();
    }

    private items(): TaskQueueItem[] {
        return filterTaskQueue(this.state.taskQueue, this.route, this.state.localDate);
    }

    private projectOptions(): SelectOption[] {
        const options: SelectOption[] = [{ value: '全部计划' }];
        return options.concat(this.state.projects.map((project: CosProject): SelectOption => {
            return { value: project.name };
        }));
    }

    private groupLabel(item: TaskQueueItem): string {
        if (item.kind === 'waiting') {
            return '在途';
        }
        if (item.kind === 'photo') {
            return '照片';
        }
        return item.group === 'overdue' ? '逾期' : item.group === 'today' ? '今天' : item.group === 'week' ? '近期' : item.group === 'undated' ? '未定期' : '以后';
    }

    private kindLabel(item: TaskQueueItem): string {
        return item.kind === 'waiting' ? '在途' : item.kind === 'photo' ? '照片' : item.kind === 'packing' ? '打包' : '准备';
    }

    private dateLabel(item: TaskQueueItem): string {
        if (!item.date) {
            return '未定期';
        }
        return (item.kind === 'waiting' ? '等至 ' : item.kind === 'packing' ? '出行 ' : item.kind === 'photo' ? '计划 ' : '截止 ') + item.date;
    }

    build() {
        Scroll(this.scroller) {
            Column({ space: 16 }) {
                Blank().height(Theme.detailTop).width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                    Select(CATEGORY_LABELS.map((label: string): SelectOption => {
                        return { value: label };
                    }))
                        .value(CATEGORY_LABELS[CATEGORIES.indexOf(this.route.category)]).onSelect((index: number): void => {
                            this.route.category = CATEGORIES[index];
                            this.route.range = index === 4 || index === 5 ? 'all' : 'action';
                        }).accessibilityText('待办类别').constraintSize({ minHeight: 36 }).margin({ right: 8, bottom: 8 })
                        .controlSize(ControlSize.SMALL).font({ size: 14 })
                    Select(this.projectOptions()).value(this.route.projectId ? this.state.projectName(this.route.projectId) : '全部计划')
                        .onSelect((index: number): void => {
                            this.route.projectId = index === 0 ? '' : this.state.projects[index - 1].id;
                        }).accessibilityText('待办所属计划').constraintSize({ minHeight: 36 }).margin({ right: 8, bottom: 8 })
                        .controlSize(ControlSize.SMALL).font({ size: 14 })
                    Select(RANGE_LABELS.map((label: string): SelectOption => {
                        return { value: label };
                    }))
                        .value(RANGE_LABELS[RANGES.indexOf(this.route.range)]).onSelect((index: number): void => {
                            this.route.range = RANGES[index];
                        }).accessibilityText('待办日期范围').constraintSize({ minHeight: 36 }).margin({ bottom: 8 })
                        .controlSize(ControlSize.SMALL).font({ size: 14 })
                }.width('100%')
                SectionHeading({ title: CATEGORY_LABELS[CATEGORIES.indexOf(this.route.category)], trailing: this.items().length + ' 项' })
                ForEach(this.items(), (item: TaskQueueItem) => {
                    Button() {
                        Row({ space: 12 }) {
                            Column({ space: 6 }) {
                                Row({ space: 8 }) {
                                    ContextRow({ label: this.kindLabel(item), text: displayName(item.title), prominent: true }).layoutWeight(1)
                                    if (item.group === 'overdue') {
                                        StatusPill({ label: '逾期' })
                                    }
                                }.width('100%')
                                ContextRow({ label: this.dateLabel(item), text: displayName(item.projectName) })
                            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                            Text('›').fontSize(22).fontColor(Theme.muted).accessibilityLevel('no')
                        }.width('100%').padding(16)
                    }.id('task-row:' + item.id).width('100%').constraintSize({ minHeight: 64 }).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
                        .onClick((): void => {
                            this.openItem(item);
                        })
                        .accessibilityText(this.kindLabel(item) + '，' + this.groupLabel(item) + '，' + item.title + '，' + item.projectName + '，' + item.detail + '，打开对应事项')
                }, (item: TaskQueueItem) => item.id)
                if (!this.items().length) {
                    EmptyState({ title: this.state.projects.length ? '当前范围没有事项' : '先建立一份计划', message: this.state.projects.length ? '可以查看全部类别与日期，包括在途和未定期。' : '计划创建后可以添加准备任务、装备和打包清单。',
                        button: this.state.projects.length ? '查看全部事项' : '新建计划', action: (): void => {
                            if (this.state.projects.length) {
                                this.route.category = 'all';
                                this.route.projectId = '';
                                this.route.range = 'all';
                            } else {
                                this.addPlan();
                            }
                        }
                    })
                }
                Blank().height(Theme.detailBottom).width('100%')
            }.width('100%')
                .constraintSize({ maxWidth: Theme.readingMaxWidth })
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .alignItems(HorizontalAlign.Start)
        }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
            .onAreaChange((_old: Area, area: Area): void => {
                if (!this.measured && Number(area.height) > 0) {
                    this.measured = true;
                    this.restoreOffset();
                }
            })
            .onDidScroll((): void => {
                if (this.measured && !this.restoring) {
                    this.route.offset = this.scroller.currentOffset().yOffset;
                }
            })
    }
}
