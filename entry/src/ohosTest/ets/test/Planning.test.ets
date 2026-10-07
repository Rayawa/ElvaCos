import { makePreparation, preparationKeys } from '../../../main/ets/model/Preparation';
import { PreparationRepository } from '../../../main/ets/data/repository/PreparationRepository';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TestContext } from '../testability/TestContext';
import { Database } from '../../../main/ets/data/database/Database';
import { baseSchema, migration2 } from '../../../main/ets/data/database/Schema';
import { CosEventRepository, CosProjectRepository } from '../../../main/ets/data/repository/Repositories';
import { PlanningRepository } from '../../../main/ets/data/repository/PlanningRepository';
import { MetadataBackupRepository } from '../../../main/ets/data/repository/MetadataBackupRepository';
import { MediaRepository } from '../../../main/ets/data/media/MediaRepository';
import { Character, CosProject, CosEvent, newId } from '../../../main/ets/model/Entities';
import { TeamMember, Expense, ReferenceImage, expenseTotal } from '../../../main/ets/model/Planning';

interface BackupTable { name: string; rows: relationalStore.ValuesBucket[]; }
interface BackupDocument { format: string; version: number; exportedAt: number; tables: BackupTable[]; }

export default function planningTest(): void {
  describe('PlanningPersistenceAndMedia', () => {
    const name = 'verification-planning-' + newId() + '.db'; const db = new Database(name);
    const repo = new PlanningRepository(db); const projects = new CosProjectRepository(db); const events = new CosEventRepository(db); const backup = new MetadataBackupRepository(db);
    const role = new Character(); role.name = 'Planning role';
    const project = new CosProject(); project.characterId = role.id; project.name = 'Planning project'; project.budgetCents = 20000;
    let context: common.Context;
    beforeAll(async () => { if (!TestContext.value) { throw new Error('Test context unavailable'); } context = TestContext.value; await db.open(context); await projects.save(project, '', role, makePreparation(project.id, preparationKeys(2))); });
    afterAll(async () => { await db.close(); await relationalStore.deleteRdbStore(context, name); });
    it('nativeV2MigrationKeepsIndependentPreparationAndLegacyActivity', 0, async () => {
      const oldName = 'verification-v2-' + newId() + '.db'; const upgraded = new Database(oldName);
      const legacy = await relationalStore.getRdbStore(context, { name: oldName, securityLevel: relationalStore.SecurityLevel.S3, encrypt: true });
      try {
        for (const sql of baseSchema().concat(migration2())) { await legacy.executeSql(sql); }
        await legacy.executeSql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','Legacy',1,1)");
        await legacy.executeSql("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('p','c','Legacy','Preparing',1,1)");
        await legacy.executeSql("INSERT INTO preparation_categories VALUES('g','p','Wig',0)");
        await legacy.executeSql("INSERT INTO preparation_tasks(id,project_id,category_id,label,done) VALUES('t','p','g','Styling',1)");
        await legacy.executeSql("INSERT INTO events(id,name,date,status,created_at) VALUES('e','Legacy Expo','2026-10-07','Planned',1)");
        await legacy.executeSql('PRAGMA user_version=2');
      } finally { await legacy.close(); }
      try {
        await upgraded.open(context); expect(upgraded.getStore().version).assertEqual(3);
        const tasks = await upgraded.getStore().querySql("SELECT done FROM preparation_tasks WHERE id='t'"); try { tasks.goToFirstRow(); expect(tasks.getLong(0)).assertEqual(1); } finally { tasks.close(); }
        const restored = (await new CosEventRepository(upgraded).list())[0]; expect(restored.dateMode).assertEqual('single'); expect(restored.reminderId).assertEqual(-1); expect(restored.date).assertEqual('2026-10-07');
      } finally { await upgraded.close(); await relationalStore.deleteRdbStore(context, oldName); }
    });
    it('teamAndActualExpensesPersistIndependentlyOfAssetPrices', 0, async () => {
      const member = new TeamMember(); member.projectId = project.id; member.name = '摄影 A'; member.notes = '已确认下午档期'; await repo.saveTeam(member);
      const expense = new Expense(); expense.projectId = project.id; expense.name = '摄影定金'; expense.category = '摄影'; expense.amountCents = 12990; expense.date = '2026-10-07'; await repo.saveExpense(expense);
      await db.getStore().executeSql("INSERT INTO assets(id,name,type,status,price_cents,created_at) VALUES('shared','Reusable','Wig','Owned',99999,1)");
      await db.getStore().executeSql('INSERT INTO project_assets VALUES (?,?)', [project.id, 'shared']);
      expect(expenseTotal(await repo.expenses(), project.id)).assertEqual(12990); expect((await repo.team())[0].notes).assertEqual(member.notes);
      expense.amountCents = -1; let rejected = false; try { await repo.saveExpense(expense); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect(expenseTotal(await repo.expenses())).assertEqual(12990);
    });
    it('pendingAndMultidaySchedulesPersistAndReopen', 0, async () => {
      const pending = new CosEvent(); pending.name = '待定拍摄'; pending.dateMode = 'pending'; pending.eventType = '拍摄'; await events.save(pending);
      const multiple = new CosEvent(); multiple.name = '多天漫展'; multiple.dateMode = 'multiple'; multiple.date = '2026-10-10'; multiple.endDate = '2026-10-12'; multiple.timeMode = 'range'; multiple.startTime = '10:00'; multiple.endTime = '18:00'; await events.save(multiple);
      await db.close(); await db.open(context);
      expect((await events.list()).find((e) => e.id === pending.id)?.date).assertEqual('');
      expect((await events.list()).find((e) => e.id === multiple.id)?.endDate).assertEqual('2026-10-12');
    });
    it('referenceOwnershipIsExactlyOneAndForeignKeysProtectIt', 0, async () => {
      const r = new ReferenceImage(); r.projectId = project.id; r.characterId = role.id; r.sourceUri = 'test://reference';
      let rejected = 0; try { await repo.saveReference(r); } catch (error) { rejected++; }
      r.projectId = ''; r.characterId = ''; try { await repo.saveReference(r); } catch (error) { rejected++; }
      r.projectId = 'missing'; try { await repo.saveReference(r); } catch (error) { rejected++; }
      expect(rejected).assertEqual(3); expect((await repo.references()).length).assertEqual(0);
    });
    it('backupV3RestoresWorkflowAndRejectsInvalidScheduleWithoutReplacement', 0, async () => {
      const exported = await backup.exportMetadata(); await backup.restoreMetadata(exported);
      expect((await repo.team()).length).assertEqual(1); expect(expenseTotal(await repo.expenses())).assertEqual(12990); expect((await events.list()).length).assertEqual(2);
      const doc = JSON.parse(exported) as BackupDocument; const table = doc.tables.find((t: BackupTable) => t.name === 'events');
      if (!table) { throw new Error('Missing event table'); }
      const row = table.rows.find((r: relationalStore.ValuesBucket) => r['date_mode'] === 'multiple'); if (!row) { throw new Error('Missing event fixture'); }
      row['end_date'] = '2026-10-01'; let rejected = false; try { await backup.restoreMetadata(JSON.stringify(doc)); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await repo.team()).length).assertEqual(1); expect((await events.list()).find((e) => e.dateMode === 'multiple')?.endDate).assertEqual('2026-10-12');
    });
    it('referenceFilesSurviveCollectionBackupAndCoverDeletion', 0, async () => {
      const root = context.filesDir + '/verification-media-' + newId(); const source = context.cacheDir + '/verification-reference-' + newId() + '.jpg';
      const media = new MediaRepository(context, root);
      const pixel = await image.createPixelMap(new Uint8Array(64 * 40 * 4).buffer, { size: { width: 64, height: 40 }, pixelFormat: image.PixelMapFormat.RGBA_8888 });
      const packer = image.createImagePacker(); const file = await fs.open(source, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { await packer.packToFile(pixel, file.fd, { format: 'image/jpeg', quality: 80 }); } finally { await fs.close(file); pixel.release(); packer.release(); }
      let imported: ReferenceImage | undefined;
      try {
        imported = await media.importReference(source, project.id, ''); await repo.saveReference(imported); await repo.setReferenceCover(imported, role.id);
        await media.collect([], [imported]); expect(await media.exists(imported)).assertTrue();
        await backup.restoreMetadata(await backup.exportMetadata()); expect((await repo.references())[0].localPath).assertEqual(imported.localPath);
        await repo.removeReference(imported);
        const rows = await db.getStore().querySql('SELECT cover FROM characters WHERE id=?', [role.id]); try { rows.goToFirstRow(); expect(rows.getString(0)).assertEqual(''); } finally { rows.close(); }
        await media.collect([], []); expect(await media.exists(imported)).assertFalse();
      } finally { if (imported) { await repo.removeReference(imported); await media.remove(imported); } if (await fs.access(root)) { await fs.rmdir(root); } await fs.unlink(source); }
    });
    it('v2BackupKeepsPreparationAndDefaultsNewScheduleFields', 0, async () => {
      const saved = await backup.exportMetadata(); const doc = JSON.parse(saved) as BackupDocument; doc.version = 2; doc.tables = doc.tables.slice(0, 12);
      const eventTable = doc.tables.find((t: BackupTable) => t.name === 'events');
      if (!eventTable) { throw new Error('Missing event table'); }
      const rows: relationalStore.ValuesBucket[] = [];
      for (const current of eventTable.rows.filter((r: relationalStore.ValuesBucket) => r['date'] !== '')) {
        const row: relationalStore.ValuesBucket = {}; for (const key of ['id','name','date','city','venue','url','status','ticket_purchased','notes','created_at']) { row[key] = current[key]; } rows.push(row);
      }
      eventTable.rows = rows;
      await backup.restoreMetadata(JSON.stringify(doc)); expect((await new PreparationRepository(db).tasks()).length).assertEqual(6); expect((await repo.team()).length).assertEqual(0); expect((await events.list())[0].dateMode).assertEqual('single'); expect((await events.list())[0].reminderId).assertEqual(-1);
      await backup.restoreMetadata(saved); expect((await repo.team()).length).assertEqual(1);
    });
    it('foreignReferencePathsAreNeverTrustedByBackupRestore', 0, async () => {
      const saved = await backup.exportMetadata(); const doc = JSON.parse(saved) as BackupDocument;
      const table = doc.tables.find((t: BackupTable) => t.name === 'reference_images'); if (!table) { throw new Error('Missing media table'); }
      table.rows.push({ id: 'untrusted', project_id: project.id, character_id: null, source_uri: 'test://foreign', local_path: '/etc/passwd', thumbnail_path: '/etc/passwd', caption: '', created_at: 1 });
      await backup.restoreMetadata(JSON.stringify(doc)); const ref = (await repo.references())[0]; expect(ref.localPath).assertEqual(''); expect(ref.thumbnailPath).assertEqual('');
      await backup.restoreMetadata(saved); expect((await repo.references()).length).assertEqual(0);
    });
    it('projectRemovalCascadesPlanningDataAndKeepsReusableGear', 0, async () => {
      await projects.remove(project.id); expect((await repo.team()).length).assertEqual(0); expect((await repo.expenses()).length).assertEqual(0);
      const rows = await db.getStore().querySql("SELECT id FROM assets WHERE id='shared'"); try { expect(rows.rowCount).assertEqual(1); } finally { rows.close(); }
      expect((await events.list()).length).assertEqual(2);
    });
  });
}
