import { TaskTemplate, CategoryTemplate } from '../common/types';
import { PREPARATION_TEMPLATES } from '../common/constants';
import { newId, ProjectProgress } from './Entities';

export class PreparationCategory {
  id: string = newId();
  projectId: string = '';
  name: string = '';
  sortOrder: number = 0;
}

export class PreparationTask {
  id: string = newId();
  projectId: string = '';
  categoryId: string = '';
  label: string = '';
  done: boolean = false;
  dueDate: string = '';
  notes: string = '';
  sortOrder: number = 0;
}

export class PreparationBundle {
  categories: PreparationCategory[] = [];
  tasks: PreparationTask[] = [];
}

export function preparationKeys(mode: number): string[] {
  const keys: string[] = [];
  if (mode === 0) { return keys; }
  for (const category of PREPARATION_TEMPLATES) {
    for (const task of category.tasks) { if (mode === 1 || !task.purchase) { keys.push(task.key); } }
  }
  return keys;
}

export function makePreparation(projectId: string, keys: string[]): PreparationBundle {
  const bundle = new PreparationBundle();
  for (const template of PREPARATION_TEMPLATES) {
    const chosen = template.tasks.filter((task: TaskTemplate) => keys.includes(task.key));
    if (chosen.length === 0) { continue; }
    const category = new PreparationCategory(); 
    category.projectId = projectId; 
    category.name = template.name; 
    category.sortOrder = bundle.categories.length;
    bundle.categories.push(category);
    for (let i = 0; i < chosen.length; i++) {
      const task = new PreparationTask(); 
      task.projectId = projectId; 
      task.categoryId = category.id; 
      task.label = chosen[i].label; 
      task.sortOrder = i;
      bundle.tasks.push(task);
    }
  }
  return bundle;
}

export function preparationProgress(projectId: string, tasks: PreparationTask[]): ProjectProgress {
  const items = tasks.filter((task: PreparationTask) => task.projectId === projectId);
  const ready = items.filter((task: PreparationTask) => task.done).length;
  return { ready: ready, total: items.length, percent: items.length === 0 ? 0 : Math.round(ready * 100 / items.length) };
}
