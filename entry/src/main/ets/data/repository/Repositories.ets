import { relationalStore } from '@kit.ArkData';
import { Database, WriteTransaction } from '../database/Database';
import { Character, CharacterVariant, CosProject, Asset, CosEvent, ChecklistItem, PhotoAsset, DiaryEntry, ProjectAsset, ProjectStatus, AssetStatus, AssetType, PhotoStatus, PhotoVersion } from '../../model/Entities';

function str(row: relationalStore.ResultSet, key: string): string {
  const i = row.getColumnIndex(key);
  return row.isColumnNull(i) ? '' : row.getString(i);
}
function num(row: relationalStore.ResultSet, key: string): number { return row.getLong(row.getColumnIndex(key)); }

export class CharacterRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<Character[]> {
    const result: Character[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM characters ORDER BY created_at DESC, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new Character();
        item.id = str(rows, 'id');
        item.name = str(rows, 'name');
        item.workName = str(rows, 'work_name');
        item.description = str(rows, 'description');
        item.cover = str(rows, 'cover');
        item.favorite = num(rows, 'favorite') === 1;
        item.status = str(rows, 'status');
        item.createdAt = num(rows, 'created_at');
        item.updatedAt = num(rows, 'updated_at');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: Character): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO characters (id, name, work_name, description, cover, favorite, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, work_name=excluded.work_name, description=excluded.description, cover=excluded.cover, favorite=excluded.favorite, status=excluded.status, created_at=excluded.created_at, updated_at=excluded.updated_at', [item.id, item.name, item.workName, item.description, item.cover, item.favorite ? 1 : 0, item.status, item.createdAt, item.updatedAt]);
  }
  async remove(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM characters WHERE id=?', [id]); }
}

export class CharacterVariantRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<CharacterVariant[]> {
    const result: CharacterVariant[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM variants ORDER BY name, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new CharacterVariant();
        item.id = str(rows, 'id');
        item.characterId = str(rows, 'character_id');
        item.name = str(rows, 'name');
        item.notes = str(rows, 'notes');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: CharacterVariant): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO variants (id, character_id, name, notes) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET character_id=excluded.character_id, name=excluded.name, notes=excluded.notes', [item.id, item.characterId, item.name, item.notes]);
  }
  async remove(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM variants WHERE id=?', [id]); }
}

export class CosProjectRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<CosProject[]> {
    const result: CosProject[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM projects ORDER BY created_at DESC, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new CosProject();
        item.id = str(rows, 'id');
        item.characterId = str(rows, 'character_id');
        item.variantId = str(rows, 'variant_id');
        item.eventId = str(rows, 'event_id');
        item.name = str(rows, 'name');
        item.status = str(rows, 'status') as ProjectStatus;
        item.notes = str(rows, 'notes');
        item.targetDate = str(rows, 'target_date');
        item.budgetCents = num(rows, 'budget_cents');
        item.createdAt = num(rows, 'created_at');
        item.updatedAt = num(rows, 'updated_at');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: CosProject, logText: string = '', character?: Character): Promise<void> {
    await this.db.transaction(async (tx: WriteTransaction) => {
    if (character) { await tx.execute('INSERT INTO characters (id,name,work_name,description,cover,favorite,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?)', [character.id, character.name, character.workName, character.description, character.cover, character.favorite ? 1 : 0, character.status, character.createdAt, character.updatedAt]); }
    await tx.execute('INSERT INTO projects (id, character_id, variant_id, event_id, name, status, notes, target_date, budget_cents, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET character_id=excluded.character_id, variant_id=excluded.variant_id, event_id=excluded.event_id, name=excluded.name, status=excluded.status, notes=excluded.notes, target_date=excluded.target_date, budget_cents=excluded.budget_cents, created_at=excluded.created_at, updated_at=excluded.updated_at', [item.id, item.characterId, item.variantId || null, item.eventId || null, item.name, item.status, item.notes, item.targetDate, item.budgetCents, item.createdAt, item.updatedAt]);
      if (logText) { const entry = new DiaryEntry(); await tx.execute('INSERT INTO diary_entries VALUES (?,?,?,?)', [entry.id, item.id, logText, entry.createdAt]); }
    });
  }

  async remove(id: string): Promise<void> { await this.db.transaction(async (tx: WriteTransaction) => { await tx.execute("UPDATE characters SET cover='' WHERE cover IN (SELECT thumbnail_path FROM photos WHERE project_id=?)", [id]); await tx.execute('DELETE FROM projects WHERE id=?', [id]); }); }
}

export class AssetRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<Asset[]> {
    const result: Asset[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM assets ORDER BY created_at DESC, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new Asset();
        item.id = str(rows, 'id');
        item.name = str(rows, 'name');
        item.type = str(rows, 'type') as AssetType;
        item.status = str(rows, 'status') as AssetStatus;
        item.location = str(rows, 'location');
        item.brand = str(rows, 'brand');
        item.size = str(rows, 'size');
        item.priceCents = num(rows, 'price_cents');
        item.purchaseUrl = str(rows, 'purchase_url');
        item.notes = str(rows, 'notes');
        item.createdAt = num(rows, 'created_at');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: Asset, projectId: string = ''): Promise<void> {
    await this.db.transaction(async (tx: WriteTransaction) => {
    await tx.execute('INSERT INTO assets (id, name, type, status, location, brand, size, price_cents, purchase_url, notes, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, type=excluded.type, status=excluded.status, location=excluded.location, brand=excluded.brand, size=excluded.size, price_cents=excluded.price_cents, purchase_url=excluded.purchase_url, notes=excluded.notes, created_at=excluded.created_at', [item.id, item.name, item.type, item.status, item.location, item.brand, item.size, item.priceCents, item.purchaseUrl, item.notes, item.createdAt]);
      if (projectId) {
        await tx.execute('INSERT INTO project_assets VALUES (?,?)', [projectId, item.id]);
        const checklist = new ChecklistItem();
        await tx.execute('INSERT INTO checklist_items(id,project_id,asset_id,label,done,sort_order) VALUES (?,?,?,?,0,0)', [checklist.id, projectId, item.id, item.name]);
      }
    });
  }
  async remove(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM assets WHERE id=?', [id]); }
}

export class CosEventRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<CosEvent[]> {
    const result: CosEvent[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM events ORDER BY created_at DESC, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new CosEvent();
        item.id = str(rows, 'id');
        item.name = str(rows, 'name');
        item.date = str(rows, 'date');
        item.city = str(rows, 'city');
        item.venue = str(rows, 'venue');
        item.url = str(rows, 'url');
        item.status = str(rows, 'status');
        item.ticketPurchased = num(rows, 'ticket_purchased') === 1;
        item.notes = str(rows, 'notes');
        item.createdAt = num(rows, 'created_at');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: CosEvent): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO events (id, name, date, city, venue, url, status, ticket_purchased, notes, created_at) VALUES (?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, date=excluded.date, city=excluded.city, venue=excluded.venue, url=excluded.url, status=excluded.status, ticket_purchased=excluded.ticket_purchased, notes=excluded.notes, created_at=excluded.created_at', [item.id, item.name, item.date, item.city, item.venue, item.url, item.status, item.ticketPurchased ? 1 : 0, item.notes, item.createdAt]);
  }
  async remove(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM events WHERE id=?', [id]); }
}

export class ChecklistItemRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<ChecklistItem[]> {
    const result: ChecklistItem[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM checklist_items ORDER BY sort_order, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new ChecklistItem();
        item.id = str(rows, 'id');
        item.projectId = str(rows, 'project_id');
        item.assetId = str(rows, 'asset_id');
        item.label = str(rows, 'label');
        item.done = num(rows, 'done') === 1;
        item.sortOrder = num(rows, 'sort_order');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: ChecklistItem): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO checklist_items (id, project_id, asset_id, label, done, sort_order) VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET project_id=excluded.project_id, asset_id=excluded.asset_id, label=excluded.label, done=excluded.done, sort_order=excluded.sort_order', [item.id, item.projectId, item.assetId || null, item.label, item.done ? 1 : 0, item.sortOrder]);
  }
  async remove(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM checklist_items WHERE id=?', [id]); }
}

export class PhotoAssetRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<PhotoAsset[]> {
    const result: PhotoAsset[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM photos ORDER BY created_at DESC, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new PhotoAsset();
        item.id = str(rows, 'id');
        item.projectId = str(rows, 'project_id');
        item.sourceUri = str(rows, 'source_uri');
        item.localPath = str(rows, 'local_path');
        item.thumbnailPath = str(rows, 'thumbnail_path');
        item.status = str(rows, 'status') as PhotoStatus;
        item.caption = str(rows, 'caption');
        item.createdAt = num(rows, 'created_at');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async save(item: PhotoAsset): Promise<void> {
    await this.db.getStore().executeSql('INSERT INTO photos (id, project_id, source_uri, local_path, thumbnail_path, status, caption, created_at) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET project_id=excluded.project_id, source_uri=excluded.source_uri, local_path=excluded.local_path, thumbnail_path=excluded.thumbnail_path, status=excluded.status, caption=excluded.caption, created_at=excluded.created_at', [item.id, item.projectId, item.sourceUri, item.localPath, item.thumbnailPath, item.status, item.caption, item.createdAt]);
  }
  async setStatuses(ids: string[], status: PhotoStatus): Promise<void> {
    if (ids.length === 0) { throw new Error('请先选择照片'); }
    await this.db.transaction(async (tx: WriteTransaction) => {
      for (const id of ids) {
        const rows = await this.db.getStore().querySql('SELECT id FROM photos WHERE id=?', [id]);
        try { if (rows.rowCount !== 1) { throw new Error('照片记录已变化，请重新选择'); } } finally { rows.close(); }
        await tx.execute('UPDATE photos SET status=? WHERE id=?', [status, id]);
      }
    });
  }
  async remove(id: string): Promise<void> { await this.db.transaction(async (tx: WriteTransaction) => { await tx.execute("UPDATE characters SET cover='' WHERE cover IN (SELECT thumbnail_path FROM photos WHERE id=?)", [id]); await tx.execute('DELETE FROM photos WHERE id=?', [id]); }); }
}

export class DiaryEntryRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async list(): Promise<DiaryEntry[]> {
    const result: DiaryEntry[] = [];
    let offset = 0;
    while (true) {
      let count = 0;
      const rows = await this.db.getStore().querySql('SELECT * FROM diary_entries ORDER BY created_at DESC, id LIMIT ? OFFSET ?', [500, offset]);
      try {
        while (rows.goToNextRow()) {
          count++;
        const item = new DiaryEntry();
        item.id = str(rows, 'id');
        item.projectId = str(rows, 'project_id');
        item.text = str(rows, 'text');
        item.createdAt = num(rows, 'created_at');
        result.push(item);
      }
      } finally { rows.close(); }
      if (count < 500) { break; }
      offset += count;
    }
    return result;
  }
  async remove(id: string): Promise<void> { await this.db.getStore().executeSql('DELETE FROM diary_entries WHERE id=?', [id]); }
}

export class RelationRepository {
  private db: Database;
  constructor(db: Database) { this.db = db; }
  async links(): Promise<ProjectAsset[]> {
    const result: ProjectAsset[] = [];
    const rows = await this.db.getStore().querySql('SELECT * FROM project_assets');
    try { while (rows.goToNextRow()) { const item = new ProjectAsset(); item.projectId = str(rows, 'project_id'); item.assetId = str(rows, 'asset_id'); result.push(item); } } finally { rows.close(); }
    return result;
  }
  async link(projectId: string, asset: Asset): Promise<void> {
    await this.db.transaction(async (tx: WriteTransaction) => {
      await tx.execute('INSERT OR IGNORE INTO project_assets VALUES (?,?)', [projectId, asset.id]);
      // The partial unique index makes repeated automatic generation idempotent.
      const item = new ChecklistItem();
      await tx.execute('INSERT OR IGNORE INTO checklist_items(id,project_id,asset_id,label,done,sort_order) VALUES (?,?,?,?,0,0)', [item.id, projectId, asset.id, asset.name]);
    });
  }
  async unlink(projectId: string, assetId: string): Promise<void> {
    await this.db.transaction(async (tx: WriteTransaction) => {
      await tx.execute('DELETE FROM project_assets WHERE project_id=? AND asset_id=?', [projectId, assetId]);
      await tx.execute('DELETE FROM checklist_items WHERE project_id=? AND asset_id=?', [projectId, assetId]);
    });
  }
  async addPhoto(photo: PhotoAsset): Promise<void> {
    const version = new PhotoVersion(); version.photoId = photo.id; version.renderedPath = photo.localPath;
    await this.db.transaction(async (tx: WriteTransaction) => {
      await tx.execute('INSERT INTO photos VALUES (?,?,?,?,?,?,?,?)', [photo.id, photo.projectId, photo.sourceUri, photo.localPath, photo.thumbnailPath, photo.status, photo.caption, photo.createdAt]);
      await tx.execute('INSERT INTO photo_versions VALUES (?,?,?,?,?,?)', [version.id, version.photoId, version.name, version.recipe, version.renderedPath, version.createdAt]);
    });
  }
  async log(projectId: string, text: string): Promise<void> {
    const entry = new DiaryEntry();
    await this.db.getStore().executeSql('INSERT INTO diary_entries VALUES (?,?,?,?)', [entry.id, projectId || null, text, entry.createdAt]);
  }
  async clear(): Promise<void> {
    await this.db.transaction(async (tx: WriteTransaction) => {
      for (const table of ['projects', 'variants', 'characters', 'assets', 'events', 'diary_entries']) { await tx.execute('DELETE FROM ' + table); }
    });
  }
}
