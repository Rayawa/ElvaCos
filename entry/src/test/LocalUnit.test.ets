import { AppState } from '../main/ets/model/ApplicationState';
import { EditDraft } from '../main/ets/model/EditDraft';
import { describe, it, expect } from '@ohos/hypium';
import { requiredName, moneyToCents, validDate, projectProgress, checklistProgress, nextPlan, photoStage } from '../main/ets/model/Rules';
import { Asset, AssetStatus, ProjectAsset, ChecklistItem, CosProject, CosEvent, ProjectStatus, PhotoAsset, PhotoStatus, Character } from '../main/ets/model/Entities';

export default function localUnitTest(): void {
  describe('DomainRules', () => {
    it('moneyUsesIntegerCents', 0, () => { expect(moneyToCents('129.99')).assertEqual(12999); expect(moneyToCents('0')).assertEqual(0); });
    it('invalidAmountsAreRejected', 0, () => { let rejected = 0; for (const value of ['-1','0.001','abc','Infinity']) { try { moneyToCents(value); } catch (error) { rejected++; } } expect(rejected).assertEqual(4); });
    it('dateChecksCalendarAndLeapYears', 0, () => { expect(validDate('2026-02-29')).assertFalse(); expect(validDate('2024-02-29')).assertTrue(); expect(validDate('2026-13-01')).assertFalse(); expect(validDate('2026-10-24')).assertTrue(); });
    it('onlyOwnedAssetsCountAsReady', 0, () => {
      const owned = new Asset(); owned.status = AssetStatus.OWNED;
      const repair = new Asset(); repair.status = AssetStatus.REPAIR;
      const first = new ProjectAsset(); first.projectId = 'p'; first.assetId = owned.id;
      const second = new ProjectAsset(); second.projectId = 'p'; second.assetId = repair.id;
      const progress = projectProgress('p', [first, second], [owned, repair]);
      expect(progress.total).assertEqual(2); expect(progress.ready).assertEqual(1); expect(progress.percent).assertEqual(50);
      expect(projectProgress('empty', [], []).percent).assertEqual(0);
    });
    it('checklistProgressHandlesEmptyAndComplete', 0, () => { const item = new ChecklistItem(); item.done = true; expect(checklistProgress([])).assertEqual(0); expect(checklistProgress([item])).assertEqual(100); });
    it('homeChoosesNearestUpcomingPlanAndSkipsFinishedOnes', 0, () => {
      const undated = new CosProject(); undated.id = 'undated';
      const overdue = new CosProject(); overdue.id = 'overdue'; overdue.targetDate = '2026-10-01';
      const later = new CosProject(); later.id = 'later'; later.targetDate = '2026-11-01';
      const event = new CosEvent(); event.date = '2026-10-10';
      const nearest = new CosProject(); nearest.id = 'nearest'; nearest.eventId = event.id;
      const finished = new CosProject(); finished.targetDate = '2026-10-07'; finished.status = ProjectStatus.COMPLETED;
      const plans = [undated, overdue, later, nearest, finished];
      expect(nextPlan(plans, [event], '2026-10-06')?.id).assertEqual('nearest');
      expect(plans[0].id).assertEqual('undated');
      nearest.status = ProjectStatus.ARCHIVED;
      expect(nextPlan([finished, nearest], [event], '2026-10-06')).assertUndefined();
      expect(nextPlan([undated, overdue], [], '2026-10-06')?.id).assertEqual('overdue');
    });
    it('planDraftKeepsFirstTimeAndEventCreationInTheSameFlow', 0, () => {
      const state = new AppState();
      const first = EditDraft.make(state, 'project');
      expect(first.kind).assertEqual('project'); expect(first.newCharacter).assertTrue();
      const role = new Character(); role.name = 'Reusable'; state.characters = [role];
      const event = new CosEvent(); event.date = '2026-10-18'; state.events = [event];
      const contextual = EditDraft.make(state, 'project', '', event.id);
      expect(contextual.characterId).assertEqual(role.id); expect(contextual.newCharacter).assertFalse();
      expect(contextual.eventId).assertEqual(event.id); expect(contextual.date).assertEqual(event.date);
      expect(contextual.advanced).assertFalse();
    });
    it('photoStagesIncludeRawAndFinishedVariantsWithoutArchived', 0, () => {
      const photos = [PhotoStatus.IMPORTED, PhotoStatus.RAW, PhotoStatus.SELECTED, PhotoStatus.WAITING, PhotoStatus.RETOUCHED, PhotoStatus.FINAL, PhotoStatus.PUBLISHED, PhotoStatus.ARCHIVED].map((status: PhotoStatus): PhotoAsset => { const photo = new PhotoAsset(); photo.status = status; return photo; });
      expect(photoStage(photos, 0).length).assertEqual(8);
      expect(photoStage(photos, 1).length).assertEqual(2);
      expect(photoStage(photos, 2).length).assertEqual(1);
      expect(photoStage(photos, 3).length).assertEqual(1);
      expect(photoStage(photos, 4).length).assertEqual(3);
    });
    it('namesTrimWhitespaceAndRejectEmpty' , 0, () => { expect(requiredName('  Miku  ')).assertEqual('Miku'); let rejected = false; try { requiredName('  '); } catch (error) { rejected = true; } expect(rejected).assertTrue(); });
  });
}
