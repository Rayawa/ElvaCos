import { TestContext } from '../testability/TestContext';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { Database } from '../../../main/ets/data/database/Database';
import { CharacterRepository, CharacterVariantRepository, CosProjectRepository, AssetRepository, PhotoAssetRepository, RelationRepository, ChecklistItemRepository } from '../../../main/ets/data/repository/Repositories';
import { Character, CharacterVariant, CosProject, Asset, PhotoAsset, PhotoStatus, newId } from '../../../main/ets/model/Entities';
import { BackupService } from '../../../main/ets/common/BackupService';
import { MediaRepository } from '../../../main/ets/data/media/MediaRepository';
import getDiskStorageInstance from '../../../main/ets/common/DiskStorage';
import { migrateElvaPreferences, migrateUxPreferences } from '../../../main/ets/common/SettingsMigration';
import { preferences } from '@kit.ArkData';
import localUnitTest from '../../../test/LocalUnit.test';

export default function abilityTest(): void {
  localUnitTest();
  describe('NativePersistenceAndMedia', () => {
    const name = 'verification-' + newId() + '.db';
    const db = new Database(name);
    const characters = new CharacterRepository(db);
    const variants = new CharacterVariantRepository(db);
    const projects = new CosProjectRepository(db);
    const assets = new AssetRepository(db);
    const photos = new PhotoAssetRepository(db);
    const relations = new RelationRepository(db);
    const checklist = new ChecklistItemRepository(db);
    const character = new Character(); character.name = 'Verification Character';
    const variant = new CharacterVariant(); variant.characterId = character.id; variant.name = 'Original';
    const project = new CosProject(); project.name = 'Verification Project'; project.characterId = character.id; project.variantId = variant.id;
    const asset = new Asset(); asset.name = 'Verification Wig';
    let context: common.Context;
    beforeAll(async () => { if (!TestContext.value) { throw new Error('TestAbility context unavailable'); } context = TestContext.value; await db.open(context); });
    afterAll(async () => { await db.close(); await relationalStore.deleteRdbStore(context, name); });
    it('migrationAndCrudWorkOnNativeRdb', 0, async () => {
      expect(db.getStore().version).assertEqual(3);
      await characters.save(character); await variants.save(variant); await projects.save(project); await assets.save(asset);
      expect((await characters.list())[0].name).assertEqual(character.name);
      expect((await projects.list())[0].variantId).assertEqual(variant.id);
    });
    it('assetAssociationAndChecklistGenerationAreIdempotent', 0, async () => {
      await relations.link(project.id, asset); await relations.link(project.id, asset);
      expect((await relations.links()).length).assertEqual(1); expect((await checklist.list()).length).assertEqual(1);
    });
    it('foreignKeysProtectLinkedCharacters', 0, async () => {
      let rejected = false; try { await characters.remove(character.id); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await characters.list()).length).assertEqual(1);
    });
    it('encryptedDataPersistsAfterReopening', 0, async () => { await db.close(); await db.open(context); expect((await projects.list())[0].name).assertEqual(project.name); });

    it('portableMetadataRestoresAndRejectsFutureVersions', 0, async () => {
      const backup = new BackupService(db, context);
      const exported = await backup.exportMetadata();
      character.name = 'Changed'; await characters.save(character);
      await backup.restoreMetadata(exported);
      expect((await characters.list())[0].name).assertEqual('Verification Character');
      let rejected = false; try { await backup.restoreMetadata(exported.replace('"version":3', '"version":4')); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await projects.list()).length).assertEqual(1);
    });
    it('invalidBackupForeignKeyRollsBackReplacement', 0, async () => {
      const backup = new BackupService(db, context);
      const exported = await backup.exportMetadata();
      let rejected = false;
      try { await backup.restoreMetadata(exported.replace('"variant_id":"' + variant.id + '"', '"variant_id":"missing"')); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await projects.list())[0].variantId).assertEqual(variant.id); expect((await relations.links()).length).assertEqual(1);
    });
    it('mediaImportMakesIndependentOriginalAndThumbnail', 0, async () => {
      const sourcePath = context.cacheDir + '/verification.jpg';
      const pixel = await image.createPixelMap(new Uint8Array(640 * 480 * 4).buffer, { size: { width: 640, height: 480 }, pixelFormat: image.PixelMapFormat.RGBA_8888 });
      const packer = image.createImagePacker();
      const file = await fs.open(sourcePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { await packer.packToFile(pixel, file.fd, { format: 'image/jpeg', quality: 80 }); } finally { await fs.close(file); pixel.release(); packer.release(); }
      const media = new MediaRepository(context);
      const imported = await media.import(sourcePath, project.id);
      try {
        expect(imported.localPath !== sourcePath).assertTrue(); expect((await fs.stat(imported.localPath)).size > 0).assertTrue();
        const thumb = image.createImageSource(imported.thumbnailPath);
        try { expect((await thumb.getImageInfo()).size.width <= 480).assertTrue(); } finally { thumb.release(); }
        await relations.addPhoto(imported);
        expect((await photos.list()).length).assertEqual(1);
        const backup = new BackupService(db, context);
        await backup.restoreMetadata(await backup.exportMetadata());
        expect((await photos.list())[0].localPath).assertEqual(imported.localPath);
        await photos.remove(imported.id);
      } finally { await media.remove(imported); await fs.unlink(sourcePath); }
    });
    it('preferencesMigratePersistAndPreserveExistingValues', 0, async () => {
      const oldName = 'verification-old-' + newId();
      const newName = 'verification-new-' + newId();
      const legacy = getDiskStorageInstance(oldName, context)!;
      const target = getDiskStorageInstance(newName, context)!;
      try {
        await legacy.set('haptic', false); await legacy.set('hapticLevel', 2);
        await legacy.set('materialLevel', 0); await legacy.set('theme', 'dark'); await legacy.set('grip', true);
        await migrateElvaPreferences(target, legacy);
        expect(await target.get('vibrationLevel', -1)).assertEqual(0);
        expect(await target.get('immersiveMaterialLevel', -1)).assertEqual(0);
        expect(await target.get('holdCheckON', false)).assertEqual(true);
        await target.set('vibrationLevel', 1);
        await migrateElvaPreferences(target, legacy);
        expect(await target.get('vibrationLevel', -1)).assertEqual(1);
        await target.destroy();
        const reopened = getDiskStorageInstance(newName, context)!;
        expect(await reopened.get('theme', '')).assertEqual('dark');
        expect(await reopened.get('vibrationLevel', -1)).assertEqual(1);
        await reopened.destroy();
      } finally {
        await legacy.destroy(); await target.destroy();
        await preferences.deletePreferences(context, oldName); await preferences.deletePreferences(context, newName);
      }
    });
    it('uxPreferencesPreserveDisabledEffectsAndUnifyHandModes', 0, async () => {
      const names = ['verification-ux-' + newId(), 'verification-ux-' + newId(), 'verification-ux-' + newId()];
      const disabled = getDiskStorageInstance(names[0], context)!;
      const automatic = getDiskStorageInstance(names[1], context)!;
      const manual = getDiskStorageInstance(names[2], context)!;
      try {
        await disabled.set('effects', false); await disabled.set('immersiveMaterialLevel', 0);
        await disabled.set('theme', 'dark'); await disabled.set('hand', 'auto'); await disabled.set('holdCheckON', false);
        await disabled.set('username', 'Preserved');
        await migrateUxPreferences(disabled);
        expect(await disabled.get('immersiveMaterialLevel', -1)).assertEqual(2);
        expect(await disabled.get('effects', true)).assertEqual(false);
        expect(await disabled.get('hand', '')).assertEqual('left');
        expect(await disabled.get('theme', '')).assertEqual('system');
        expect(await disabled.get('username', '')).assertEqual('Preserved');
        await disabled.set('immersiveMaterialLevel', 1); await disabled.set('effects', true);
        await migrateUxPreferences(disabled);
        expect(await disabled.get('immersiveMaterialLevel', -1)).assertEqual(1);
        await disabled.destroy();
        const reopened = getDiskStorageInstance(names[0], context)!;
        expect(await reopened.get('ux_preferences_v2', false)).assertEqual(true);
        expect(await reopened.get('effects', false)).assertEqual(true);
        await reopened.destroy();
        await automatic.set('hand', 'auto'); await automatic.set('holdCheckON', true);
        await migrateUxPreferences(automatic);
        expect(await automatic.get('hand', '')).assertEqual('auto');
        expect(await automatic.get('holdCheckON', false)).assertEqual(true);
        await manual.set('hand', 'right'); await manual.set('holdCheckON', true);
        await manual.set('immersiveMaterialLevel', 2);
        await migrateUxPreferences(manual);
        expect(await manual.get('hand', '')).assertEqual('right');
        expect(await manual.get('holdCheckON', true)).assertEqual(false);
        expect(await manual.get('effects', true)).assertEqual(false);
      } finally {
        await disabled.destroy(); await automatic.destroy(); await manual.destroy();
        for (const preferenceName of names) { await preferences.deletePreferences(context, preferenceName); }
      }
    });
    it('cacheClearRemovesOnlyIsolatedTemporaryFiles', 0, async () => {
      const root = context.cacheDir + '/verification-' + newId();
      const original = context.filesDir + '/verification-' + newId() + '.original';
      const media = new MediaRepository(context);
      await fs.mkdir(root + '/nested', true);
      for (const path of [root + '/temporary', root + '/nested/temporary', original]) {
        const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        try { await fs.write(file.fd, 'retained'); } finally { await fs.close(file); }
      }
      try {
        expect(await media.cacheSize(root)).assertEqual(16);
        await media.clearCache(root);
        expect(await media.cacheSize(root)).assertEqual(0);
        expect(await fs.access(original)).assertTrue();
        let rejected = false;
        try { await media.clearCache(root + '/../'); } catch (error) { rejected = true; }
        expect(rejected).assertTrue();
      } finally { await fs.rmdir(root); await fs.unlink(original); }
    });
    it('newRoleAndPlanAreAtomicAndNeverLeaveHalfAPlan', 0, async () => {
      const role = new Character(); role.name = 'Inline role';
      const plan = new CosProject(); plan.name = 'Inline plan'; plan.characterId = role.id; plan.variantId = 'missing';
      let rejected = false;
      try { await projects.save(plan, 'Created inline', role); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      expect((await characters.list()).some((c: Character) => c.id === role.id)).assertFalse();
      expect((await projects.list()).some((p: CosProject) => p.id === plan.id)).assertFalse();
      plan.variantId = '';
      await projects.save(plan, 'Created inline', role);
      try {
        expect((await characters.list()).some((c: Character) => c.id === role.id)).assertTrue();
        expect((await projects.list()).find((p: CosProject) => p.id === plan.id)?.characterId).assertEqual(role.id);
      } finally { await projects.remove(plan.id); await characters.remove(role.id); }
    });
    it('newGearAssociationAndPackingItemSaveTogether', 0, async () => {
      const gear = new Asset(); gear.name = 'Inline gear';
      let rejected = false;
      try { await assets.save(gear, 'missing'); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect((await assets.list()).some((a: Asset) => a.id === gear.id)).assertFalse();
      await assets.save(gear, project.id);
      try {
        expect((await relations.links()).some((link) => link.projectId === project.id && link.assetId === gear.id)).assertTrue();
        expect((await checklist.list()).filter((item) => item.projectId === project.id && item.assetId === gear.id).length).assertEqual(1);
      } finally { await relations.unlink(project.id, gear.id); await assets.remove(gear.id); }
    });
    it('batchPhotoStatusRollsBackIfSelectionContainsMissingRecord', 0, async () => {
      const first = new PhotoAsset(); first.projectId = project.id; first.sourceUri = 'verification-first';
      const second = new PhotoAsset(); second.projectId = project.id; second.sourceUri = 'verification-second';
      await photos.save(first); await photos.save(second);
      try {
        let rejected = false;
        try { await photos.setStatuses([first.id, 'missing'], PhotoStatus.SELECTED); } catch (error) { rejected = true; }
        expect(rejected).assertTrue(); expect((await photos.list()).find((p: PhotoAsset) => p.id === first.id)?.status).assertEqual(PhotoStatus.IMPORTED);
        await photos.setStatuses([first.id, second.id], PhotoStatus.WAITING);
        expect((await photos.list()).filter((p: PhotoAsset) => p.status === PhotoStatus.WAITING).length).assertEqual(2);
      } finally { await photos.remove(first.id); await photos.remove(second.id); }
    });
    it('projectDeleteCascadesLinksAndKeepsReusableAsset', 0, async () => {
      await projects.remove(project.id);
      expect((await relations.links()).length).assertEqual(0); expect((await checklist.list()).length).assertEqual(0); expect((await assets.list()).length).assertEqual(1);
    });
  });
}
