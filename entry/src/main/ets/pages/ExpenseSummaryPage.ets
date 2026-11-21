import { displayName } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { DashboardSplitLayout } from '../views/DashboardSplitLayout';
import { RollingNumber } from '../components/RollingNumber';
import { LedgerRoute } from '../viewmodels/LedgerRoute';
import { LedgerSummary, LedgerCategory, buildLedgerSummary } from '../models/LedgerSummary';
import { DateField } from '../components/DateField';
import { PressFeedback } from '../ui/pressFeedback';
import { AppState } from '../viewmodels/ApplicationState';
import { MIN_SPLIT_HEIGHT, READING_MAX_WIDTH } from '../models/constants';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { CosProject } from '../models/Entities';
import { Expense } from '../models/Planning';
import { StatusPill, SectionHeading, EmptyState } from '../components/Surfaces';
import { StaggerEntrance } from '../ui/motion';
import { InteractiveLineChart, ChartViewportState } from '../components/InteractiveLineChart';

const RANGES: string[] = ['month', 'year', 'custom', 'all'];
const RANGE_LABELS: string[] = ['本月', '本年', '自定义日期', '全部日期'];

@ComponentV2
export struct ExpenseSummary {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    private scroller: Scroller = new Scroller();
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    @Require @Param state: AppState;
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string) => void = () => {};
    @Param route: LedgerRoute = new LedgerRoute();
    @Local viewportWidth: number = 360;
    @Local viewportHeight: number = 800;
    private restoreTimer: number = -1;
    private restoring: boolean = true;
    private measured: boolean = false;

    aboutToAppear(): void {
        if (!this.entrance.managed) {
            this.entrance.play(this.getUIContext());
        }
        this.restoreScroll();
    }

    @Monitor('route.restoreVersion')
    private restoreScroll(): void {
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

    aboutToDisappear(): void {
        this.feedback.dispose();
        if (!this.entrance.managed) {
            this.entrance.reset();
        }
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
    }

    @Computed
    private get isSplitLayout(): boolean {
        return this.viewportWidth >= Theme.wideBreakpoint && this.viewportHeight >= MIN_SPLIT_HEIGHT;
    }

    @Monitor('route.projectId', 'route.category', 'route.range', 'route.startDate', 'route.endDate')
    private filterChanged(): void {
        this.route.offsets = [0, 0];
        this.route.chartZoom = 1;
        this.route.chartPan = 0;
        this.restoreScroll();
    }

    @Computed
    private get summary(): LedgerSummary {
        if (this.route.range === 'month' && !this.route.projectId && !this.route.category) {
            return this.state.monthLedger;
        }
        return buildLedgerSummary(this.state.expenses, this.state.readinessPlans, this.route, this.state.localDate);
    }

    @Computed
    private get categoryNames(): string[] {
        return Array.from(new Set(this.state.expenses.map((expense: Expense) => expense.category))).sort();
    }

    private categoryOptions(): SelectOption[] {
        const options: SelectOption[] = [{ value: '全部分类' }];
        return options.concat(this.categoryNames.map((name: string): SelectOption => ({ value: name })));
    }

    private chooseRange(index: number): void {
        vibration.dotVibration();
        if (RANGES[index] === 'custom') {
            if (!this.route.startDate) {
                this.route.startDate = this.summary.range.start || this.state.localDate;
            }
            if (!this.route.endDate) {
                this.route.endDate = this.summary.range.end || this.state.localDate;
            }
        }
        this.route.range = RANGES[index];
    }

    private clearFilters(): void {
        vibration.dotVibration();
        this.route.range = 'all';
        this.route.projectId = '';
        this.route.category = '';
    }

    private sourceLabel(): string {
        if (!this.route.sourceProjectId) {
            return '从全局花费统计进入';
        }
        const project = this.state.projects.find((item: CosProject) => item.id === this.route.sourceProjectId);
        return project ? '来源计划：' + displayName(project.name) + '（进入时为全部日期）' : '来源计划已不存在';
    }

    @Builder rangeControls() {
        Text(this.sourceLabel()).fontSize(13).fontColor(Theme.muted)
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            Select(RANGE_LABELS.map((label: string): SelectOption => ({ value: label })))
                .id('expense-range')
                .value(RANGE_LABELS[RANGES.indexOf(this.route.range)])
                .backgroundColor(Theme.surface)
                .borderRadius(12)
                .onSelect((index: number): void => {
                    this.chooseRange(index);
                })
                .constraintSize({ minHeight: 36 })
                .margin({ right: 8, bottom: 8 })
                .accessibilityText('花费日期范围')
                .controlSize(ControlSize.SMALL)
                .font({ size: 13 })
            Select(new Array<SelectOption>({ value: '全部计划' }).concat(this.state.projects.map((project: CosProject): SelectOption => ({ value: project.name }))))
                .id('expense-project')
                .value(this.route.projectId ? this.state.projectName(this.route.projectId) : '全部计划')
                .backgroundColor(Theme.surface)
                .borderRadius(12)
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.route.projectId = index === 0 ? '' : this.state.projects[index - 1].id;
                })
                .constraintSize({ minHeight: 36 })
                .margin({ right: 8, bottom: 8 })
                .accessibilityText('花费所属计划')
                .controlSize(ControlSize.SMALL)
                .font({ size: 13 })
            Select(this.categoryOptions())
                .id('expense-category-filter')
                .value(this.route.category || '全部分类')
                .backgroundColor(Theme.surface)
                .borderRadius(12)
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.route.category = index === 0 ? '' : this.categoryNames[index - 1];
                })
                .constraintSize({ minHeight: 36 })
                .margin({ bottom: 8 })
                .accessibilityText('花费分类筛选')
                .controlSize(ControlSize.SMALL)
                .font({ size: 13 })
        }.width('100%')
        if (this.route.range === 'custom') {
            Row({ space: 12 }) {
                DateField({
                    label: '开始日期（含当天）',
                    value: this.route.startDate,
                    change: (value: string): void => {
                        this.route.startDate = value;
                    },
                }).layoutWeight(1)
                DateField({
                    label: '结束日期（含当天）',
                    value: this.route.endDate,
                    change: (value: string): void => {
                        this.route.endDate = value;
                    },
                }).layoutWeight(1)
            }.width('100%')
        }
        ContextRow({
            label: this.route.category || '全部分类',
            text: (this.route.projectId ? displayName(this.state.projectName(this.route.projectId)) : '全部计划') + '，' + this.summary.range.label,
        }).id('expense-scope')
    }

    @Builder moneySummary() {
        Column({ space: 10 }) {
            Row({ space: 8 }) {
                Stack({ alignContent: Alignment.Center }) {
                    SymbolGlyph(Icons.wallet).fontSize(17).fontColor([Theme.accent]).accessibilityLevel('no')
                }.width(32).height(32).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
                Text('已记录支出').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.muted)
            }
            RollingNumber({
                value: this.summary.totalCents / 100,
                decimals: 2,
                prefix: '¥',
                fontSize: 28,
                color: Theme.accent,
                accessibilityLabel: '当前范围已记录支出金额',
            })
            Text(this.summary.budgetText).fontSize(13).fontColor(Theme.muted)
            if (this.summary.canCompareBudget) {
                ContextRow({
                    label: this.summary.budgetSpentCents > this.summary.budgetCents ? '超出预算' : '剩余预算',
                    text: '¥' + (Math.abs(this.summary.budgetCents - this.summary.budgetSpentCents) / 100).toFixed(2),
                    tone: this.summary.budgetSpentCents > this.summary.budgetCents ? 'danger' : 'success',
                })
            } else if (this.summary.budgetCount) {
                Text('预算属于计划整体；查看全部日期和全部分类可比较累计支出。').fontSize(12).fontColor(Theme.muted)
            }
        }.padding(18)
            .width('100%')
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.heroRadius)
            .border({ width: 0.8, color: Theme.divider })
            .shadow({ radius: 10, color: Theme.shadow, offsetX: 0, offsetY: 3 })
            .alignItems(HorizontalAlign.Start)
    }

    @Builder categoryChart() {
        SectionHeading({ title: '分类统计', icon: Icons.wallet, trailing: '点击分类查看明细' })
        ForEach(this.summary.categories, (category: LedgerCategory) => {
            Column({ space: 8 }) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                    Text(category.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                    Row({ space: 8 }) {
                        StatusPill({ label: category.percent.toFixed(1) + '%', tone: 'brand', compact: true })
                        Text('¥' + (category.amount / 100).toFixed(2)).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                    }
                }.width('100%')
                Progress({ value: category.percent, total: 100, type: ProgressType.Linear })
                    .width('100%')
                    .color(Theme.brand)
                    .backgroundColor(Theme.tint)
                    .style({ strokeWidth: 5 })
                    .accessibilityLevel('no')
            }.id('expense-category:' + category.name)
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(14)
                .backgroundColor(Theme.tint)
                .borderRadius(12)
                .border({
                    width: this.route.category === category.name ? 1.5 : 0.8,
                    color: this.route.category === category.name ? Theme.accent : Theme.line,
                })
                .onClick((): void => {
                    vibration.dotVibration();
                    this.route.category = this.route.category === category.name ? '' : category.name;
                    this.route.section = 1;
                    this.route.restoreVersion++;
                })
                .accessibilityGroup(true)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilitySelected(this.route.category === category.name)
                .accessibilityText(category.name + '，花费 ' + (category.amount / 100).toFixed(2) + ' 元，占比 ' + category.percent.toFixed(1) + '%')
                .accessibilityDescription('双击筛选此分类，再次双击显示全部分类')
                .visualEffect(this.feedback.effect('expense-category:' + category.name, true))
                .compositingFilter(this.feedback.filter('expense-category:' + category.name, true))
                .attributeModifier(this.feedback.control('expense-category:' + category.name, true))
        }, (category: LedgerCategory): string => category.name)
    }

    @Builder expenseRecords() {
        SectionHeading({ title: '花费明细', icon: Icons.creditcard, trailing: this.summary.records.length + ' 笔' })
        if (this.route.category) {
            Button('显示全部分类', { type: ButtonType.Normal, stateEffect: false })
                .constraintSize({ minHeight: 38 })
                .padding({ left: 14, right: 14 })
                .borderRadius(Theme.pillRadius)
                .fontColor(Theme.accent)
                .fontSize(13)
                .backgroundColor(Theme.tint)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.route.category = '';
                })
                .accessibilityText('取消花费分类筛选')
                .visualEffect(this.feedback.effect('clear-category', false))
                .compositingFilter(this.feedback.filter('clear-category', false))
                .attributeModifier(this.feedback.control('clear-category', false))
        }
        ForEach(this.summary.records, (expense: Expense) => {
            Row({ space: 10 }) {
                Column({ space: 4 }) {
                    Row({ space: 8 }) {
                        Text(expense.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1)
                        Text('¥' + (expense.amountCents / 100).toFixed(2)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
                    }.width('100%')
                    ContextRow({
                        label: expense.category,
                        text: expense.date + ' ' + displayName(this.state.projectName(expense.projectId)),
                        tone: 'neutral',
                    })
                }.layoutWeight(1)
                    .constraintSize({ minHeight: 48 })
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Start)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.edit('expense', expense.id, expense.projectId);
                    })
                    .accessibilityGroup(true)
                    .accessibilityRole(AccessibilityRoleType.BUTTON)
                    .accessibilityText('编辑花费 ' + expense.name + '，' + (expense.amountCents / 100).toFixed(2) + ' 元，' + expense.date)
                    .visualEffect(this.feedback.effect('edit-expense:' + expense.id))
                    .compositingFilter(this.feedback.filter('edit-expense:' + expense.id))
                    .attributeModifier(this.feedback.control('edit-expense:' + expense.id))
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.remove).fontSize(16).fontColor([Theme.danger]).accessibilityLevel('no')
                }.width(38)
                    .height(38)
                    .backgroundColor(Theme.dangerBg)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.remove('expense', expense.id);
                    })
                    .accessibilityText('删除花费 ' + expense.name)
                    .visualEffect(this.feedback.effect('remove-expense:' + expense.id, false))
                    .compositingFilter(this.feedback.filter('remove-expense:' + expense.id, false))
                    .attributeModifier(this.feedback.control('remove-expense:' + expense.id, false))
            }.id('expense-record:' + expense.id)
                .padding(14)
                .width('100%')
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }, (expense: Expense): string => expense.id)
        if (!this.summary.records.length) {
            if (!this.state.expenses.length) {
                EmptyState({
                    title: '记下这次的实际花费',
                    message: '服装、妆造、摄影、门票和交通可以分别记录。',
                    button: '记一笔',
                    icon: Icons.creditcard,
                    action: (): void => {
                        this.edit('expense', '', this.route.projectId);
                    },
                })
            } else {
                EmptyState({
                    title: '当前范围没有花费记录',
                    message: '可以调整日期、计划或分类，再查看已有记录。',
                    button: '清除筛选',
                    icon: Icons.creditcard,
                    action: (): void => {
                        this.clearFilters();
                    },
                })
            }
        }
    }

    @Builder detailSections() {
        if (!this.summary.range.error) {
            Column({ space: Theme.sectionSpacing }) {
                if (this.route.section === 0) {
                    Column({ space: 10 }) {
                        this.categoryChart()
                    }.width('100%')
                        .backgroundColor(Theme.surface)
                        .borderRadius(Theme.cardRadius)
                        .border({ width: 0.8, color: Theme.line })
                        .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
                        .padding(16)
                    if (this.summary.months.length) {
                        InteractiveLineChart({
                            title: '有记录月份支出',
                            unit: '元',
                            points: this.summary.months,
                            viewport: { zoom: this.route.chartZoom, panRatio: this.route.chartPan },
                            onViewportChange: (value: ChartViewportState): void => {
                                this.route.chartZoom = value.zoom;
                                this.route.chartPan = value.panRatio;
                            },
                            lineColor: Theme.brand,
                            paletteId: Theme.paletteId,
                            chartHeight: 220,
                            responsiveAxisFont: true,
                        })
                        Text('仅显示当前筛选中有记录的月份；金额与上方明细一致。').fontSize(13).fontColor(Theme.muted)
                    }
                } else {
                    this.expenseRecords()
                }
            }.width('100%').alignItems(HorizontalAlign.Start)
        }
    }

    @Builder splitOverviewPane() {
        Column({ space: 14 }) {
            this.rangeControls()
            if (this.summary.range.error) {
                Text(this.summary.range.error).id('expense-range-error').fontSize(15).fontColor(Theme.danger)
            } else {
                this.moneySummary()
            }
        }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(1))
    }

    @Builder
    private splitDetailsPane() {
        Column() {
            this.detailSections()
        }.width('100%').attributeModifier(this.entrance.group(2))
    }

    build() {
        Stack() {
            if (this.isSplitLayout) {
                DashboardSplitLayout({
                    scroller: this.scroller,
                    overviewTop: Theme.detailTop,
                    scrollTop: Theme.detailTop,
                    bottomInset: Theme.detailFloatingBottom,
                    layoutId: 'expense-split',
                    overviewId: 'expense-overview',
                    scrollId: 'expense-scroll',
                    overviewLabel: '花费筛选与总计',
                    scrollLabel: '花费分类与明细',
                    overview: (): void => this.splitOverviewPane(),
                    content: (): void => this.splitDetailsPane(),
                })
            } else {
                Scroll(this.scroller) {
                    Column({ space: Theme.sectionSpacing }) {
                        Blank().height(Theme.detailTop).accessibilityLevel('no')
                        Column({ space: Theme.sectionSpacing }) {
                            this.rangeControls()
                            if (this.summary.range.error) {
                                Text(this.summary.range.error).id('expense-range-error').fontSize(15).fontColor(Theme.danger)
                            } else if (this.route.section === 0) {
                                this.moneySummary()
                            }
                        }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(1))
                        Column() {
                            this.detailSections()
                        }.width('100%').attributeModifier(this.entrance.group(2))
                        Blank().height(Theme.detailFloatingBottom).accessibilityLevel('no')
                    }.width('100%')
                        .constraintSize({ maxWidth: READING_MAX_WIDTH })
                        .alignItems(HorizontalAlign.Start)
                        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                }.id('expense-scroll')
                    .width('100%')
                    .height('100%')
                    .align(Alignment.Top)
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
                    .onAxisEvent((event: AxisEvent): void => {
                        scrollByAxis(this.scroller, event);
                    })
                    .onAreaChange((_, area: Area): void => {
                        if (!this.measured && Number(area.height) > 0) {
                            this.measured = true;
                            this.restoreScroll();
                        }
                    })
                    .onDidScroll((): void => {
                        if (this.measured && !this.restoring) {
                            this.route.offset = this.scroller.currentOffset().yOffset;
                        }
                    })
            }
        }.width('100%')
            .height('100%')
            .onAreaChange((_, area: Area): void => {
                const width = Number(area.width);
                const height = Number(area.height);
                if (width > 0 && height > 0) {
                    this.viewportWidth = width;
                    this.viewportHeight = height;
                }
            })
    }
}
