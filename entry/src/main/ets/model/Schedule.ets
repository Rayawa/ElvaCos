import { DATE_MODES, TIME_MODES } from '../common/constants';
import { CosEvent } from './Entities';
import { validDate, requiredName } from './Rules';

export function validTime(value: string): boolean { return /^([01]\d|2[0-3]):[0-5]\d$/.test(value); }
export function checkSchedule(event: CosEvent): void {
  requiredName(event.eventType);
  if (!DATE_MODES.includes(event.dateMode) || !TIME_MODES.includes(event.timeMode)) { throw new Error('活动日期或时间模式无效'); }
  if (event.dateMode === 'pending') {
    if (event.date || event.endDate || event.timeMode !== 'none' || event.startTime || event.endTime || event.reminderMinutes !== -1) { 
      throw new Error('日期待定时请关闭时间与提醒'); }
    return;
  }
  if (!validDate(event.date)) { throw new Error('活动日期格式为 YYYY-MM-DD'); }
  if (event.dateMode === 'multiple') {
    if (!validDate(event.endDate) || event.endDate < event.date) { throw new Error('结束日期应不早于开始日期'); }
  } else if (event.endDate) { throw new Error('单日活动无需结束日期'); }
  if (event.timeMode === 'none') {
    if (event.startTime || event.endTime) { throw new Error('不标记时间时请清除时间'); }
  } else {
    if (!validTime(event.startTime)) { throw new Error('开始时间格式为 HH:mm'); }
    if (event.timeMode === 'range') {
      if (!validTime(event.endTime) || ((event.dateMode === 'single' || event.endDate === event.date) && event.endTime <= event.startTime)) { 
        throw new Error('结束时间应晚于开始时间'); }
    } else if (event.endTime) { throw new Error('仅标记开始时间时无需结束时间'); }
  }
  if (![-1, 0, 30, 60, 1440].includes(event.reminderMinutes)) { throw new Error('提醒提前时间无效'); }
}
export function eventEnd(event: CosEvent): string { return event.dateMode === 'multiple' ? event.endDate : event.date; }
export function eventDateLabel(event: CosEvent): string { 
  return event.dateMode === 'pending' ? '日期待定' : event.date + (event.dateMode === 'multiple' ? ' ～ ' + event.endDate : ''); }
export function eventTimeLabel(event: CosEvent): string { 
  return event.timeMode === 'none' ? '未标记时间' : event.startTime + (event.timeMode === 'range' ? ' ～ ' + event.endTime : ''); }
export function eventsOnDate(events: CosEvent[], date: string): CosEvent[] {
  return events.filter((event: CosEvent) => event.dateMode !== 'pending' && event.date <= date && eventEnd(event) >= date)
    .sort((a: CosEvent, b: CosEvent) => a.startTime.localeCompare(b.startTime) || a.name.localeCompare(b.name));
}
export function reminderTime(event: CosEvent): number {
  checkSchedule(event);
  if (event.reminderMinutes < 0 || event.dateMode === 'pending') { return 0; }
  return new Date(event.date + 'T' + (event.timeMode === 'none' ? '09:00' : event.startTime) + ':00').getTime() - event.reminderMinutes * 60000;
}
export class CalendarDay {
  date: string;
  day: number;
  currentMonth: boolean;
  constructor(date: string, day: number, currentMonth: boolean) { this.date = date; this.day = day; this.currentMonth = currentMonth; }
}
export function calendarDays(year: number, month: number): CalendarDay[] {
  const first = new Date(year, month, 1, 12); const mondayOffset = (first.getDay() + 6) % 7;
  const days: CalendarDay[] = [];
  for (let i = 0; i < 42; i++) {
    const date = new Date(year, month, 1 - mondayOffset + i, 12);
    const key = String(date.getFullYear())
      .padStart(4, '0') + '-' + String(date.getMonth() + 1)
      .padStart(2, '0') + '-' + String(date.getDate())
      .padStart(2, '0');
    days.push(new CalendarDay(key, date.getDate(), date.getMonth() === month && date.getFullYear() === year));
  } return days;
}
