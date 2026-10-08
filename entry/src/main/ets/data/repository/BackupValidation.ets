import { relationalStore } from '@kit.ArkData';

export interface BackupTable { name: string; rows: relationalStore.ValuesBucket[]; }

/** Validate relationships and SQL constraints before offering replacement. */
export function validateBackupRelations(tables: BackupTable[]): void {
  const rows = new Map<string, relationalStore.ValuesBucket[]>();
  const indexes = new Map<string, Map<string, relationalStore.ValuesBucket>>();
  for (const table of tables) {
    rows.set(table.name, table.rows);
    const index = new Map<string, relationalStore.ValuesBucket>();
    if (table.name !== 'project_assets') {
      for (const row of table.rows) {
        const id = row['id'];
        if (typeof id !== 'string' || !id || index.has(id)) { throw new Error('备份包含缺失或重复的记录标识'); }
        index.set(id, row);
      }
    }
    indexes.set(table.name, index);
  }
  const each = (table: string, action: (row: relationalStore.ValuesBucket) => void): void => { (rows.get(table) || []).forEach(action); };
  const link = (row: relationalStore.ValuesBucket, field: string, table: string, optional: boolean = false): relationalStore.ValuesBucket | undefined => {
    if (optional && row[field] === null) { return undefined; }
    const owner = indexes.get(table)?.get(String(row[field]));
    if (!owner) { throw new Error('备份关联无效：' + field); }
    return owner;
  };
  const unique = (table: string, fields: string[], skipNull: boolean = false): void => {
    const keys = new Set<string>();
    each(table, (row: relationalStore.ValuesBucket): void => {
      if (skipNull && fields.some((field: string) => row[field] === null)) { return; }
      const key = JSON.stringify(fields.map((field: string) => row[field]));
      if (keys.has(key)) { throw new Error('备份包含重复的关联或名称：' + table); } keys.add(key);
    });
  };
  const choice = (row: relationalStore.ValuesBucket, field: string, allowed: string[]): void => {
    if (!allowed.includes(String(row[field]))) { throw new Error('备份包含无效状态：' + field); }
  };
  for (const table of tables) {
    for (const row of table.rows) {
      for (const field of ['favorite', 'ticket_purchased', 'done', 'pinned']) {
        if (row[field] !== undefined && row[field] !== 0 && row[field] !== 1) { throw new Error('备份包含无效开关：' + field); }
      }
    }
  }
  each('variants', (row): void => { link(row, 'character_id', 'characters'); });
  unique('variants', ['character_id', 'name']);
  each('events', (row): void => { choice(row, 'status', ['Wishlist', 'Planned', 'Attended']); });
  each('projects', (row): void => {
    link(row, 'character_id', 'characters'); link(row, 'event_id', 'events', true);
    const variant = link(row, 'variant_id', 'variants', true);
    if (variant && variant['character_id'] !== row['character_id']) { throw new Error('备份角色版本不属于当前角色'); }
    choice(row, 'status', ['Idea', 'Planning', 'Preparing', 'Ready', 'Event', 'Shooting', 'PostProduction', 'Completed', 'Archived']);
  });
  each('assets', (row): void => {
    choice(row, 'type', ['Costume', 'Wig', 'Shoes', 'Prop', 'Accessory', 'ContactLens', 'Makeup', 'Other']);
    choice(row, 'status', ['Wish', 'Ordered', 'Owned', 'Repair', 'Lent', 'Retired']);
  });
  each('project_assets', (row): void => { link(row, 'project_id', 'projects'); link(row, 'asset_id', 'assets'); });
  unique('project_assets', ['project_id', 'asset_id']);
  each('checklist_items', (row): void => { link(row, 'project_id', 'projects'); link(row, 'asset_id', 'assets', true); });
  unique('checklist_items', ['project_id', 'asset_id'], true);
  each('photos', (row): void => {
    link(row, 'project_id', 'projects'); choice(row, 'status', ['Imported', 'Raw', 'Selected', 'WaitingForRetouch', 'Retouched', 'Final', 'Published', 'Archived']);
  });
  unique('photos', ['project_id', 'source_uri']);
  each('photo_versions', (row): void => { link(row, 'photo_id', 'photos'); });
  each('diary_entries', (row): void => { link(row, 'project_id', 'projects', true); });
  each('preparation_categories', (row): void => { link(row, 'project_id', 'projects'); });
  unique('preparation_categories', ['project_id', 'name']);
  each('preparation_tasks', (row): void => {
    link(row, 'project_id', 'projects'); const category = link(row, 'category_id', 'preparation_categories');
    if (category?.['project_id'] !== row['project_id']) { throw new Error('备份准备分类不属于当前计划'); }
  });
  each('team_members', (row): void => { link(row, 'project_id', 'projects'); });
  each('expenses', (row): void => { link(row, 'project_id', 'projects'); });
  each('reference_images', (row): void => {
    if ((row['project_id'] === null) === (row['character_id'] === null)) { throw new Error('备份参考图必须且只能属于计划或角色'); }
    link(row, 'project_id', 'projects', true); link(row, 'character_id', 'characters', true);
  });
  unique('reference_images', ['project_id', 'source_uri'], true); unique('reference_images', ['character_id', 'source_uri'], true);
  each('project_shots', (row): void => {
    const project = link(row, 'project_id', 'projects');
    if (row['reference_id'] !== '') {
      const reference = link(row, 'reference_id', 'reference_images');
      if (reference?.['project_id'] !== row['project_id'] && reference?.['character_id'] !== project?.['character_id']) { throw new Error('备份拍摄参考图不属于此计划或角色'); }
    }
  });
}
