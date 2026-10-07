import { deviceCalendarDraft } from '../main/ets/model/DeviceCalendar';
import { describe, it, expect } from '@ohos/hypium';
import { CosEvent } from '../main/ets/model/Entities';
import { calendarDays, eventsOnDate, checkSchedule, reminderTime } from '../main/ets/model/Schedule';
import { makePreparation, preparationKeys } from '../main/ets/model/Preparation';
import { EventSaveCoordinator } from '../main/ets/common/EventSaveCoordinator';

export default function planningRulesTest(): void {
  describe('PlanningRules', () => {
    it('deviceCalendarAllDayIncludesLastDateWithExclusiveEnd', 0, () => {
      const event = new CosEvent(); event.name = '多日活动'; event.date = '2026-12-31'; event.endDate = '2027-01-02'; event.dateMode = 'multiple';
      const draft = deviceCalendarDraft(event);
      expect(draft.isAllDay).assertTrue(); expect(draft.endTime).assertEqual(new Date('2027-01-03T00:00:00').getTime());
      expect(draft.reminderTime[0]).assertEqual(30);
    });
    it('deviceCalendarKeepsTimeRangeLocationNotesAndChosenReminder', 0, () => {
      const event = new CosEvent(); event.name = '外景'; event.date = '2026-10-14'; event.timeMode = 'range'; event.startTime = '09:00'; event.endTime = '11:30'; event.city = '杭州'; event.venue = '公园'; event.notes = '带道具'; event.reminderMinutes = 60;
      const draft = deviceCalendarDraft(event);
      expect(draft.endTime - draft.startTime).assertEqual(150 * 60000); expect(draft.location).assertEqual('杭州 · 公园'); expect(draft.description).assertEqual('带道具'); expect(draft.reminderTime[0]).assertEqual(60);
    });
    it('deviceCalendarStartOnlyDefaultsOneHourAndRejectsPending', 0, () => {
      const event = new CosEvent(); event.name = '拍摄'; event.date = '2026-10-14'; event.timeMode = 'start'; event.startTime = '23:30';
      const draft = deviceCalendarDraft(event); expect(draft.endTime - draft.startTime).assertEqual(3600000);
      event.dateMode = 'pending'; event.date = ''; event.timeMode = 'none'; event.startTime = '';
      let rejected = false; try { deviceCalendarDraft(event); } catch (error) { rejected = true; } expect(rejected).assertTrue();
    });
    it('reuseTemplateSkipsPurchasesAndHonorsIndividualChoices', 0, () => {
      const keys = preparationKeys(2); expect(keys.length).assertEqual(6); expect(keys.includes('shoe-fit')).assertTrue(); expect(keys.includes('shoe-buy')).assertFalse();
      const bundle = makePreparation('p', keys.filter((key: string) => key !== 'photographer'));
      expect(bundle.tasks.length).assertEqual(5); expect(bundle.tasks.some((t) => t.label === '购买')).assertFalse();
      expect(makePreparation('p', []).categories.length).assertEqual(0);
    });
    it('calendarUsesMondayAndCoversLeapDaysAndYearBoundaries', 0, () => {
      const days = calendarDays(2024, 1); expect(days.length).assertEqual(42);
      expect(days[0].date).assertEqual('2024-01-29'); expect(days.some((d) => d.date === '2024-02-29' && d.currentMonth)).assertTrue();
      expect(calendarDays(2026, 0)[0].date).assertEqual('2025-12-29');
    });
    it('multidayEventsAppearOnEveryCoveredDayAndPendingStayOffCalendar', 0, () => {
      const multiple = new CosEvent(); multiple.date = '2026-10-07'; multiple.endDate = '2026-10-09'; multiple.dateMode = 'multiple';
      const pending = new CosEvent(); pending.dateMode = 'pending';
      for (const date of ['2026-10-07', '2026-10-08', '2026-10-09']) { expect(eventsOnDate([multiple, pending], date).length).assertEqual(1); }
      expect(eventsOnDate([multiple, pending], '2026-10-10').length).assertEqual(0);
    });
    it('scheduleRejectsInvalidDatesTimesAndPendingReminders', 0, () => {
      const event = new CosEvent(); event.date = '2026-10-07'; event.dateMode = 'multiple'; event.endDate = '2026-10-06';
      let rejected = 0; try { checkSchedule(event); } catch (error) { rejected++; }
      event.endDate = '2026-10-07'; event.timeMode = 'range'; event.startTime = '12:00'; event.endTime = '09:00';
      try { checkSchedule(event); } catch (error) { rejected++; }
      event.timeMode = 'start'; event.startTime = '24:00'; event.endTime = '';
      try { checkSchedule(event); } catch (error) { rejected++; }
      event.dateMode = 'pending'; event.date = ''; event.endDate = ''; event.timeMode = 'none'; event.startTime = ''; event.reminderMinutes = 30;
      try { checkSchedule(event); } catch (error) { rejected++; }
      expect(rejected).assertEqual(4);
      event.reminderMinutes = -1; checkSchedule(event);
    });
    it('allDayReminderUsesNineAndLeadTimeCrossesMidnight', 0, () => {
      const event = new CosEvent(); event.date = '2026-10-08'; event.reminderMinutes = 1440;
      expect(reminderTime(event)).assertEqual(new Date('2026-10-07T09:00:00').getTime());
      event.timeMode = 'start'; event.startTime = '00:15'; event.reminderMinutes = 30;
      expect(reminderTime(event)).assertEqual(new Date('2026-10-07T23:45:00').getTime());
    });
    it('permissionFailureSavesActivityWithReminderDisabled', 0, async () => {
      let persisted: CosEvent = new CosEvent();
      const event = new CosEvent(); event.date = '2027-01-01'; event.reminderMinutes = 30;
      const save = new EventSaveCoordinator(async (e: CosEvent): Promise<void> => { persisted = e; }, async (): Promise<number> => { throw new Error('通知未授权'); }, async (): Promise<void> => {});
      expect((await save.save(event)).length > 0).assertTrue(); expect(persisted.reminderId).assertEqual(-1); expect(persisted.reminderMinutes).assertEqual(-1);
    });
    it('failedPersistenceCancelsNewReminderAndKeepsOldReminder', 0, async () => {
      const old = new CosEvent(); old.date = '2027-01-01'; old.reminderId = 12; old.reminderMinutes = 30;
      const event = JSON.parse(JSON.stringify(old)) as CosEvent; event.date = '2027-01-02';
      const canceled: number[] = [];
      const save = new EventSaveCoordinator(async (): Promise<void> => { throw new Error('DB failure'); }, async (): Promise<number> => 15, async (id: number): Promise<void> => { canceled.push(id); });
      let rejected = false; try { await save.save(event, old); } catch (error) { rejected = true; }
      expect(rejected).assertTrue(); expect(canceled.length).assertEqual(1); expect(canceled[0]).assertEqual(15); expect(old.reminderId).assertEqual(12);
    });
    it('unchangedReminderAvoidsRepeatedAuthorizationAndReplacementCancelsOld', 0, async () => {
      const old = new CosEvent(); old.date = '2027-01-01'; old.reminderId = 12; old.reminderMinutes = 30;
      const event = JSON.parse(JSON.stringify(old)) as CosEvent;
      let published = 0; const canceled: number[] = [];
      const save = new EventSaveCoordinator(async (): Promise<void> => {}, async (): Promise<number> => { published++; return 15; }, async (id: number): Promise<void> => { canceled.push(id); });
      await save.save(event, old); expect(published).assertEqual(0); expect(canceled.length).assertEqual(0);
      event.date = '2027-01-02'; await save.save(event, old); expect(published).assertEqual(1); expect(event.reminderId).assertEqual(15); expect(canceled[0]).assertEqual(12);
    });
  });
}
