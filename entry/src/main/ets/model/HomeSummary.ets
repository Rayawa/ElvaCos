import { CosProject, ProjectStatus, newId } from './Entities';
import { PreparationTask } from './Preparation';
import { TaskQueueItem, taskNeedsAction } from './TaskQueue';

export const PREPARATION_UNDO_MS: number = 10000;
export class PreparationUndo {
  id: string = newId();
  taskId: string;
  projectId: string;
  label: string;
  previousDone: boolean;
  expectedDone: boolean;
  expiresAt: number;
  constructor(task: PreparationTask, now: number) {
    this.taskId = task.id; this.projectId = task.projectId; this.label = task.label;
    this.previousDone = task.done; this.expectedDone = !task.done; this.expiresAt = now + PREPARATION_UNDO_MS;
  }
}
export function usablePreparationUndo(token: PreparationUndo, tasks: PreparationTask[], projects: CosProject[], now: number): boolean {
  const task = tasks.find((item: PreparationTask) => item.id === token.taskId && item.projectId === token.projectId);
  const project = projects.find((item: CosProject) => item.id === token.projectId);
  return now < token.expiresAt && !!task && task.done === token.expectedDone && !!project && project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED;
}
/** Tokens are created after the write commits. Keep that feedback while its snapshot is pending. */
export function visiblePreparationUndos(tokens: PreparationUndo[], tasks: PreparationTask[], projects: CosProject[], now: number, snapshotPending: boolean): PreparationUndo[] {
  return tokens.filter((token: PreparationUndo): boolean => {
    if (usablePreparationUndo(token, tasks, projects, now)) { return true; }
    return snapshotPending && now < token.expiresAt && tasks.some((task: PreparationTask) => task.id === token.taskId && task.projectId === token.projectId) && projects.some((project: CosProject) => project.id === token.projectId && project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED);
  });
}
export class HomeTaskRow {
  key: string;
  item: TaskQueueItem;
  retired: boolean = false;
  undo?: PreparationUndo;
  constructor(item: TaskQueueItem) { this.key = item.id; this.item = item; }
}
export function homeCandidates(queue: TaskQueueItem[]): TaskQueueItem[] {
  return queue.filter((item: TaskQueueItem) => item.kind === 'waiting').concat(queue.filter(taskNeedsAction)).slice(0, 5);
}
/** Preserve pending rows; refill at the end after the completion feedback has left. */
export function advanceHomeSnapshot(snapshot: TaskQueueItem[], queue: TaskQueueItem[], undos: PreparationUndo[], now: number): TaskQueueItem[] {
  const eligible = queue.filter((item: TaskQueueItem) => item.kind === 'waiting' || taskNeedsAction(item));
  const matches = (a: TaskQueueItem, b: TaskQueueItem): boolean => a.source === b.source && a.projectId === b.projectId && a.focusId === b.focusId;
  const tokenFor = (item: TaskQueueItem): PreparationUndo | undefined => item.source === 'preparation' ? undos.find((token: PreparationUndo) => token.taskId === item.focusId && token.projectId === item.projectId) : undefined;
  // Keep an expired completion for one clock tick so its collapse can finish.
  const kept = snapshot.filter((item: TaskQueueItem) => eligible.some((candidate: TaskQueueItem) => matches(candidate, item)) || (!!tokenFor(item) && now < (tokenFor(item)?.expiresAt || 0) + 1000));
  let visible = kept.filter((item: TaskQueueItem) => eligible.some((candidate: TaskQueueItem) => matches(candidate, item)) || now < (tokenFor(item)?.expiresAt || 0)).length;
  for (const candidate of eligible) {
    if (visible >= 5) { break; }
    if (!kept.some((item: TaskQueueItem) => matches(candidate, item))) { kept.push(candidate); visible++; }
  }
  return kept;
}
/** Reconcile current values without sorting the visit's captured rows. */
export function reconcileHomeRows(snapshot: TaskQueueItem[], queue: TaskQueueItem[], undos: PreparationUndo[], now: number): HomeTaskRow[] {
  const eligible = queue.filter((item: TaskQueueItem) => item.kind === 'waiting' || taskNeedsAction(item));
  return snapshot.map((item: TaskQueueItem): HomeTaskRow => {
    const row = new HomeTaskRow(item);
    const current = eligible.find((candidate: TaskQueueItem) => candidate.source === item.source && candidate.projectId === item.projectId && candidate.focusId === item.focusId);
    if (current) { row.item = current; }
    row.undo = item.source === 'preparation' ? undos.find((token: PreparationUndo) => token.taskId === item.focusId && token.projectId === item.projectId && now < token.expiresAt) : undefined;
    row.retired = !current && !row.undo; return row;
  });
}
export function homeTaskCapacity(viewport: number, top: number, bottom: number, next: number, recent: number, row: number): number {
  return Math.max(1, Math.min(5, Math.floor((viewport - top - bottom - next - recent - 104) / Math.max(56, row))));
}
