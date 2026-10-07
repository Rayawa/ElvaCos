import { CosEvent } from '../../model/Entities';
import { checkSchedule } from '../../model/Schedule';
import { relationalStore } from '@kit.ArkData';
import { validDate, requiredName, safeUrl } from '../../model/Rules';
import { Database, WriteTransaction } from '../database/Database';

class TableSpec { public name: string;
  public columns: string[];
  constructor(name: string, columns: string[]) { this.name = name; this.columns = columns; } }
const LEGACY_EVENT_COLUMNS: string[] = ['id','name','date','city','venue','url','status','ticket_purchased','notes','created_at'];
const TABLES: TableSpec[] = [
  new TableSpec('characters', ['id','name','work_name','description','cover','favorite','status','created_at','updated_at']),
  new TableSpec('variants', ['id','character_id','name','notes']),
  new TableSpec('events', LEGACY_EVENT_COLUMNS.concat(['date_mode','end_date','time_mode','start_time','end_time','event_type','reminder_id','reminder_minutes'])),
  new TableSpec('projects', ['id','character_id','variant_id','event_id','name','status','notes','target_date','budget_cents','created_at','updated_at']),
  new TableSpec('assets', ['id','name','type','status','location','brand','size','price_cents','purchase_url','notes','created_at']),
  new TableSpec('project_assets', ['project_id','asset_id']),
  new TableSpec('checklist_items', ['id','project_id','asset_id','label','done','sort_order']),
  new TableSpec('photos', ['id','project_id','source_uri','local_path','thumbnail_path','status','caption','created_at']),
  new TableSpec('photo_versions', ['id','photo_id','name','recipe','rendered_path','created_at']),
  new TableSpec('diary_entries', ['id','project_id','text','created_at']),
  new TableSpec('preparation_categories', ['id','project_id','name','sort_order']),
  new TableSpec('preparation_tasks', ['id','project_id','category_id','label','done','due_date','notes','sort_order']),
  new TableSpec('team_members', ['id','project_id','role','name','notes']),
  new TableSpec('expenses', ['id','project_id','name','category','amount_cents','date','notes','created_at']),
  new TableSpec('reference_images', ['id','project_id','character_id','source_uri','local_path','thumbnail_path','caption','created_at'])
];
interface BackupTable { name: string; rows: relationalStore.ValuesBucket[]; }
interface BackupDocument { format: string; version: number; exportedAt: number; tables: BackupTable[]; }

// Versioned portable metadata and RDB transactions stay in the data layer.
export class MetadataBackupRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async exportMetadata(): Promise<string> {
    const tables: BackupTable[] = [];
    for (const spec of TABLES) {
      const rows: relationalStore.ValuesBucket[] = [];
      const result = await this.db.getStore().querySql('SELECT * FROM ' + spec.name);
      try {
        while (result.goToNextRow()) {
          const row: relationalStore.ValuesBucket = {};
          spec.columns.forEach((col: string) => { row[col] = result.getValue(result.getColumnIndex(col)); });
          rows.push(row);
        }
      } finally { result.close(); }
      tables.push({ name: spec.name, rows: rows });
    }
    const doc: BackupDocument = { format: 'cos-personal-metadata', version: 3, exportedAt: Date.now(), tables: tables };
    const output = JSON.stringify(doc);
    if (output.length > 3 * 1024 * 1024) { throw new Error('元数据过大，请使用系统完整备份'); }
    return output;
  }
  async restoreMetadata(input: string): Promise<void> {
    if (input.length > 10 * 1024 * 1024) { throw new Error('元数据过大'); }
    const doc = JSON.parse(input) as BackupDocument;
    if (doc.format !== 'cos-personal-metadata' || ![1, 2, 3].includes(doc.version) || !Array.isArray(doc.tables) || doc.tables.length !== (doc.version === 1 ? 10 : doc.version === 2 ? 12 : TABLES.length)) { throw new Error('备份格式或版本不受支持'); }
    const allowedCovers: string[] = [];
    const existingMedia = new Map<string, relationalStore.ValuesBucket>();
    const existingRows = await this.db.getStore().querySql('SELECT project_id,source_uri,local_path,thumbnail_path FROM photos');
    try { while (existingRows.goToNextRow()) { existingMedia.set(JSON.stringify([existingRows.getString(0), existingRows.getString(1)]), { local_path: existingRows.getString(2), thumbnail_path: existingRows.getString(3) }); } } finally { existingRows.close(); }
    const existingReferences = new Map<string, relationalStore.ValuesBucket>();
    const referenceRows = await this.db.getStore().querySql('SELECT project_id,character_id,source_uri,local_path,thumbnail_path FROM reference_images');
    try { while (referenceRows.goToNextRow()) {
      const project = referenceRows.isColumnNull(0) ? '' : referenceRows.getString(0); const character = referenceRows.isColumnNull(1) ? '' : referenceRows.getString(1);
      existingReferences.set(JSON.stringify([project, character, referenceRows.getString(2)]), { local_path: referenceRows.getString(3), thumbnail_path: referenceRows.getString(4) });
    } } finally { referenceRows.close(); }
    // Only media records retained by this backup may keep a character cover.
    for (const table of doc.tables) {
      if (!table || !Array.isArray(table.rows)) { throw new Error('备份表结构无效'); }
      if (table.name !== 'photos' && table.name !== 'reference_images') { continue; }
      for (const row of table.rows) {
        const existing = table.name === 'photos' ? existingMedia.get(JSON.stringify([row['project_id'], row['source_uri']])) : existingReferences.get(JSON.stringify([row['project_id'] || '', row['character_id'] || '', row['source_uri']]));
        if (existing && typeof existing['thumbnail_path'] === 'string') { allowedCovers.push(String(existing['thumbnail_path'])); }
      }
    }
    for (let i = 0; i < doc.tables.length; i++) {
      const spec = doc.version < 3 && TABLES[i].name === 'events' ? new TableSpec('events', LEGACY_EVENT_COLUMNS) : TABLES[i]; const table = doc.tables[i];
      if (!table || table.name !== spec.name || !Array.isArray(table.rows) || table.rows.length > 50000) { throw new Error('备份表结构无效'); }
      for (const row of table.rows) {
        if (Object.keys(row).length !== spec.columns.length) { throw new Error('备份列不完整'); }
        for (const col of spec.columns) {
          const value = row[col];
          if (value !== null && typeof value !== 'string' && typeof value !== 'number') { throw new Error('备份包含无效字段'); }
          const numbers = ['favorite','created_at','updated_at','ticket_purchased','budget_cents','price_cents','done','sort_order','amount_cents','reminder_id','reminder_minutes'];
          if (numbers.includes(col) && (typeof value !== 'number' || !Number.isSafeInteger(value) || value < (col === 'reminder_id' || col === 'reminder_minutes' ? -1 : 0))) { throw new Error('备份包含无效数字'); }
          if (!numbers.includes(col) && value !== null && typeof value !== 'string') { throw new Error('备份包含无效文本'); }
          if (value === null && !['variant_id','event_id','asset_id','project_id','character_id'].includes(col)) { throw new Error('备份包含缺失字段'); }
          if (typeof value === 'string' && ['name', 'label', 'role', 'category', 'event_type'].includes(col)) { requiredName(value); }
          if (typeof value === 'string' && (col === 'url' || col === 'purchase_url')) { safeUrl(value); }
          if (typeof value === 'string' && (col === 'date' || col === 'target_date' || col === 'due_date' || col === 'end_date') && (value !== '' || (col === 'date' && !(spec.name === 'events' && row['date_mode'] === 'pending'))) && !validDate(value)) { throw new Error('备份包含无效日期'); }
          if (typeof value === 'string' && value.length > 20000) { throw new Error('备份字段过长'); }
        }
        if (spec.name === 'events') {
          const event = new CosEvent(); event.date = String(row['date']); event.dateMode = doc.version < 3 ? 'single' : String(row['date_mode']); event.endDate = doc.version < 3 ? '' : String(row['end_date']); event.timeMode = doc.version < 3 ? 'none' : String(row['time_mode']); event.startTime = doc.version < 3 ? '' : String(row['start_time']); event.endTime = doc.version < 3 ? '' : String(row['end_time']); event.eventType = doc.version < 3 ? '漫展' : String(row['event_type']); event.reminderMinutes = doc.version < 3 ? -1 : Number(row['reminder_minutes']);
          checkSchedule(event);
          // System reminder IDs belong to a device, never to portable metadata.
          row['reminder_id'] = -1; row['reminder_minutes'] = -1;
        }
        // Never accept foreign filesystem paths from an imported document.
        if (spec.name === 'photos') { const existing = existingMedia.get(JSON.stringify([row['project_id'], row['source_uri']])); row['local_path'] = existing ? existing['local_path'] : ''; row['thumbnail_path'] = existing ? existing['thumbnail_path'] : ''; }
        if (spec.name === 'reference_images') {
          const existing = existingReferences.get(JSON.stringify([row['project_id'] || '', row['character_id'] || '', row['source_uri']]));
          row['local_path'] = existing ? existing['local_path'] : ''; row['thumbnail_path'] = existing ? existing['thumbnail_path'] : '';
        }
        if (spec.name === 'photo_versions') { row['rendered_path'] = ''; }
        if (spec.name === 'characters') { row['cover'] = allowedCovers.includes(String(row['cover'])) ? row['cover'] : ''; }
      }
    }
    await this.db.transaction(async (tx: WriteTransaction) => {
      for (let i = TABLES.length - 1; i >= 0; i--) { await tx.execute('DELETE FROM ' + TABLES[i].name); }
      for (let i = 0; i < doc.tables.length; i++) {
        for (const row of doc.tables[i].rows) { await tx.insert(TABLES[i].name, row); }
      }
    });
  }
}
