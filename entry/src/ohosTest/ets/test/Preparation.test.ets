import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TestContext } from '../testability/TestContext';
import { Database } from '../../../main/ets/data/database/Database';
import { SCHEMA } from '../../../main/ets/data/database/Schema';
import { CosProjectRepository, ChecklistItemRepository } from '../../../main/ets/data/repository/Repositories';
import { PreparationRepository } from '../../../main/ets/data/repository/PreparationRepository';
import { MetadataBackupRepository } from '../../../main/ets/data/repository/MetadataBackupRepository';
import { newId, Character, CosProject } from '../../../main/ets/model/Entities';
import { makePreparation, preparationKeys, preparationProgress } from '../../../main/ets/model/Preparation';

interface BackupTable { name: string; rows: relationalStore.ValuesBucket[]; }
interface BackupDocument { format: string; version: number; exportedAt: number; tables: BackupTable[]; }

export default function preparationTest(): void {
  describe('PreparationWorkflow', () => {
    const name = 'verification-preparation-' + newId() + '.db';
    const db = new Database(name);
    const repo = new PreparationRepository(db);
    const projects = new CosProjectRepository(db);
    const checklist = new ChecklistItemRepository(db);
    const backup = new MetadataBackupRepository(db);
    let context: common.Context;
    beforeAll(async () => {
      if (!TestContext.value) { throw new Error('Test context unavailable'); } context = TestContext.value;
      const legacy = await relationalStore.getRdbStore(context, { name: name, securityLevel: relationalStore.SecurityLevel.S3, encrypt: true });
      try {
        await legacy.executeSql('PRAGMA foreign_keys=ON');
        for (const sql of SCHEMA) { await legacy.executeSql(sql); }
        await legacy.executeSql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('legacy-c','Old role',1,1)");
        await legacy.executeSql("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('legacy-p','legacy-c','Old plan','Preparing',1,1)");
        await legacy.executeSql("INSERT INTO assets(id,name,type,status,created_at) VALUES('legacy-a','Old wig','Wig','Owned',1)");
        await legacy.executeSql("INSERT INTO checklist_items VALUES('legacy-pack','legacy-p','legacy-a','Old wig',1,0)");
        await legacy.executeSql("INSERT INTO photos VALUES('legacy-photo','legacy-p','test://old','/original','/thumb','Raw','',1)");
        await legacy.executeSql('PRAGMA user_version=1');
      } finally { legacy.close(); }
      await db.open(context);
    });
    afterAll(async () => { db.close(); await relationalStore.deleteRdbStore(context, name); });
    it('nativeV1MigrationPreservesPackingAndMediaWithoutInventingPreparation', 0, async () => {
      expect(db.getStore().version).assertEqual(3);
      expect((await checklist.list())[0].done).assertTrue();
      expect((await repo.tasks()).length).assertEqual(0);
      const rows = await db.getStore().querySql("SELECT local_path FROM photos WHERE id='legacy-photo'");
      try { rows.goToFirstRow(); expect(rows.getString(0)).assertEqual('/original'); } finally { rows.close(); }
      db.close(); await db.open(context); expect((await checklist.list())[0].done).assertTrue();
    });
    it('planRoleAndSelectedTemplateCommitAtomically', 0, async () => {
      const role = new Character(); role.name = 'Template role';
      const plan = new CosProject(); plan.name = 'Template plan'; plan.characterId = role.id;
      const bundle = makePreparation(plan.id, preparationKeys(2));
      await projects.save(plan, 'Start', role, bundle);
      expect((await repo.tasks()).filter((t) => t.projectId === plan.id).length).assertEqual(6);
      expect((await repo.tasks()).some((t) => t.label === '购买')).assertFalse();
      const brokenRole = new Character(); brokenRole.name = 'Must roll back';
      const brokenPlan = new CosProject(); brokenPlan.name = 'Must roll back'; brokenPlan.characterId = brokenRole.id;
      const brokenBundle = makePreparation(brokenPlan.id, preparationKeys(1)); brokenBundle.tasks[0].categoryId = 'missing';
      let rejected = false; try { await projects.save(brokenPlan, 'Must roll back', brokenRole, brokenBundle); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await projects.list()).some((p) => p.id === brokenPlan.id)).assertFalse();
      const rows = await db.getStore().querySql('SELECT id FROM characters WHERE id=?', [brokenRole.id]);
      try { expect(rows.rowCount).assertEqual(0); } finally { rows.close(); }
    });
    it('addingTemplateTwicePreservesCompletionAndPacking', 0, async () => {
      await repo.addTemplate(makePreparation('legacy-p', preparationKeys(1)));
      const tasks = (await repo.tasks()).filter((t) => t.projectId === 'legacy-p');
      expect(tasks.length).assertEqual(14);
      await repo.setDone(tasks[0].id, true);
      await repo.addTemplate(makePreparation('legacy-p', preparationKeys(1)));
      const updated = (await repo.tasks()).filter((t) => t.projectId === 'legacy-p');
      expect(updated.length).assertEqual(14); expect(preparationProgress('legacy-p', updated).ready).assertEqual(1);
      expect((await checklist.list())[0].done).assertTrue();
    });
    it('categoryCannotMoveTaskToAnotherProject', 0, async () => {
      const task = (await repo.tasks()).find((t) => t.projectId === 'legacy-p');
      const foreign = (await repo.categories()).find((c) => c.projectId !== 'legacy-p');
      if (!task || !foreign) { throw new Error('Missing fixture'); }
      task.categoryId = foreign.id;
      let rejected = false; try { await repo.saveTask(task); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      expect((await repo.tasks()).find((t) => t.id === task.id)?.categoryId === foreign.id).assertFalse();
    });
    it('backupIncludesTasksAndMalformedRestoreRollsBack', 0, async () => {
      const exported = await backup.exportMetadata();
      const doc = JSON.parse(exported) as BackupDocument;
      const table = doc.tables.find((t: BackupTable) => t.name === 'preparation_tasks');
      if (!table) { throw new Error('Missing task backup'); }
      const count = table.rows.length; expect(count > 0).assertTrue();
      await backup.restoreMetadata(exported); expect((await repo.tasks()).length).assertEqual(count);
      table.rows[0]['category_id'] = 'missing';
      let rejected = false; try { await backup.restoreMetadata(JSON.stringify(doc)); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await repo.tasks()).length).assertEqual(count);
    });
    it('legacyBackupImportsWithoutChangingPackingMeaning', 0, async () => {
      const saved = await backup.exportMetadata();
      const legacy = JSON.parse(saved) as BackupDocument; legacy.version = 1; legacy.tables = legacy.tables.slice(0, 10);
      const eventTable = legacy.tables.find((t: BackupTable) => t.name === 'events');
      if (eventTable) {
        const legacyRows: relationalStore.ValuesBucket[] = [];
        for (const row of eventTable.rows) {
          const legacyRow: relationalStore.ValuesBucket = {};
          for (const key of ['id','name','date','city','venue','url','status','ticket_purchased','notes','created_at']) { legacyRow[key] = row[key]; }
          legacyRows.push(legacyRow);
        }
        eventTable.rows = legacyRows;
      }
      await backup.restoreMetadata(JSON.stringify(legacy));
      expect((await repo.tasks()).length).assertEqual(0); expect((await checklist.list())[0].done).assertTrue();
      await backup.restoreMetadata(saved); expect((await repo.tasks()).length > 0).assertTrue();
    });
    it('deletingCategoryKeepsPackingAndReusableAssets', 0, async () => {
      const category = (await repo.categories()).find((c) => c.projectId === 'legacy-p');
      if (!category) { throw new Error('Missing category'); }
      await repo.removeCategory(category.id);
      expect((await repo.tasks()).filter((t) => t.categoryId === category.id).length).assertEqual(0);
      expect((await checklist.list())[0].done).assertTrue();
    });
  });
}
