import { CosEvent } from '../model/Entities';
import { EventReminderService } from './EventReminderService';

// An unavailable notification service must never prevent saving core activity data.
// Publish new -> persist new ID -> cancel old. A failed DB write cancels only new.
export class EventSaveCoordinator {
  private persist: (event: CosEvent) => Promise<void>;
  private publish: (event: CosEvent) => Promise<number>;
  private cancel: (id: number) => Promise<void>;
  constructor(persist: (event: CosEvent) => Promise<void>, publish: (event: CosEvent) => Promise<number>, cancel: (id: number) => Promise<void>) {
    this.persist = persist; this.publish = publish; this.cancel = cancel;
  }
  async save(item: CosEvent, old?: CosEvent): Promise<string> {
    let newId = -1; let warning = '';
    if (old && EventReminderService.same(item, old)) { item.reminderId = old.reminderId; }
    else {
      item.reminderId = -1;
      if (item.reminderMinutes >= 0) {
        try { newId = await this.publish(item); item.reminderId = newId; }
        catch (error) { warning = EventReminderService.failure(error as Error); item.reminderMinutes = -1; }
      }
    }
    try { await this.persist(item); }
    catch (error) { if (newId >= 0) { try { await this.cancel(newId); } catch (cleanupError) {} } throw error as Error; }
    if (old && old.reminderId !== item.reminderId) {
      try { await this.cancel(old.reminderId); } catch (error) { warning = '活动已保存，旧提醒取消失败，重新打开应用后会再次清理。'; }
    }
    return warning;
  }
}
