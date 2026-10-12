import { CosProject, AssetStatus } from './Entities';
import { PlanReadiness } from './PlanReadiness';
import { PreparationTask } from './Preparation';

export class TaskQueueItem {
  id: string = '';
  kind: string = 'preparation';
  source: string = 'preparation';
  projectId: string = '';
  projectName: string = '';
  focusId: string = '';
  title: string = '';
  detail: string = '';
  date: string = '';
  group: string = 'undated';
  section: number = 1;
  photoFilter: number = 0;
}
@ObservedV2
export class TaskRoute {
  @Trace category: string = 'action';
  @Trace projectId: string = '';
  @Trace range: string = 'action';
  @Trace restoreVersion: number = 0;
  offset: number = 0;
  constructor(projectId: string = '') { this.projectId = projectId; }
}
export function dateGroup(date: string, today: string): string {
  if (!date) { return 'undated'; }
  const week = new Date(today + 'T12:00:00'); week.setDate(week.getDate() + 7);
  const end = String(week.getFullYear()) + '-' + String(week.getMonth() + 1).padStart(2, '0') + '-' + String(week.getDate()).padStart(2, '0');
  return date < today ? 'overdue' : date === today ? 'today' : date <= end ? 'week' : 'later';
}
export function buildTaskQueue(plans: PlanReadiness[], projects: CosProject[], today: string): TaskQueueItem[] {
  const items: TaskQueueItem[] = [];
  for (const plan of plans.filter((item: PlanReadiness) => item.active)) {
    const name = projects.find((project: CosProject) => project.id === plan.id)?.name || '计划已不存在';
    const make = (kind: string, id: string, title: string): TaskQueueItem => {
      const item = new TaskQueueItem(); item.id = kind + ':' + plan.id + ':' + id;
      item.kind = kind; item.projectId = plan.id; item.projectName = name; item.focusId = id; item.title = title;
      return item;
    };
    for (const task of plan.prep.pending.concat(plan.prep.waitingItems)) {
      const waiting = plan.prep.waitingItems.some((item: PreparationTask) => item.id === task.id);
      const item = make(waiting ? 'waiting' : 'preparation', task.id, task.label);
      item.source = 'preparation'; item.date = waiting ? task.waitingUntil : task.dueDate;
      item.group = waiting ? 'waiting' : plan.prep.overdue.includes(task) ? 'overdue' : plan.prep.today.includes(task) ? 'today' : plan.prep.upcoming.includes(task) ? 'week' : !task.dueDate ? 'undated' : 'later';
      item.detail = waiting ? (task.waitingOn || '等待外部进展') + (task.waitingUntil ? '，等待至 ' + task.waitingUntil : '') : task.dueDate ? '截止 ' + task.dueDate : '未定期';
      items.push(item);
    }
    for (const asset of plan.equipment.waiting) {
      const item = make('waiting', asset.id, asset.name); item.source = 'asset'; item.group = 'waiting';
      item.detail = asset.status === AssetStatus.ORDERED ? '等收货' : asset.status === AssetStatus.REPAIR ? '等维修完成' : '等借出归还'; items.push(item);
    }
    for (const pack of plan.pack.pending) {
      const item = make('packing', pack.id, pack.label); item.source = 'packing'; item.section = 2;
      item.date = plan.date; item.group = dateGroup(plan.date, today); item.detail = plan.date ? '出行日期 ' + plan.date : '出行日期待定'; items.push(item);
    }
    for (const stage of [0, 2]) {
      const count = plan.photos.byStage[stage]; if (!count) { continue; }
      const item = make('photo', String(stage), (stage === 0 ? '待选 ' : '待修 ') + count + ' 张');
      item.source = 'photo'; item.section = 3; item.photoFilter = stage === 0 ? 1 : 3;
      item.date = plan.date; item.group = 'queue'; item.detail = plan.date ? '计划日期 ' + plan.date : '计划日期待定'; items.push(item);
    }
  }
  const order: string[] = ['waiting', 'overdue', 'today', 'week', 'queue', 'undated', 'later'];
  return items.sort((a: TaskQueueItem, b: TaskQueueItem) => order.indexOf(a.group) - order.indexOf(b.group) || (a.date || '9999').localeCompare(b.date || '9999') || a.projectName.localeCompare(b.projectName) || a.id.localeCompare(b.id));
}
export function taskNeedsAction(item: TaskQueueItem): boolean { return ['overdue', 'today', 'week', 'queue'].includes(item.group); }
export function filterTaskQueue(items: TaskQueueItem[], route: TaskRoute, today: string): TaskQueueItem[] {
  return items.filter((item: TaskQueueItem) => {
    if (route.projectId && item.projectId !== route.projectId) { return false; }
    if (route.category === 'action' ? item.kind === 'waiting' : route.category !== 'all' && item.kind !== route.category) { return false; }
    if (route.range === 'action') { return taskNeedsAction(item); }
    if (route.range === 'overdue') { return item.group === 'overdue'; }
    if (route.range === 'today') { return item.date === today; }
    if (route.range === 'week') { return item.date > today && dateGroup(item.date, today) === 'week'; }
    if (route.range === 'undated') { return !item.date; }
    return true;
  });
}
