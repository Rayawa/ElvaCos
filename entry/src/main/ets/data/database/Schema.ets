const SCHEMA: string[] = [
  `CREATE TABLE characters (id TEXT PRIMARY KEY, name TEXT NOT NULL, work_name TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', cover TEXT NOT NULL DEFAULT '', favorite INTEGER NOT NULL DEFAULT 0 CHECK(favorite IN (0,1)), status TEXT NOT NULL DEFAULT 'Wishlist', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)`,
  `CREATE TABLE variants (id TEXT PRIMARY KEY, character_id TEXT NOT NULL REFERENCES characters(id) ON DELETE CASCADE, name TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', UNIQUE(character_id,name), UNIQUE(id,character_id))`,
  `CREATE TABLE events (id TEXT PRIMARY KEY, name TEXT NOT NULL, date TEXT NOT NULL, city TEXT NOT NULL DEFAULT '', venue TEXT NOT NULL DEFAULT '', url TEXT NOT NULL DEFAULT '', status TEXT NOT NULL CHECK(status IN ('Wishlist','Planned','Attended')), ticket_purchased INTEGER NOT NULL DEFAULT 0 CHECK(ticket_purchased IN (0,1)), notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)`,
  `CREATE TABLE projects (id TEXT PRIMARY KEY, character_id TEXT NOT NULL REFERENCES characters(id) ON DELETE RESTRICT, variant_id TEXT, event_id TEXT REFERENCES events(id) ON DELETE SET NULL, name TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('Idea','Planning','Preparing','Ready','Event','Shooting','PostProduction','Completed','Archived')), notes TEXT NOT NULL DEFAULT '', target_date TEXT NOT NULL DEFAULT '', budget_cents INTEGER NOT NULL DEFAULT 0 CHECK(budget_cents>=0), created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, FOREIGN KEY(variant_id,character_id) REFERENCES variants(id,character_id) ON DELETE RESTRICT)`,
  `CREATE TABLE assets (id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('Costume','Wig','Shoes','Prop','Accessory','ContactLens','Makeup','Other')), status TEXT NOT NULL CHECK(status IN ('Wish','Ordered','Owned','Repair','Lent','Retired')), location TEXT NOT NULL DEFAULT '', brand TEXT NOT NULL DEFAULT '', size TEXT NOT NULL DEFAULT '', price_cents INTEGER NOT NULL DEFAULT 0 CHECK(price_cents>=0), purchase_url TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)`,
  `CREATE TABLE project_assets (project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE, PRIMARY KEY(project_id,asset_id))`,
  `CREATE TABLE checklist_items (id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, asset_id TEXT REFERENCES assets(id) ON DELETE SET NULL, label TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0 CHECK(done IN (0,1)), sort_order INTEGER NOT NULL DEFAULT 0)`,
  `CREATE UNIQUE INDEX checklist_asset_unique ON checklist_items(project_id,asset_id) WHERE asset_id IS NOT NULL`,
  `CREATE TABLE photos (id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, source_uri TEXT NOT NULL, local_path TEXT NOT NULL, thumbnail_path TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('Imported','Raw','Selected','WaitingForRetouch','Retouched','Final','Published','Archived')), caption TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, UNIQUE(project_id,source_uri))`,
  `CREATE TABLE photo_versions (id TEXT PRIMARY KEY, photo_id TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE, name TEXT NOT NULL, recipe TEXT NOT NULL, rendered_path TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)`,
  `CREATE TABLE diary_entries (id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id) ON DELETE CASCADE, text TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX projects_character_idx ON projects(character_id)`,
  `CREATE INDEX projects_event_idx ON projects(event_id)`,
  `CREATE INDEX photos_project_idx ON photos(project_id,created_at)`,
  `CREATE INDEX checklist_project_idx ON checklist_items(project_id,sort_order)`,
  `CREATE INDEX diary_date_idx ON diary_entries(created_at)`
];

// v1 remains immutable. Existing packing confirmations retain their meaning.
const MIGRATION_2: string[] = [
  `CREATE TABLE preparation_categories (id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0 CHECK(sort_order>=0), UNIQUE(project_id,name), UNIQUE(id,project_id))`,
  `CREATE TABLE preparation_tasks (id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, category_id TEXT NOT NULL, label TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0 CHECK(done IN (0,1)), due_date TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0 CHECK(sort_order>=0), FOREIGN KEY(category_id,project_id) REFERENCES preparation_categories(id,project_id) ON DELETE CASCADE)`,
  `CREATE INDEX preparation_project_idx ON preparation_tasks(project_id,category_id,sort_order)`
];

const MIGRATION_3: string[] = [
  `CREATE TABLE team_members (id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, role TEXT NOT NULL, name TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '')`,
  `CREATE TABLE expenses (id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE, name TEXT NOT NULL, category TEXT NOT NULL, amount_cents INTEGER NOT NULL CHECK(amount_cents>=0), date TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)`,
  `CREATE TABLE reference_images (id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id) ON DELETE CASCADE, character_id TEXT REFERENCES characters(id) ON DELETE CASCADE, source_uri TEXT NOT NULL, local_path TEXT NOT NULL, thumbnail_path TEXT NOT NULL, caption TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, CHECK((project_id IS NULL) != (character_id IS NULL)), UNIQUE(project_id,source_uri), UNIQUE(character_id,source_uri))`,
  `CREATE INDEX team_project_idx ON team_members(project_id)`,
  `CREATE INDEX expenses_project_idx ON expenses(project_id,date)`,
  `CREATE INDEX reference_project_idx ON reference_images(project_id,created_at)`,
  `ALTER TABLE events ADD COLUMN date_mode TEXT NOT NULL DEFAULT 'single' CHECK(date_mode IN ('pending','single','multiple'))`,
  `ALTER TABLE events ADD COLUMN end_date TEXT NOT NULL DEFAULT ''`,
  `ALTER TABLE events ADD COLUMN time_mode TEXT NOT NULL DEFAULT 'none' CHECK(time_mode IN ('none','start','range'))`,
  `ALTER TABLE events ADD COLUMN start_time TEXT NOT NULL DEFAULT ''`,
  `ALTER TABLE events ADD COLUMN end_time TEXT NOT NULL DEFAULT ''`,
  `ALTER TABLE events ADD COLUMN event_type TEXT NOT NULL DEFAULT '漫展'`,
  `ALTER TABLE events ADD COLUMN reminder_id INTEGER NOT NULL DEFAULT -1 CHECK(reminder_id>=-1)`,
  `ALTER TABLE events ADD COLUMN reminder_minutes INTEGER NOT NULL DEFAULT -1 CHECK(reminder_minutes IN (-1,0,30,60,1440))`
];

export function baseSchema(): string[] { return SCHEMA; }
export function migration2(): string[] { return MIGRATION_2; }
export function migration3(): string[] { return MIGRATION_3; }
