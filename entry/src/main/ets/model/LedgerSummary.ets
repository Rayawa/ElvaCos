import { LedgerRoute } from './LedgerRoute';
import { Expense } from './Planning';
import { PlanReadiness, budgetLabel } from './PlanReadiness';
import { validDate } from './Rules';
import { MonthlyExpensePoint } from './Statistics';

export class LedgerRange {
  start: string = '';
  end: string = '';
  label: string = '全部日期';
  error: string = '';
}
export class LedgerCategory {
  name: string = '';
  amount: number = 0;
  percent: number = 0;
  count: number = 0;
}
export class LedgerSummary {
  range: LedgerRange = new LedgerRange();
  records: Expense[] = [];
  totalCents: number = 0;
  categories: LedgerCategory[] = [];
  months: MonthlyExpensePoint[] = [];
  budgetCents: number = 0;
  budgetCount: number = 0;
  budgetSpentCents: number = 0;
  budgetText: string = '';
  canCompareBudget: boolean = false;
}

export function ledgerRange(route: LedgerRoute, today: string): LedgerRange {
  const result = new LedgerRange();
  if (route.range === 'all') { return result; }
  if (route.range === 'custom') {
    result.start = route.startDate; result.end = route.endDate; result.label = '自定义日期';
    if (!validDate(result.start) || !validDate(result.end)) { result.error = '请选择有效的开始日期和结束日期'; }
    else if (result.start > result.end) { result.error = '结束日期不能早于开始日期'; }
  } else if (validDate(today)) {
    if (route.range === 'year') {
      result.start = today.slice(0, 4) + '-01-01'; result.end = today.slice(0, 4) + '-12-31'; result.label = '本年';
    } else {
      result.start = today.slice(0, 7) + '-01';
      const last = new Date(Number(today.slice(0, 4)), Number(today.slice(5, 7)), 0, 12).getDate();
      result.end = today.slice(0, 7) + '-' + String(last).padStart(2, '0'); result.label = '本月';
    }
  } else { result.error = '当前日期暂不可用，请选择自定义日期或全部日期'; }
  if (!result.error) { result.label += '，' + result.start + ' 至 ' + result.end; }
  return result;
}

/** Every visible amount/chart/detail is derived from the same selected records. */
export function buildLedgerSummary(expenses: Expense[], plans: PlanReadiness[], route: LedgerRoute, today: string): LedgerSummary {
  const result = new LedgerSummary(); result.range = ledgerRange(route, today);
  if (result.range.error) { return result; }
  result.records = expenses.filter((expense: Expense): boolean =>
    (!route.projectId || expense.projectId === route.projectId) && (!route.category || expense.category === route.category) &&
    (!result.range.start || validDate(expense.date) && expense.date >= result.range.start && expense.date <= result.range.end))
    .sort((a: Expense, b: Expense): number => b.date.localeCompare(a.date) || b.createdAt - a.createdAt || a.id.localeCompare(b.id));
  const months: LedgerCategory[] = [];
  for (const expense of result.records) {
    result.totalCents += expense.amountCents;
    let category = result.categories.find((item: LedgerCategory) => item.name === expense.category);
    if (!category) { category = new LedgerCategory(); category.name = expense.category; result.categories.push(category); }
    category.amount += expense.amountCents; category.count++;
    const key = validDate(expense.date) ? expense.date.slice(0, 7) : '未记录日期';
    let month = months.find((item: LedgerCategory) => item.name === key);
    if (!month) { month = new LedgerCategory(); month.name = key; months.push(month); }
    month.amount += expense.amountCents; month.count++;
  }
  for (const category of result.categories) { category.percent = result.totalCents ? category.amount * 100 / result.totalCents : 0; }
  result.categories.sort((a: LedgerCategory, b: LedgerCategory) => b.amount - a.amount || a.name.localeCompare(b.name));
  result.months = months.sort((a: LedgerCategory, b: LedgerCategory) => a.name.localeCompare(b.name))
    .map((month: LedgerCategory): MonthlyExpensePoint => ({ label: month.name, value: month.amount / 100, detail: month.name + '，¥' + (month.amount / 100).toFixed(2) + '，' + month.count + ' 笔' }));
  const scopedPlans = plans.filter((plan: PlanReadiness) => !route.projectId || plan.id === route.projectId);
  const budgeted = scopedPlans.filter((plan: PlanReadiness) => plan.money.budgetConfigured === true);
  result.budgetCount = budgeted.length;
  result.budgetCents = budgeted.reduce((sum: number, plan: PlanReadiness) => sum + plan.money.budgetCents, 0);
  result.budgetSpentCents = budgeted.reduce((sum: number, plan: PlanReadiness) => sum + plan.money.spentCents, 0);
  result.canCompareBudget = route.range === 'all' && !route.category && result.budgetCount > 0;
  result.budgetText = route.projectId && scopedPlans.length ? '计划' + budgetLabel(scopedPlans[0].money.budgetConfigured, scopedPlans[0].money.budgetCents) :
    result.budgetCount ? '计划总预算 ¥' + (result.budgetCents / 100).toFixed(2) + '，覆盖 ' + result.budgetCount + ' 份计划' : '当前计划范围无明确预算';
  return result;
}
