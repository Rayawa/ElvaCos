import { CosEvent, CosProject } from './Entities';
import { PlanReadiness } from './PlanReadiness';
import { PreparationTask } from './Preparation';
import { calendarDays, CalendarDay, eventsOnDate, ScheduleGroup, scheduleGroups } from './Schedule';
import { ScheduleRoute } from './ScheduleRoute';
import { TaskQueueItem } from './TaskQueue';

export class ScheduleTaskItem {
  task: PreparationTask;
  projectName: string;
  waiting: boolean;
  overdue: boolean;
  constructor(task: PreparationTask, projectName: string, waiting: boolean, overdue: boolean) {
    this.task = task; this.projectName = projectName; this.waiting = waiting; this.overdue = overdue;
  }
}
export class ScheduleDayCell {
  day: CalendarDay;
  events: CosEvent[] = [];
  tasks: ScheduleTaskItem[] = [];
  constructor(day: CalendarDay) { this.day = day; }
}
export class ScheduleView {
  groups: ScheduleGroup[] = [];
  selectedEvents: CosEvent[] = [];
  selectedTasks: ScheduleTaskItem[] = [];
  days: ScheduleDayCell[] = [];
  pendingCount: number = 0;
}
export function deadlineTasksOnDate(plans: PlanReadiness[], projects: CosProject[], date: string): ScheduleTaskItem[] {
  const tasks: ScheduleTaskItem[] = [];
  if (!date) { return tasks; }
  for (const plan of plans.filter((item: PlanReadiness) => item.active)) {
    const name = projects.find((project: CosProject) => project.id === plan.id)?.name || '计划已不存在';
    for (const task of plan.prep.items) {
      if (task.dueDate === date) { tasks.push(new ScheduleTaskItem(task, name, plan.prep.waitingItems.includes(task), plan.prep.overdue.includes(task))); }
    }
  }
  return tasks.sort((a: ScheduleTaskItem, b: ScheduleTaskItem) => a.projectName.localeCompare(b.projectName) || a.task.sortOrder - b.task.sortOrder || a.task.id.localeCompare(b.task.id));
}
export function scheduleTaskRoute(item: ScheduleTaskItem): TaskQueueItem {
  const route = new TaskQueueItem(); route.id = 'preparation:' + item.task.projectId + ':' + item.task.id;
  route.projectId = item.task.projectId; route.projectName = item.projectName; route.focusId = item.task.id;
  route.title = item.task.label; route.date = item.task.dueDate; route.section = 1;
  route.kind = item.waiting ? 'waiting' : 'preparation'; return route;
}
export function buildScheduleView(events: CosEvent[], plans: PlanReadiness[], projects: CosProject[], route: ScheduleRoute, today: string): ScheduleView {
  const result = new ScheduleView();
  const typed = events.filter((event: CosEvent) => !route.eventType || event.eventType === route.eventType);
  result.pendingCount = typed.filter((event: CosEvent) => event.dateMode === 'pending').length;
  result.days = calendarDays(route.year, route.month).map((day: CalendarDay): ScheduleDayCell => {
    const cell = new ScheduleDayCell(day); cell.events = eventsOnDate(typed, day.date);
    cell.tasks = deadlineTasksOnDate(plans, projects, day.date); return cell;
  });
  const selected = result.days.find((cell: ScheduleDayCell) => cell.day.date === route.selectedDate);
  result.selectedEvents = selected?.events || eventsOnDate(typed, route.selectedDate);
  result.selectedTasks = selected?.tasks || deadlineTasksOnDate(plans, projects, route.selectedDate);
  const groups = scheduleGroups(typed, today);
  result.groups = route.dateFocused ? [new ScheduleGroup(route.selectedDate, result.selectedEvents)] :
    route.filter === 1 ? [groups[3]] : route.filter === 2 ? [groups[2]] : route.filter === 3 ? [groups[0]] : route.filter === 4 ? [groups[1]] : groups;
  return result;
}
