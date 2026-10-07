import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TestContext } from '../testability/TestContext';
import { Database } from '../../../main/ets/data/database/Database';
import { DemoDataRepository } from '../../../main/ets/data/repository/DemoDataRepository';
import { MediaRepository } from '../../../main/ets/data/media/MediaRepository';
import { CharacterRepository, CosProjectRepository, PhotoAssetRepository, RelationRepository } from '../../../main/ets/data/repository/Repositories';
import { PlanningRepository } from '../../../main/ets/data/repository/PlanningRepository';
import { MetadataBackupRepository } from '../../../main/ets/data/repository/MetadataBackupRepository';
import { Character, newId } from '../../../main/ets/model/Entities';
import { CosEventRepository } from '../../../main/ets/data/repository/Repositories';
import { checkSchedule } from '../../../main/ets/model/Schedule';

export default function demoDataTest(): void {
  describe('BundledDemoData', () => {
    const name = 'verification-demo-' + newId() + '.db';
    const db = new Database(name);
    let context: common.Context;
    let media: MediaRepository;
    let demo: DemoDataRepository;
    let mediaRoot: string;
    const now = new Date(2026, 9, 8, 12);
    beforeAll(async (): Promise<void> => {
      if (!TestContext.value) { throw new Error('Missing test context'); }
      context = TestContext.value.createModuleContext('entry');
      mediaRoot = context.filesDir + '/verification-demo-' + newId();
      media = new MediaRepository(context, mediaRoot);
      demo = new DemoDataRepository(db, context, media);
      await db.open(context);
      const personal = new Character(); personal.id = 'personal-character'; personal.name = '我的角色';
      await new CharacterRepository(db).save(personal);
    });
    afterAll(async (): Promise<void> => {
      await db.close();
      await relationalStore.deleteRdbStore(context, name);
      if (await fs.access(mediaRoot)) { await fs.rmdir(mediaRoot); }
    });
    it('automaticImportSkipsPersonalDataAndMarksTheCheck', 0, async (): Promise<void> => {
      expect(await demo.load(true, now)).assertFalse();
      expect((await new CharacterRepository(db).list()).length).assertEqual(1);
    });
    it('explicitImportAddsCompleteRelationsWithoutReplacingPersonalData', 0, async (): Promise<void> => {
      expect(await demo.load(false, now)).assertTrue();
      expect((await new CharacterRepository(db).list()).length).assertEqual(17);
      const projects = await new CosProjectRepository(db).list();
      expect(projects.length).assertEqual(24);
      expect(projects.find((p) => p.id === 'demo-v1-project-0')?.targetDate).assertEqual('2026-10-08');
      for (const event of await new CosEventRepository(db).list()) { checkSchedule(event); expect(event.reminderMinutes).assertEqual(-1); }
      const violations = await db.getStore().querySql('PRAGMA foreign_key_check');
      try { expect(violations.rowCount).assertEqual(0); } finally { violations.close(); }
      // The existing portable backup validator must accept all populated tables.
      const backup = new MetadataBackupRepository(db);
      await backup.restoreMetadata(await backup.exportMetadata());
      expect((await new CharacterRepository(db).list()).some((c) => c.id === 'personal-character')).assertTrue();
    });
    it('bundledImagesDecodeOfflineAndAreOwnedByIndividualMediaRecords', 0, async (): Promise<void> => {
      const photos = await new PhotoAssetRepository(db).list();
      const references = await new PlanningRepository(db).references();
      expect(photos.length).assertEqual(76); expect(references.length).assertEqual(40);
      const allPaths: string[] = [];
      for (const item of photos) {
        expect(await media.exists(item)).assertTrue();
        expect(allPaths.includes(item.localPath)).assertFalse(); allPaths.push(item.localPath);
      }
      for (const item of references) {
        expect(await media.exists(item)).assertTrue();
        expect(allPaths.includes(item.localPath)).assertFalse(); allPaths.push(item.localPath);
      }
      const source = image.createImageSource(photos[0].localPath);
      try { const info = await source.getImageInfo(); expect(info.size.width > 0 && info.size.height > 0).assertTrue(); }
      finally { source.release(); }
      const original = photos[0].localPath;
      await media.collect(photos, references);
      expect(await fs.access(original)).assertTrue();
      expect((await new CharacterRepository(db).list()).filter((c) => c.id.startsWith('demo-v1-')).every((c) => c.cover.length > 0)).assertTrue();
    });
    it('repeatImportPreservesEditedAndDeletedRecordsAcrossReopen', 0, async (): Promise<void> => {
      const characters = new CharacterRepository(db);
      const role = (await characters.list()).find((c) => c.id === 'demo-v1-character-hutao');
      if (!role) { throw new Error('Missing demo character'); }
      role.name = '已修改的胡桃'; await characters.save(role);
      await new CosProjectRepository(db).remove('demo-v1-project-0');
      await db.close(); await db.open(context);
      expect(await demo.load(false, now)).assertFalse();
      expect((await characters.list()).find((c) => c.id === role.id)?.name).assertEqual('已修改的胡桃');
      expect((await new CosProjectRepository(db).list()).length).assertEqual(23);
    });
    it('clearingStaysEmptyOnAutomaticLoadAndExplicitReloadWorks', 0, async (): Promise<void> => {
      await new RelationRepository(db).clear(); await media.collect([]);
      expect(await demo.load(true, now)).assertFalse();
      expect((await new CharacterRepository(db).list()).length).assertEqual(0);
      expect(await demo.load(false, now)).assertTrue();
      expect((await new CharacterRepository(db).list()).length).assertEqual(16);
    });
  });
}
