import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { SCHEMA, SCHEMA_VERSION, MIGRATION_2, MIGRATION_3 } from './Schema';

// Use the store's writer connection: createTransaction() uses a separate
// connection whose PRAGMA foreign_keys setting is not inherited.
export class WriteTransaction {
  private store: relationalStore.RdbStore;
  constructor(store: relationalStore.RdbStore) { this.store = store; }
  execute(sql: string, args?: relationalStore.ValueType[]): Promise<void> { return this.store.executeSql(sql, args); }
  insert(table: string, row: relationalStore.ValuesBucket): Promise<number> { return this.store.insert(table, row); }
}

export class Database {
  private store?: relationalStore.RdbStore;
  private inTransaction: boolean = false;
  private name: string;
  constructor(name: string = 'personal.db') { this.name = name; }
  async open(context: common.Context): Promise<void> {
    if (this.store) { return; }
    const store = await relationalStore.getRdbStore(context, { name: this.name, securityLevel: relationalStore.SecurityLevel.S3, encrypt: true });
    try {
      await store.executeSql('PRAGMA foreign_keys = ON');
      if (store.version > SCHEMA_VERSION) { throw new Error('此数据由更新版本创建，请升级应用'); }
      if (store.version < SCHEMA_VERSION) {
        store.beginTransaction();
        try {
          const version = store.version;
          if (version < 1) { for (const sql of SCHEMA) { await store.executeSql(sql); } }
          if (version < 2) { for (const sql of MIGRATION_2) { await store.executeSql(sql); } }
          if (version < 3) { for (const sql of MIGRATION_3) { await store.executeSql(sql); } }
          await store.executeSql('PRAGMA user_version = 3');
          store.commit();
        } catch (error) { store.rollBack(); throw error as Error; }
      }
      this.store = store;
    } catch (error) { store.close(); throw error as Error; }
  }
  getStore(): relationalStore.RdbStore {
    if (!this.store) { throw new Error('数据库尚未初始化'); }
    return this.store;
  }
  // AppState serializes writes. Reject accidental nested/concurrent transactions.
  async transaction(action: (tx: WriteTransaction) => Promise<void>): Promise<void> {
    if (this.inTransaction) { throw new Error('已有数据操作进行中'); }
    const store = this.getStore();
    store.beginTransaction();
    this.inTransaction = true;
    try { await action(new WriteTransaction(store)); store.commit(); }
    catch (error) { store.rollBack(); throw error as Error; }
    finally { this.inTransaction = false; }
  }
  close(): void { if (this.store) { this.store.close(); this.store = undefined; } }
}
