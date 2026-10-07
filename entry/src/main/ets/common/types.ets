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

export interface ReleaseNote { version: string; date: string; changes: string[]; }
