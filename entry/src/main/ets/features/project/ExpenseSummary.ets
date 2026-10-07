import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { CosProject } from '../../model/Entities';
import { Expense, expenseTotal } from '../../model/Planning';
import { SectionHeading, EmptyState } from '../../components/Surfaces';
import { pageTransition } from '../../common/motion';

@ComponentV2
export struct ExpenseSummary {
  @Param state: AppState = new AppState();
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local projectId: string = '';
  private records(): Expense[] { return this.state.expenses.filter((e: Expense) => !this.projectId || e.projectId === this.projectId); }
  private categories(): string[] { const categories: string[] = []; for (const e of this.records()) { if (!categories.includes(e.category)) { categories.push(e.category); } } return categories; }
  private budget(): number { return this.state.projects.filter((p: CosProject) => !this.projectId || p.id === this.projectId).reduce((sum: number, p: CosProject) => sum + p.budgetCents, 0); }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Select(new Array<SelectOption>({ value: '全部计划' }).concat(this.state.projects.map((p: CosProject): SelectOption => { return { value: p.name }; })))
          .value(this.projectId ? this.state.projectName(this.projectId) : '全部计划')
          .onSelect((index: number): void => { vibration.dotVibration(); this.projectId = index === 0 ? '' : this.state.projects[index - 1].id; }).accessibilityText('花费所属计划')
        Column({ space: 8 }) {
          Text('实际花费 ¥' + (expenseTotal(this.records()) / 100).toFixed(2)).fontSize(24).fontColor(Theme.accent)
          Text('预计预算 ¥' + (this.budget() / 100).toFixed(2)).fontSize(14).fontColor(Theme.muted)
          Text('只统计已记录的花费，复用衣柜装备不会自动计费。').fontSize(12).fontColor(Theme.muted)
        }.padding(18).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).alignItems(HorizontalAlign.Start)
        SectionHeading({ title: '分类统计' })
        ForEach(this.categories(), (category: string) => {
          Row() { Text(category).fontColor(Theme.ink).layoutWeight(1); Text('¥' + (expenseTotal(this.records().filter((e: Expense) => e.category === category)) / 100).toFixed(2)).fontColor(Theme.accent) }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(14)
        }, (category: string) => category)
        SectionHeading({ title: '花费明细', trailing: this.records().length + ' 笔' })
        ForEach(this.records(), (e: Expense) => {
          Row({ space: 8 }) {
            Column({ space: 5 }) { Text(e.name + ' · ¥' + (e.amountCents / 100).toFixed(2)).fontColor(Theme.ink); Text(e.date + ' · ' + e.category + ' · ' + this.state.projectName(e.projectId)).fontSize(12).fontColor(Theme.muted) }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick((): void => { vibration.dotVibration(); this.edit('expense', e.id, e.projectId); }).accessibilityText('编辑花费 ' + e.name)
            Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.remove('expense', e.id); }).accessibilityText('删除花费 ' + e.name)
          }.padding(14).width('100%').backgroundColor(Theme.surface).borderRadius(16)
        }, (e: Expense) => e.id)
        if (this.records().length === 0) { EmptyState({ title: '记下这次的实际花费', message: '服装、妆造、摄影、门票和交通可以分别记录。', button: '＋ 添加花费', action: (): void => this.edit('expense', '', this.projectId) }) }
        Blank().height(Theme.contentBottom).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off).transition(pageTransition())
  }
}
