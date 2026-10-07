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

export class TaskTemplate {
  key: string;
  label: string;
  purchase: boolean;
  constructor(key: string, label: string, purchase: boolean = false) { this.key = key; this.label = label; this.purchase = purchase; }
}
export class CategoryTemplate {
  name: string;
  tasks: TaskTemplate[];
  constructor(name: string, tasks: TaskTemplate[]) { this.name = name; this.tasks = tasks; }
}

export const PREPARATION_TEMPLATES: CategoryTemplate[] = [
  new CategoryTemplate('假发', [new TaskTemplate('wig-buy', '购买', true), new TaskTemplate('wig-receive', '收货', true), new TaskTemplate('wig-style', '造型')]),
  new CategoryTemplate('服装', [new TaskTemplate('costume-buy', '购买', true), new TaskTemplate('costume-receive', '收货', true), new TaskTemplate('costume-fit', '试穿')]),
  new CategoryTemplate('鞋子', [new TaskTemplate('shoe-buy', '购买', true), new TaskTemplate('shoe-receive', '收货', true), new TaskTemplate('shoe-fit', '试穿')]),
  new CategoryTemplate('美瞳', [new TaskTemplate('lens-buy', '购买', true), new TaskTemplate('lens-receive', '收货', true)]),
  new CategoryTemplate('化妆', [new TaskTemplate('makeup', '确认妆容')]),
  new CategoryTemplate('拍摄', [new TaskTemplate('photographer', '预约摄影')]),
  new CategoryTemplate('后期', [new TaskTemplate('retoucher', '预约后期')])
];

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
    const category = new PreparationCategory(); category.projectId = projectId; category.name = template.name; category.sortOrder = bundle.categories.length;
    bundle.categories.push(category);
    for (let i = 0; i < chosen.length; i++) {
      const task = new PreparationTask(); task.projectId = projectId; task.categoryId = category.id; task.label = chosen[i].label; task.sortOrder = i;
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
