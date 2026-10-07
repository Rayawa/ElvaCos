import { relationalStore } from '@kit.ArkData';
import { Database, WriteTransaction } from '../database/Database';
import { PreparationCategory, PreparationTask, PreparationBundle } from '../../model/Preparation';
import { requiredName, validDate } from '../../model/Rules';

function text(row: relationalStore.ResultSet, key: string): string { return row.getString(row.getColumnIndex(key)); }
function number(row: relationalStore.ResultSet, key: string): number { return row.getLong(row.getColumnIndex(key)); }

// Used inside the same transaction as plan creation. No independent commit.
export async function insertPreparation(tx: WriteTransaction, bundle: PreparationBundle): Promise<void> {
  for (const category of bundle.categories) {
    await tx.execute('INSERT INTO preparation_categories(id,project_id,name,sort_order) VALUES (?,?,?,?)', [category.id, category.projectId, requiredName(category.name), category.sortOrder]);
  }
  for (const task of bundle.tasks) {
    await tx.execute('INSERT INTO preparation_tasks(id,project_id,category_id,label,done,due_date,notes,sort_order) VALUES (?,?,?,?,?,?,?,?)', [task.id, task.projectId, task.categoryId, requiredName(task.label), task.done ? 1 : 0, task.dueDate, task.notes, task.sortOrder]);
  }
}

export class PreparationRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async categories(): Promise<PreparationCategory[]> {
    const items: PreparationCategory[] = [];
    let offset = 0;
    while (true) {
      const rows = await this.db.getStore().querySql('SELECT * FROM preparation_categories ORDER BY sort_order,id LIMIT 500 OFFSET ?', [offset]);
      let count = 0;
      try {
        while (rows.goToNextRow()) {
          const item = new PreparationCategory();
          item.id = text(rows, 'id');
          item.projectId = text(rows, 'project_id');
          item.name = text(rows, 'name');
          item.sortOrder = number(rows, 'sort_order');
          items.push(item);
          count++;
        }
      } finally { rows.close(); }
      if (count < 500) { break; } offset += count;
    }
    return items;
  }
  async tasks(): Promise<PreparationTask[]> {
    const items: PreparationTask[] = [];
    let offset = 0;
    while (true) {
      const rows = await this.db.getStore().querySql('SELECT * FROM preparation_tasks ORDER BY sort_order,id LIMIT 500 OFFSET ?', [offset]);
      let count = 0;
      try {
        while (rows.goToNextRow()) {
          const item = new PreparationTask();
          item.id = text(rows, 'id');
          item.projectId = text(rows, 'project_id');
          item.categoryId = text(rows, 'category_id');
          item.label = text(rows, 'label');
          item.done = number(rows, 'done') === 1;
          item.dueDate = text(rows, 'due_date');
          item.notes = text(rows, 'notes');
          item.sortOrder = number(rows, 'sort_order');
          items.push(item);
          count++;
        }
      } finally { rows.close(); }
      if (count < 500) { break; } offset += count;
    }
    return items;
  }
  async saveCategory(item: PreparationCategory): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO preparation_categories(id,project_id,name,sort_order) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name', [item.id, item.projectId, requiredName(item.name), item.sortOrder]);
  }
  async saveTask(item: PreparationTask): Promise<void> {
    if (item.dueDate && !validDate(item.dueDate)) { throw new Error('任务日期格式为 YYYY-MM-DD'); }
    await this.db.getStore().executeSql('INSERT INTO preparation_tasks(id,project_id,category_id,label,done,due_date,notes,sort_order) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET category_id=excluded.category_id,label=excluded.label,done=excluded.done,due_date=excluded.due_date,notes=excluded.notes,sort_order=excluded.sort_order', [item.id, item.projectId, item.categoryId, requiredName(item.label), item.done ? 1 : 0, item.dueDate, item.notes, item.sortOrder]);
  }
  async setDone(id: string, done: boolean): Promise<void> {
    const changed = await this.db.getStore().update({ done: done ? 1 : 0 }, new relationalStore.RdbPredicates('preparation_tasks').equalTo('id', id));
    if (changed !== 1) { throw new Error('任务已不存在，请刷新后重试'); }
  }
  async addTemplate(bundle: PreparationBundle): Promise<void> {
    // Add only missing names/labels; never replace custom tasks or reset completion.
    await this.db.transaction(async (tx: WriteTransaction) => {
      for (const category of bundle.categories) {
        await tx.execute('INSERT OR IGNORE INTO preparation_categories(id,project_id,name,sort_order) VALUES (?,?,?,?)', [category.id, category.projectId, category.name, category.sortOrder]);
        for (const task of bundle.tasks.filter((t: PreparationTask) => t.categoryId === category.id)) {
          await tx.execute('INSERT INTO preparation_tasks(id,project_id,category_id,label,done,due_date,notes,sort_order) SELECT ?,?,id,?,0,?,?,? FROM preparation_categories WHERE project_id=? AND name=? AND NOT EXISTS (SELECT 1 FROM preparation_tasks WHERE category_id=preparation_categories.id AND label=?)', [task.id, task.projectId, task.label, task.dueDate, task.notes, task.sortOrder, category.projectId, category.name, task.label]);
        }
      }
    });
  }
  async removeTask(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM preparation_tasks WHERE id=?', [id]); }
  async removeCategory(id: string): Promise<void> {
    await this.db.getStore().executeSql('DELETE FROM preparation_categories WHERE id=?', [id]);
  }
}
