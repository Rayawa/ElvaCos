import { newId, ManagedMedia } from './Entities';

export class TeamMember {
  id: string = newId();
  projectId: string = '';
  role: string = '摄影';
  name: string = '';
  notes: string = '';
}
export const TEAM_ROLES: string[] = ['毛娘', '妆娘', '摄影', '后勤', '后期', '其他'];

export class Expense {
  id: string = newId();
  projectId: string = '';
  name: string = '';
  category: string = '服装';
  amountCents: number = 0;
  date: string = '';
  notes: string = '';
  createdAt: number = Date.now();
}
export const EXPENSE_CATEGORIES: string[] = ['服装', '假发', '美瞳', '妆造', '摄影', '后期', '门票', '交通', '住宿', '道具', '其他'];
export function expenseTotal(expenses: Expense[], projectId: string = ''): number {
  return expenses.filter((e: Expense) => !projectId || e.projectId === projectId).reduce((total: number, e: Expense) => total + e.amountCents, 0);
}

export class ReferenceImage implements ManagedMedia {
  id: string = newId();
  projectId: string = '';
  characterId: string = '';
  sourceUri: string = '';
  localPath: string = '';
  thumbnailPath: string = '';
  caption: string = '';
  createdAt: number = Date.now();
}
