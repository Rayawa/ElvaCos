import { DATE_MODES, TIME_MODES } from './constants';
import { CosEvent } from './Entities';
import { validDate, requiredName, validTime } from './Rules';

export { validTime } from './Rules';

export class ScheduleError extends Error {
    field: string;

    constructor(field: string, message: string) {
        super(message);
        this.field = field;
    }
}

export function checkSchedule(event: CosEvent): void {
    try {
        requiredName(event.eventType);
    } catch (error) {
        throw new ScheduleError('type', (error as Error).message);
    }
    if (!DATE_MODES.includes(event.dateMode)) {
        throw new ScheduleError('dateMode', '活动日期模式无效');
    }
    if (!TIME_MODES.includes(event.timeMode)) {
        throw new ScheduleError('timeMode', '活动时间模式无效');
    }
    if (event.dateMode === 'pending') {
        if (event.date || event.endDate || event.timeMode !== 'none' || event.startTime || event.endTime || event.reminderMinutes !== -1) {
            throw new ScheduleError('dateMode', '日期待定时请关闭时间与提醒');
        }
        return;
    }
    if (!validDate(event.date)) {
        throw new ScheduleError('date', '活动日期格式为 YYYY-MM-DD');
    }
    if (event.dateMode === 'multiple') {
        if (!validDate(event.endDate) || event.endDate < event.date) {
            throw new ScheduleError('endDate', '结束日期应不早于开始日期');
        }
    } else if (event.endDate) {
        throw new ScheduleError('dateMode', '单日活动无需结束日期');
    }
    if (event.timeMode === 'none') {
        if (event.startTime || event.endTime) {
            throw new ScheduleError('timeMode', '不标记时间时请清除时间');
        }
    } else {
        if (!validTime(event.startTime)) {
            throw new ScheduleError('startTime', '开始时间格式为 HH:mm');
        }
        if (event.timeMode === 'range') {
            if (!validTime(event.endTime) || ((event.dateMode === 'single' || event.endDate === event.date) && event.endTime <= event.startTime)) {
                throw new ScheduleError('endTime', '结束时间应晚于开始时间');
            }
        } else if (event.endTime) {
            throw new ScheduleError('timeMode', '仅标记开始时间时无需结束时间');
        }
    }
    if (![-1, 0, 30, 60, 1440].includes(event.reminderMinutes)) {
        throw new ScheduleError('reminderMinutes', '提醒提前时间无效');
    }
}

export function eventEnd(event: CosEvent): string {
    return event.dateMode === 'multiple' ? event.endDate : event.date;
}

export function eventDateLabel(event: CosEvent): string {
    return event.dateMode === 'pending' ? '日期待定' : event.date + (event.dateMode === 'multiple' ? ' ～ ' + event.endDate : '');
}

export function eventTimeLabel(event: CosEvent): string {
    return event.timeMode === 'none' ? '未标记时间' : event.startTime + (event.timeMode === 'range' ? ' ～ ' + event.endTime : '');
}

export function eventsOnDate(events: CosEvent[], date: string): CosEvent[] {
    return events.filter((event: CosEvent) => event.dateMode !== 'pending' && event.date <= date && eventEnd(event) >= date)
        .sort((a: CosEvent, b: CosEvent) => a.startTime.localeCompare(b.startTime) || a.name.localeCompare(b.name));
}

export class ScheduleGroup {
    label: string;
    events: CosEvent[];

    constructor(label: string, events: CosEvent[]) {
        this.label = label;
        this.events = events;
    }
}

export function schedulePhase(event: CosEvent, date: string): 'pending' | 'past' | 'today' | 'upcoming' {
    if (event.dateMode === 'pending' || !event.date) {
        return 'pending';
    }
    if (event.status === 'Attended' || eventEnd(event) < date) {
        return 'past';
    }
    return event.date <= date ? 'today' : 'upcoming';
}

export function scheduleGroups(events: CosEvent[], date: string): ScheduleGroup[] {
    const groups = [new ScheduleGroup('今天', []), new ScheduleGroup('即将到来', []),
        new ScheduleGroup('日期待定', []), new ScheduleGroup('已结束', [])];
    for (const event of events) {
        const phase = schedulePhase(event, date);
        const index = phase === 'today' ? 0 : phase === 'upcoming' ? 1 : phase === 'pending' ? 2 : 3;
        groups[index].events.push(event);
    }
    const sort = (a: CosEvent, b: CosEvent): number => a.date.localeCompare(b.date) || a.startTime.localeCompare(b.startTime) || a.name.localeCompare(b.name);
    groups[0].events.sort(sort);
    groups[1].events.sort(sort);
    groups[2].events.sort((a: CosEvent, b: CosEvent): number => a.name.localeCompare(b.name));
    groups[3].events.sort((a: CosEvent, b: CosEvent): number => -sort(a, b));
    return groups;
}

export function reminderTime(event: CosEvent): number {
    checkSchedule(event);
    if (event.reminderMinutes < 0 || event.dateMode === 'pending') {
        return 0;
    }
    return new Date(event.date + 'T' + (event.timeMode === 'none' ? '09:00' : event.startTime) + ':00')
        .getTime() - event.reminderMinutes * 60000;
}

export class CalendarDay {
    date: string;
    day: number;
    currentMonth: boolean;

    constructor(date: string, day: number, currentMonth: boolean) {
        this.date = date;
        this.day = day;
        this.currentMonth = currentMonth;
    }
}

export function calendarDays(year: number, month: number): CalendarDay[] {
    const first = new Date(year, month, 1, 12);
    const mondayOffset = (first.getDay() + 6) % 7;
    const days: CalendarDay[] = [];
    for (let i = 0; i < 42; i++) {
        const date = new Date(year, month, 1 - mondayOffset + i, 12);
        const key = String(date.getFullYear())
            .padStart(4, '0') + '-' + String(date.getMonth() + 1)
            .padStart(2, '0') + '-' + String(date.getDate())
            .padStart(2, '0');
        days.push(new CalendarDay(key, date.getDate(), date.getMonth() === month && date.getFullYear() === year));
    }
    return days;
}
