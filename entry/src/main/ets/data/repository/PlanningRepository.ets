import { relationalStore } from '@kit.ArkData';
import { Database, WriteTransaction } from '../database/Database';
import { TeamMember, Expense, ReferenceImage } from '../../model/Planning';
import { requiredName, validDate } from '../../model/Rules';

function text(row: relationalStore.ResultSet, key: string): string { 
  const i = row.getColumnIndex(key); 
  return row.isColumnNull(i) ? '' : row.getString(i); }
function number(row: relationalStore.ResultSet, key: string): number { return row.getLong(row.getColumnIndex(key)); }

export class PlanningRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async team(): Promise<TeamMember[]> {
    const items: TeamMember[] = []; let offset = 0;
    while (true) {
      const rows = await this.db.getStore().querySql('SELECT * FROM team_members ORDER BY role,name,id LIMIT 500 OFFSET ?', [offset]); 
    let count = 0;
      try { 
      while (rows.goToNextRow()) { 
        const m = new TeamMember(); 
        m.id = text(rows, 'id'); 
        m.projectId = text(rows, 'project_id'); 
        m.role = text(rows, 'role'); 
        m.name = text(rows, 'name'); 
        m.notes = text(rows, 'notes'); 
        items.push(m); 
        count++; 
      } } finally { 
      rows.close(); }
      if (count < 500) { break; } offset += count;
    } return items;
  }
  async expenses(): Promise<Expense[]> {
    const items: Expense[] = []; let offset = 0;
    while (true) {
      const rows = await this.db.getStore().querySql('SELECT * FROM expenses ORDER BY date DESC,created_at DESC,id LIMIT 500 OFFSET ?', [offset]); 
    let count = 0;
      try { 
      while (rows.goToNextRow()) { 
        const e = new Expense(); 
        e.id = text(rows, 'id'); 
        e.projectId = text(rows, 'project_id'); 
        e.name = text(rows, 'name'); 
        e.category = text(rows, 'category'); 
        e.amountCents = number(rows, 'amount_cents'); 
        e.date = text(rows, 'date'); 
        e.notes = text(rows, 'notes'); 
        e.createdAt = number(rows, 'created_at'); 
        items.push(e); 
        count++; 
      } } finally { 
      rows.close(); }
      if (count < 500) { break; } offset += count;
    } return items;
  }
  async references(): Promise<ReferenceImage[]> {
    const items: ReferenceImage[] = []; let offset = 0;
    while (true) {
      const rows = await this.db.getStore().querySql('SELECT * FROM reference_images ORDER BY created_at DESC,id LIMIT 500 OFFSET ?', [offset]); 
    let count = 0;
      try { 
      while (rows.goToNextRow()) { 
        const r = new ReferenceImage(); 
        r.id = text(rows, 'id'); 
        r.projectId = text(rows, 'project_id'); 
        r.characterId = text(rows, 'character_id'); 
        r.sourceUri = text(rows, 'source_uri'); 
        r.localPath = text(rows, 'local_path'); 
        r.thumbnailPath = text(rows, 'thumbnail_path'); 
        r.caption = text(rows, 'caption'); 
        r.createdAt = number(rows, 'created_at'); 
        items.push(r); 
        count++; 
      } } finally { 
      rows.close(); }
      if (count < 500) { break; } offset += count;
    } return items;
  }
  async saveTeam(m: TeamMember): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO team_members(id,project_id,role,name,notes) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET role=excluded.role,name=excluded.name,notes=excluded.notes', [m.id, m.projectId, requiredName(m.role), requiredName(m.name), m.notes]);
  }
  async saveExpense(e: Expense): Promise<void> {
    if (!validDate(e.date)) { throw new Error('花费日期格式为 YYYY-MM-DD'); }
    if (!Number.isSafeInteger(e.amountCents) || e.amountCents < 0) { throw new Error('花费金额无效'); }
    await this.db.getStore().executeSql('INSERT INTO expenses(id,project_id,name,category,amount_cents,date,notes,created_at) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,category=excluded.category,amount_cents=excluded.amount_cents,date=excluded.date,notes=excluded.notes', [e.id, e.projectId, requiredName(e.name), requiredName(e.category), e.amountCents, e.date, e.notes, e.createdAt]);
  }
  async saveReference(r: ReferenceImage): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO reference_images(id,project_id,character_id,source_uri,local_path,thumbnail_path,caption,created_at) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET local_path=excluded.local_path,thumbnail_path=excluded.thumbnail_path,caption=excluded.caption', [r.id, r.projectId || null, r.characterId || null, r.sourceUri, r.localPath, r.thumbnailPath, r.caption, r.createdAt]);
  }
  async setReferenceCover(r: ReferenceImage, characterId: string): Promise<void> {
    await this.db.getStore().executeSql('UPDATE characters SET cover=?,updated_at=? WHERE id=?', [r.thumbnailPath, Date.now(), characterId]);
  }
  async removeTeam(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM team_members WHERE id=?', [id]); }
  async removeExpense(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM expenses WHERE id=?', [id]); }
  async removeReference(r: ReferenceImage): Promise<void> {
    await this.db.transaction(async (tx: WriteTransaction) => {
      await tx.execute("UPDATE characters SET cover='' WHERE cover=?", [r.thumbnailPath]);
      await tx.execute('DELETE FROM reference_images WHERE id=?', [r.id]);
    });
  }
}
