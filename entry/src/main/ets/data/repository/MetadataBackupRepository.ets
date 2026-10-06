import { relationalStore } from '@kit.ArkData';
import { validDate, requiredName, safeUrl } from '../../model/Rules';
import { Database, WriteTransaction } from '../database/Database';

class TableSpec { public name: string;
  public columns: string[];
  constructor(name: string, columns: string[]) { this.name = name; this.columns = columns; } }
const TABLES: TableSpec[] = [
  new TableSpec('characters', ['id','name','work_name','description','cover','favorite','status','created_at','updated_at']),
  new TableSpec('variants', ['id','character_id','name','notes']),
  new TableSpec('events', ['id','name','date','city','venue','url','status','ticket_purchased','notes','created_at']),
  new TableSpec('projects', ['id','character_id','variant_id','event_id','name','status','notes','target_date','budget_cents','created_at','updated_at']),
  new TableSpec('assets', ['id','name','type','status','location','brand','size','price_cents','purchase_url','notes','created_at']),
  new TableSpec('project_assets', ['project_id','asset_id']),
  new TableSpec('checklist_items', ['id','project_id','asset_id','label','done','sort_order']),
  new TableSpec('photos', ['id','project_id','source_uri','local_path','thumbnail_path','status','caption','created_at']),
  new TableSpec('photo_versions', ['id','photo_id','name','recipe','rendered_path','created_at']),
  new TableSpec('diary_entries', ['id','project_id','text','created_at'])
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
    const doc: BackupDocument = { format: 'cos-personal-metadata', version: 1, exportedAt: Date.now(), tables: tables };
    const output = JSON.stringify(doc);
    if (output.length > 3 * 1024 * 1024) { throw new Error('元数据过大，请使用系统完整备份'); }
    return output;
  }
  async restoreMetadata(input: string): Promise<void> {
    if (input.length > 10 * 1024 * 1024) { throw new Error('元数据过大'); }
    const doc = JSON.parse(input) as BackupDocument;
    if (doc.format !== 'cos-personal-metadata' || doc.version !== 1 || !Array.isArray(doc.tables) || doc.tables.length !== TABLES.length) { throw new Error('备份格式或版本不受支持'); }
    const allowedCovers: string[] = [];
    const existingMedia = new Map<string, relationalStore.ValuesBucket>();
    const existingRows = await this.db.getStore().querySql('SELECT project_id,source_uri,local_path,thumbnail_path FROM photos');
    try { while (existingRows.goToNextRow()) { allowedCovers.push(existingRows.getString(3)); existingMedia.set(existingRows.getString(0) + ':' + existingRows.getString(1), { local_path: existingRows.getString(2), thumbnail_path: existingRows.getString(3) }); } } finally { existingRows.close(); }
    for (let i = 0; i < TABLES.length; i++) {
      const spec = TABLES[i]; const table = doc.tables[i];
      if (!table || table.name !== spec.name || !Array.isArray(table.rows) || table.rows.length > 50000) { throw new Error('备份表结构无效'); }
      for (const row of table.rows) {
        if (Object.keys(row).length !== spec.columns.length) { throw new Error('备份列不完整'); }
        for (const col of spec.columns) {
          const value = row[col];
          if (value !== null && typeof value !== 'string' && typeof value !== 'number') { throw new Error('备份包含无效字段'); }
          const numbers = ['favorite','created_at','updated_at','ticket_purchased','budget_cents','price_cents','done','sort_order'];
          if (numbers.includes(col) && (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0)) { throw new Error('备份包含无效数字'); }
          if (!numbers.includes(col) && value !== null && typeof value !== 'string') { throw new Error('备份包含无效文本'); }
          if (value === null && !['variant_id','event_id','asset_id','project_id'].includes(col)) { throw new Error('备份包含缺失字段'); }
          if (typeof value === 'string' && (col === 'name' || col === 'label')) { requiredName(value); }
          if (typeof value === 'string' && (col === 'url' || col === 'purchase_url')) { safeUrl(value); }
          if (typeof value === 'string' && (col === 'date' || col === 'target_date') && (col === 'date' || value !== '') && !validDate(value)) { throw new Error('备份包含无效日期'); }
          if (typeof value === 'string' && value.length > 20000) { throw new Error('备份字段过长'); }
        }
        // Never accept foreign filesystem paths from an imported document.
        if (spec.name === 'photos') { const existing = existingMedia.get(String(row['project_id']) + ':' + String(row['source_uri'])); row['local_path'] = existing ? existing['local_path'] : ''; row['thumbnail_path'] = existing ? existing['thumbnail_path'] : ''; }
        if (spec.name === 'photo_versions') { row['rendered_path'] = ''; }
        if (spec.name === 'characters') { row['cover'] = allowedCovers.includes(String(row['cover'])) ? row['cover'] : ''; }
      }
    }
    await this.db.transaction(async (tx: WriteTransaction) => {
      for (let i = TABLES.length - 1; i >= 0; i--) { await tx.execute('DELETE FROM ' + TABLES[i].name); }
      for (let i = 0; i < TABLES.length; i++) {
        for (const row of doc.tables[i].rows) { await tx.insert(TABLES[i].name, row); }
      }
    });
  }
}
