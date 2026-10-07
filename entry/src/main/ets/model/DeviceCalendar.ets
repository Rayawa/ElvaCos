import { CosEvent } from './Entities';
import { checkSchedule, eventEnd } from './Schedule';
import { requiredName } from './Rules';

export class DeviceCalendarDraft {
  title: string = '';
  startTime: number = 0;
  endTime: number = 0;
  isAllDay: boolean = false;
  location: string = '';
  description: string = '';
  reminderTime: number[] = [];
}

// Calendar Kit uses an exclusive end for all-day events. Construct the next local
// midnight rather than adding 24 hours, which is incorrect on DST boundaries.
export function deviceCalendarDraft(event: CosEvent): DeviceCalendarDraft {
  checkSchedule(event);
  if (event.dateMode === 'pending') { throw new Error('请先确定活动日期，再添加到设备日历'); }
  const draft = new DeviceCalendarDraft(); draft.title = requiredName(event.name);
  draft.isAllDay = event.timeMode === 'none';
  draft.startTime = new Date(event.date + 'T' + (draft.isAllDay ? '00:00' : event.startTime) + ':00').getTime();
  const end = new Date(eventEnd(event) + 'T' + (draft.isAllDay ? '00:00' : event.timeMode === 'range' ? event.endTime : event.startTime) + ':00');
  if (draft.isAllDay) { end.setDate(end.getDate() + 1); }
  else if (event.timeMode === 'start') { end.setHours(end.getHours() + 1); }
  draft.endTime = end.getTime();
  draft.location = [event.city, event.venue].filter((value: string) => !!value).join(' · ');
  draft.description = [event.notes, event.url].filter((value: string) => !!value).join('\n');
  draft.reminderTime = [event.reminderMinutes >= 0 ? event.reminderMinutes : 30];
  return draft;
}
