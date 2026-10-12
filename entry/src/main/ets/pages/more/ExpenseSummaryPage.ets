import { displayName } from '../../common/format';
import { ContextRow } from '../../component/ContextRow';
import { LedgerRoute } from '../../model/LedgerRoute';
import { LedgerSummary, LedgerCategory, buildLedgerSummary } from '../../model/LedgerSummary';
import { DateField } from '../../component/DateField';
import { PressFeedback } from '../../common/pressFeedback';
import { AppState } from '../../model/ApplicationState';
import { READING_MAX_WIDTH } from '../../common/constants';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { scrollByAxis } from '../../common/scroll';
import { CosProject } from '../../model/Entities';
import { Expense } from '../../model/Planning';
import { StatusPill, SectionHeading, EmptyState } from '../../component/Surfaces';
import { pageTransition, StaggerEntrance } from '../../common/motion';
import { InteractiveLineChart, ChartViewportState } from '../../component/charts/InteractiveLineChart';

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

  private restoreTimer: number = -1;
  private restoring: boolean = true;
  private measured: boolean = false;
  aboutToAppear(): void {
    if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); }
    this.restoreScroll();
  }
  @Monitor('route.restoreVersion')
  private restoreScroll(): void {
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoring = true;
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false }); this.restoring = false;
    }, 0);
  }
  aboutToDisappear(): void {
    if (!this.entrance.managed) { this.entrance.reset(); }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; }
  }
  @Monitor('route.projectId', 'route.category', 'route.range', 'route.startDate', 'route.endDate')
  private filterChanged(): void {
    this.route.offset = 0; this.route.chartZoom = 1; this.route.chartPan = 0;
    this.restoreScroll();
  }
  @Computed
  private get summary(): LedgerSummary {
    if (this.route.range === 'month' && !this.route.projectId && !this.route.category) { return this.state.monthLedger; }
    return buildLedgerSummary(this.state.expenses, this.state.readinessPlans, this.route, this.state.localDate);
  }
  @Computed
  private get categoryNames(): string[] { return Array.from(new Set(this.state.expenses.map((expense: Expense) => expense.category))).sort(); }
  private categoryOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部分类' }];
    return options.concat(this.categoryNames.map((name: string): SelectOption => ({ value: name })));
  }
  private chooseRange(index: number): void {
    if (RANGES[index] === 'custom') {
      if (!this.route.startDate) { this.route.startDate = this.summary.range.start || this.state.localDate; }
      if (!this.route.endDate) { this.route.endDate = this.summary.range.end || this.state.localDate; }
    }
    this.route.range = RANGES[index];
  }
  private clearFilters(): void { this.route.range = 'all'; this.route.projectId = ''; this.route.category = ''; }
  private sourceLabel(): string {
    if (!this.route.sourceProjectId) { return '从全局花费统计进入'; }
    const project = this.state.projects.find((item: CosProject) => item.id === this.route.sourceProjectId);
    return project ? '来源计划：' + displayName(project.name) + '（进入时为全部日期）' : '来源计划已不存在';
  }
  @Builder rangeControls() {
    Text(this.sourceLabel()).fontSize(14).fontColor(Theme.muted)
    Select(RANGE_LABELS.map((label: string): SelectOption => ({ value: label }))).id('expense-range')
      .value(RANGE_LABELS[RANGES.indexOf(this.route.range)]).onSelect((index: number): void => { this.chooseRange(index); })
      .accessibilityText('花费日期范围')
    if (this.route.range === 'custom') {
      DateField({ label: '开始日期（含当天）', value: this.route.startDate, change: (value: string): void => { this.route.startDate = value; } })
      DateField({ label: '结束日期（含当天）', value: this.route.endDate, change: (value: string): void => { this.route.endDate = value; } })
    }
    Select(new Array<SelectOption>({ value: '全部计划' }).concat(this.state.projects.map((project: CosProject): SelectOption => ({ value: project.name }))))
      .id('expense-project').value(this.route.projectId ? this.state.projectName(this.route.projectId) : '全部计划')
      .onSelect((index: number): void => { vibration.dotVibration(); this.route.projectId = index === 0 ? '' : this.state.projects[index - 1].id; })
      .accessibilityText('花费所属计划')
    Select(this.categoryOptions()).id('expense-category-filter').value(this.route.category || '全部分类')
      .onSelect((index: number): void => { this.route.category = index === 0 ? '' : this.categoryNames[index - 1]; })
      .accessibilityText('花费分类筛选')
    ContextRow({ label: this.route.category || '全部分类', text: (this.route.projectId ? displayName(this.state.projectName(this.route.projectId)) : '全部计划') + '，' + this.summary.range.label }).id('expense-scope')
  }
  @Builder moneySummary() {
    Column({ space: 8 }) {
      Text('已记录支出 ¥' + (this.summary.totalCents / 100).toFixed(2)).fontSize(24).fontColor(Theme.accent)
        .accessibilityText('当前范围已记录支出 ' + (this.summary.totalCents / 100).toFixed(2) + ' 元')
      Text(this.summary.budgetText).fontSize(14).fontColor(Theme.muted)
      if (this.summary.canCompareBudget) {
        ContextRow({ label: this.summary.budgetSpentCents > this.summary.budgetCents ? '超出预算' : '剩余预算', text: '¥' + (Math.abs(this.summary.budgetCents - this.summary.budgetSpentCents) / 100).toFixed(2) })
      } else if (this.summary.budgetCount) { Text('预算属于计划整体；查看全部日期和全部分类可比较累计支出。').fontSize(14).fontColor(Theme.muted) }

    }.padding(18).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).alignItems(HorizontalAlign.Start)
  }

  @Builder categoryChart() {
    SectionHeading({ title: '分类统计', trailing: '点击分类查看明细' })
    ForEach(this.summary.categories, (category: LedgerCategory) => {
      Column({ space: 8 }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          Text(category.name).fontColor(Theme.ink)
          Row({ space: 8 }) {
            StatusPill({ label: category.percent.toFixed(1) + '%' })
            Text('¥' + (category.amount / 100).toFixed(2)).fontSize(14).fontColor(Theme.ink)
          }
        }.width('100%')
        Progress({ value: category.percent, total: 100, type: ProgressType.Linear })
          .width('100%').color(Theme.brand).backgroundColor(Theme.tint).accessibilityLevel('no')
      }.id('expense-category:' + category.name).width('100%').alignItems(HorizontalAlign.Start).padding(14)
        .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        .border({ width: this.route.category === category.name ? 1 : 0, color: Theme.accent })
        .onClick((): void => { vibration.dotVibration(); this.route.category = this.route.category === category.name ? '' : category.name; })
        .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilitySelected(this.route.category === category.name)
        .accessibilityText(category.name + '，花费 ' + (category.amount / 100).toFixed(2) + ' 元，占比 ' + category.percent.toFixed(1) + '%')
        .accessibilityDescription('双击筛选此分类，再次双击显示全部分类')
        .visualEffect(this.feedback.effect('expense-category:' + category.name, true))
        .compositingFilter(this.feedback.filter('expense-category:' + category.name, true))
        .attributeModifier(this.feedback.control('expense-category:' + category.name, true))
    }, (category: LedgerCategory): string => category.name)
  }

  @Builder expenseRecords() {
    SectionHeading({ title: '花费明细', trailing: this.summary.records.length + ' 笔' })
    if (this.route.category) {
      Button('显示全部分类').constraintSize({ minHeight: 48 }).fontColor(Theme.accent).backgroundColor(Theme.tint)
        .onClick((): void => { vibration.dotVibration(); this.route.category = ''; })
        .accessibilityText('取消花费分类筛选').visualEffect(this.feedback.effect('clear-category')).compositingFilter(this.feedback.filter('clear-category')).attributeModifier(this.feedback.control('clear-category'))
    }
    ForEach(this.summary.records, (expense: Expense) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(expense.name).fontSize(16).fontColor(Theme.ink).layoutWeight(1)
            Text('¥' + (expense.amountCents / 100).toFixed(2)).fontSize(16).fontColor(Theme.ink)
          }.width('100%')
          ContextRow({ label: expense.category, text: expense.date + '，' + displayName(this.state.projectName(expense.projectId)) })
        }.layoutWeight(1).constraintSize({ minHeight: 48 }).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start).enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.edit('expense', expense.id, expense.projectId); })
          .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('编辑花费 ' + expense.name + '，' + (expense.amountCents / 100).toFixed(2) + ' 元，' + expense.date)
          .visualEffect(this.feedback.effect('edit-expense:' + expense.id))
          .compositingFilter(this.feedback.filter('edit-expense:' + expense.id))
          .attributeModifier(this.feedback.control('edit-expense:' + expense.id))
        Button('−').constraintSize({ minWidth: 48, minHeight: 48 }).backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.remove('expense', expense.id); })
          .accessibilityText('删除花费 ' + expense.name).visualEffect(this.feedback.effect('remove-expense:' + expense.id)).compositingFilter(this.feedback.filter('remove-expense:' + expense.id)).attributeModifier(this.feedback.control('remove-expense:' + expense.id))
      }.id('expense-record:' + expense.id).padding(14).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    }, (expense: Expense): string => expense.id)
    if (!this.summary.records.length) {
      if (!this.state.expenses.length) {
        EmptyState({ title: '记下这次的实际花费', message: '服装、妆造、摄影、门票和交通可以分别记录。',
          button: '＋ 记一笔', action: (): void => { this.edit('expense', '', this.route.projectId); } })
      } else {
        EmptyState({ title: '当前范围没有花费记录', message: '可以调整日期、计划或分类，再查看已有记录。',
          button: '清除筛选', action: (): void => { this.clearFilters(); } })
      }
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).accessibilityLevel('no')
        Column({ space: Theme.sectionSpacing }) {
          this.rangeControls()
          if (this.summary.range.error) { Text(this.summary.range.error).id('expense-range-error').fontSize(16).fontColor(Theme.accent) }
          else { this.moneySummary() }
        }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(1))
        if (!this.summary.range.error) {
          Column({ space: Theme.sectionSpacing }) {
            this.categoryChart()
            this.expenseRecords()
            if (this.summary.months.length) {
              InteractiveLineChart({ title: '有记录月份支出', unit: '元', points: this.summary.months,
                viewport: { zoom: this.route.chartZoom, panRatio: this.route.chartPan },
                onViewportChange: (value: ChartViewportState): void => { this.route.chartZoom = value.zoom; this.route.chartPan = value.panRatio; },
                lineColor: Theme.brand, paletteId: Theme.paletteId, chartHeight: 220, responsiveAxisFont: true })
              Text('仅显示当前筛选中有记录的月份；金额与上方明细一致。').fontSize(14).fontColor(Theme.muted)
            }
          }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(2))
        }
        Blank().height(Theme.detailBottom).accessibilityLevel('no')
      }.width('100%').constraintSize({ maxWidth: READING_MAX_WIDTH }).alignItems(HorizontalAlign.Start)
        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.id('expense-scroll').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto).transition(pageTransition())
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
      .onAreaChange((_, area: Area): void => {
        if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreScroll(); }
      })
      .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offset = this.scroller.currentOffset().yOffset; } })
  }
}
