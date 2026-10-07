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

export type ReleaseType = 'beta' | 'rc' | 'release';

export interface ReleaseNote {
  version: string;
  date: string;
  type: ReleaseType;
  buildNumber: number;
  changes: string[];
}
