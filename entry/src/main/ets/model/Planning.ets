import { newId, ManagedMedia } from './Entities';

export class TeamMember {
  id: string = newId();
  projectId: string = '';
  role: string = '摄影';
  name: string = '';
  notes: string = '';
}

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
