import { calendarManager } from '@kit.CalendarKit';
import { common } from '@kit.AbilityKit';
import { CosEvent } from '../model/Entities';
import { deviceCalendarDraft } from '../model/DeviceCalendar';

// API 12, CalendarData; editEvent is a user-confirmed system page and requires
// no calendar read/write permission. The user chooses the destination account.
export class DeviceCalendarService {
  async add(event: CosEvent, context: common.UIAbilityContext): Promise<boolean> {
    if (!canIUse('SystemCapability.Applications.CalendarData')) { throw new Error('当前设备不支持系统日历'); }
    const draft = deviceCalendarDraft(event);
    const request: calendarManager.Event = {
      type: calendarManager.EventType.NORMAL, title: draft.title,
      startTime: draft.startTime, endTime: draft.endTime, isAllDay: draft.isAllDay,
      location: { location: draft.location }, description: draft.description,
      reminderTime: draft.reminderTime
    };
    const id = await calendarManager.getCalendarManager(context).editEvent(request);
    if (id === 0) { throw new Error('日历未返回有效结果，请检查系统日历'); }
    return id > 0;
  }
}
