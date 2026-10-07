import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Database, WriteTransaction } from '../database/Database';
import { MediaRepository } from '../media/MediaRepository';
import { ManagedMedia } from '../../model/Entities';

interface DemoTable { name: string; rows: relationalStore.ValuesBucket[]; }
interface DemoImage { id: string; key: string; }
interface DemoDataset { version: number; tables: DemoTable[]; media: DemoImage[]; }
const BUSINESS_TABLES: string[] = ['characters', 'variants', 'events', 'projects', 'assets', 'project_assets',
  'checklist_items', 'photos', 'photo_versions', 'diary_entries', 'preparation_categories',
  'preparation_tasks', 'team_members', 'expenses', 'reference_images'];

/** Additive, transactional fixture import. Never replaces personal metadata. */
export class DemoDataRepository {
  private db: Database;
  private context: common.Context;
  private media: MediaRepository;
  constructor(db: Database, context: common.Context, media: MediaRepository) {
    this.db = db; this.context = context; this.media = media;
  }

  private async hasRows(sql: string): Promise<boolean> {
    const rows = await this.db.getStore().querySql(sql);
    try { return rows.rowCount > 0; } finally { rows.close(); }
  }

  /** Automatic import is checked only once; clearing data remains empty on restart. */
  async load(automatic: boolean = false, now: Date = new Date()): Promise<boolean> {
    await this.db.getStore().executeSql('CREATE TABLE IF NOT EXISTS demo_data_state (key TEXT PRIMARY KEY)');
    if (automatic && await this.hasRows("SELECT key FROM demo_data_state WHERE key='automatic-checked-v1'")) { return false; }
    const occupied = await this.hasRows(BUSINESS_TABLES.map((table: string): string => 'SELECT 1 FROM ' + table).join(' UNION ALL ') + ' LIMIT 1');
    if (automatic && occupied) {
      await this.db.getStore().executeSql("INSERT OR IGNORE INTO demo_data_state VALUES ('automatic-checked-v1')");
      return false;
    }
    // IDs also catch demo records recovered through a portable metadata backup.
    const existing = await this.hasRows(BUSINESS_TABLES.filter((table: string): boolean => table !== 'project_assets')
      .map((table: string): string => "SELECT 1 FROM " + table + " WHERE id LIKE 'demo-v1-%'").join(' UNION ALL ') + ' LIMIT 1');
    if (existing) { return false; }
    const bytes = await this.context.resourceManager.getRawFileContent('demo/dataset.json');
    const dataset = JSON.parse(new util.TextDecoder('utf-8', { fatal: true }).decodeToString(bytes)) as DemoDataset;
    if (dataset.version !== 1 || dataset.tables.length !== BUSINESS_TABLES.length ||
      dataset.tables.some((table: DemoTable, index: number): boolean => table.name !== BUSINESS_TABLES[index])) {
      throw new Error('示例数据版本无效');
    }
    const imported: ManagedMedia[] = [];
    const paths = new Map<string, string>();
    try {
      for (const item of dataset.media) {
        const media = await this.media.importBundled(item.key, item.id);
        imported.push(media);
        paths.set('$media/' + item.id + '.jpg', media.localPath);
        paths.set('$media/' + item.id + '-thumb.jpg', media.thumbnailPath);
      }
      await this.db.transaction(async (tx: WriteTransaction): Promise<void> => {
        for (const table of dataset.tables) {
          for (const row of table.rows) {
            for (const column of Object.keys(row)) {
              const value = row[column];
              if (typeof value === 'string') { row[column] = this.resolve(value, paths, now); }
            }
            await tx.insert(table.name, row);
          }
        }
        await tx.execute("INSERT OR IGNORE INTO demo_data_state VALUES ('automatic-checked-v1')");
      });
      return true;
    } catch (error) {
      for (const media of imported) { await this.media.remove(media); }
      throw error as Error;
    }
  }

  private resolve(value: string, paths: Map<string, string>, now: Date): relationalStore.ValueType {
    if (value.startsWith('$media/')) {
      const path = paths.get(value);
      if (!path) { throw new Error('示例图片缺少关联'); }
      return path;
    }
    if (value.startsWith('$day:') || value.startsWith('$time:')) {
      const offset = Number(value.slice(value.indexOf(':') + 1));
      if (!Number.isInteger(offset)) { throw new Error('示例日期无效'); }
      const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset, 12);
      if (value.startsWith('$time:')) { return date.getTime(); }
      return String(date.getFullYear()).padStart(4, '0') + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0');
    }
    return value;
  }
}
