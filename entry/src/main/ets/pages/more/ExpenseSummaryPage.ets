import { PressFeedback } from '../../common/pressFeedback';
import { AppState } from '../../model/ApplicationState';
import { READING_MAX_WIDTH } from '../../common/constants';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { scrollByAxis } from '../../common/scroll';
import { CosProject } from '../../model/Entities';
import { Expense, expenseTotal } from '../../model/Planning';
import { SectionHeading, EmptyState } from '../../component/Surfaces';
import { pageTransition, StaggerEntrance } from '../../common/motion';

interface ExpenseCategory {
  name: string;
  amount: number;
  percent: number;
}

@ComponentV2
export struct ExpenseSummary {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  private scroller: Scroller = new Scroller();
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Require @Param state: AppState;
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local projectId: string = '';
  @Local category: string = '';

  aboutToAppear(): void { if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (!this.entrance.managed) { this.entrance.reset(); } }

  @Computed
  private get records(): Expense[] {
    return this.state.expenses.filter((expense: Expense): boolean => !this.projectId || expense.projectId === this.projectId);
  }

  @Computed
  private get visibleRecords(): Expense[] {
    return this.records.filter((expense: Expense): boolean => !this.category || expense.category === this.category);
  }

  @Computed
  private get categories(): ExpenseCategory[] {
    const categories: ExpenseCategory[] = [];
    const total = expenseTotal(this.records);
    for (const expense of this.records) {
      const category = categories.find((item: ExpenseCategory): boolean => item.name === expense.category);
      if (category) { category.amount += expense.amountCents; }
      else { categories.push({ name: expense.category, amount: expense.amountCents, percent: 0 }); }
    }
    for (const category of categories) { category.percent = total > 0 ? category.amount * 100 / total : 0; }
    return categories.sort((a: ExpenseCategory, b: ExpenseCategory): number => b.amount - a.amount);
  }

  private budget(): number {
    return this.state.projects.filter((project: CosProject): boolean => !this.projectId || project.id === this.projectId)
      .reduce((sum: number, project: CosProject): number => sum + project.budgetCents, 0);
  }

  @Builder categoryChart() {
    SectionHeading({ title: '分类统计', trailing: '点击分类查看明细' })
    ForEach(this.categories, (category: ExpenseCategory) => {
      Column({ space: 8 }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          Text(category.name).fontColor(Theme.ink)
          Text('¥' + (category.amount / 100).toFixed(2) + ' · ' + category.percent.toFixed(1) + '%')
            .fontSize(14).fontColor(Theme.accent)
        }.width('100%')
        Progress({ value: category.percent, total: 100, type: ProgressType.Linear })
          .width('100%').color(Theme.accent).backgroundColor(Theme.tint).accessibilityLevel('no')
      }.id('expense-category:' + category.name).width('100%').alignItems(HorizontalAlign.Start).padding(14)
        .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        .border({ width: this.category === category.name ? 1 : 0, color: Theme.accent })
        .onClick((): void => { vibration.dotVibration(); this.category = this.category === category.name ? '' : category.name; })
        .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilitySelected(this.category === category.name)
        .accessibilityText(category.name + '，花费 ' + (category.amount / 100).toFixed(2) + ' 元，占比 ' + category.percent.toFixed(1) + '%')
        .accessibilityDescription('双击筛选此分类，再次双击显示全部分类')
        .attributeModifier(this.feedback.control('expense-category:' + category.name, true))
    }, (category: ExpenseCategory): string => category.name)
  }

  @Builder expenseRecords() {
    SectionHeading({ title: '花费明细', trailing: this.visibleRecords.length + ' 笔' })
    if (this.category) {
      Button('显示全部分类').fontColor(Theme.accent).backgroundColor(Theme.tint)
        .onClick((): void => { vibration.dotVibration(); this.category = ''; })
        .accessibilityText('取消花费分类筛选').attributeModifier(this.feedback.control('clear-category'))
    }
    ForEach(this.visibleRecords, (expense: Expense) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) {
          Text(expense.name + ' · ¥' + (expense.amountCents / 100).toFixed(2)).fontColor(Theme.ink)
          Text(expense.date + ' · ' + expense.category + ' · ' + this.state.projectName(expense.projectId))
            .fontSize(12).fontColor(Theme.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.edit('expense', expense.id, expense.projectId); })
          .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('编辑花费 ' + expense.name + '，' + (expense.amountCents / 100).toFixed(2) + ' 元，' + expense.date)
          .attributeModifier(this.feedback.control('edit-expense:' + expense.id))
        Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.remove('expense', expense.id); })
          .accessibilityText('删除花费 ' + expense.name).attributeModifier(this.feedback.control('remove-expense:' + expense.id))
      }.id('expense-record:' + expense.id).padding(14).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    }, (expense: Expense): string => expense.id)
    if (this.records.length === 0) {
      EmptyState({
        title: '记下这次的实际花费', message: '服装、妆造、摄影、门票和交通可以分别记录。',
        button: '＋ 添加花费', action: (): void => this.edit('expense', '', this.projectId),
      })
    } else if (this.visibleRecords.length === 0) {
      Text('此分类暂无花费记录，可显示全部分类。').fontColor(Theme.muted).accessibilityText('此分类暂无花费记录，可显示全部分类')
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).accessibilityLevel('no')
        Column({ space: Theme.sectionSpacing }) {
          Select(new Array<SelectOption>({ value: '全部计划' }).concat(this.state.projects.map((project: CosProject): SelectOption => ({ value: project.name }))))
            .id('expense-project').value(this.projectId ? this.state.projectName(this.projectId) : '全部计划')
            .onSelect((index: number): void => {
              vibration.dotVibration();
              this.projectId = index === 0 ? '' : this.state.projects[index - 1].id;
              this.category = '';
            })
            .accessibilityText('花费所属计划').attributeModifier(this.feedback.control('expense-project'))
          Column({ space: 8 }) {
            Text('实际花费 ¥' + (expenseTotal(this.records) / 100).toFixed(2)).fontSize(24).fontColor(Theme.accent)
              .accessibilityText('实际花费 ' + (expenseTotal(this.records) / 100).toFixed(2) + ' 元')
            Text('预计预算 ¥' + (this.budget() / 100).toFixed(2)).fontSize(14).fontColor(Theme.muted)
              .accessibilityText('预计预算 ' + (this.budget() / 100).toFixed(2) + ' 元')
            Text('只统计已记录的花费，复用衣柜装备不会自动计费。').fontSize(12).fontColor(Theme.muted)
              .accessibilityText('只统计已记录的花费，复用衣柜装备不会自动计费')
          }.padding(18).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            .alignItems(HorizontalAlign.Start).attributeModifier(this.feedback.control('expense-total', true))
        }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(1))
        Column({ space: Theme.sectionSpacing }) {
          this.categoryChart()
          this.expenseRecords()
        }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(2))
        Blank().height(Theme.contentBottom).accessibilityLevel('no')
      }.width('100%').constraintSize({ maxWidth: READING_MAX_WIDTH }).alignItems(HorizontalAlign.Start)
        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.id('expense-scroll').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto).transition(pageTransition())
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
