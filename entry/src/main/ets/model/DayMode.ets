import { PlanReadiness } from './PlanReadiness';
import { CosEvent, CosProject } from './Entities';
import { CollectedEntry } from './CollectedEntry';
import { TeamMember } from './Planning';
import { eventEnd, reminderTime } from './Schedule';

export interface DayModuleOption { enabled: boolean; order: number; }
export type DayModulePreferences = Record<string, DayModuleOption>;
export class DayModule {
  id: string; label: string; section: number; order: number;
  constructor(id: string, label: string, section: number, order: number) {
    this.id = id; this.label = label; this.section = section; this.order = order;
  }
}
export const DAY_MODULES: DayModule[] = [
  new DayModule('packing', '出发前', 0, 0), new DayModule('credentials', '凭证', 0, 1), new DayModule('people', '人', 0, 2),
  new DayModule('plans', '今天要做', 1, 0), new DayModule('shots', '今天要拍', 1, 1), new DayModule('timeline', '时间线', 1, 2), new DayModule('wrapup', '收尾', 1, 3)
];
export function localDay(now: number): string {
  const date = new Date(now);
  return String(date.getFullYear()).padStart(4, '0') + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0');
}
export function dayWindow(event: CosEvent, now: number): boolean {
  if (event.dateMode === 'pending' || !event.date || !eventEnd(event)) { return false; }
  const start = new Date(event.date + 'T20:00:00'); start.setDate(start.getDate() - 1);
  const end = new Date(eventEnd(event) + 'T00:00:00'); end.setDate(end.getDate() + 1);
  return now >= start.getTime() && now < end.getTime();
}
export function dayEntries(events: CosEvent[], dismissed: Record<string, string>, now: number): CosEvent[] {
  const date = localDay(now);
  return events.filter((event: CosEvent) => dayWindow(event, now) && dismissed[event.id] !== date)
    .sort((a: CosEvent, b: CosEvent) => {
      // Ongoing activities precede tomorrow; for today's starts, the next future
      // start precedes elapsed starts, then stable date/time/name/ID ties.
      const rank = (event: CosEvent): number => {
        if (event.date > date) { return 2; }
        return event.date < date || !event.startTime || event.startTime > new Date(now).toTimeString().slice(0, 5) ? 0 : 1;
      };
      return rank(a) - rank(b) || a.date.localeCompare(b.date) || a.startTime.localeCompare(b.startTime) || a.name.localeCompare(b.name) || a.id.localeCompare(b.id);
    });
}
export function dayTitle(event: CosEvent, now: number): string {
  const date = localDay(now);
  return (event.date > date && dayWindow(event, now) ? '明天' : event.date <= date && eventEnd(event) >= date ? '今天' : event.dateMode === 'pending' ? '日期待定' : event.date) + ' · ' + event.name;
}
export function dayNumber(event: CosEvent, now: number): string {
  if (event.dateMode !== 'multiple' || localDay(now) < event.date || localDay(now) > eventEnd(event)) { return ''; }
  const start = new Date(event.date + 'T12:00:00'); const date = new Date(localDay(now) + 'T12:00:00');
  return '第 ' + (Math.round((date.getTime() - start.getTime()) / 86400000) + 1) + ' 天';
}
export function parseDayModules(json: string): DayModulePreferences {
  const result: DayModulePreferences = {};
  try {
    const stored = JSON.parse(json) as DayModulePreferences;
    for (const module of DAY_MODULES) {
      const option = stored[module.id];
      if (option && typeof option.enabled === 'boolean' && typeof option.order === 'number' && Number.isFinite(option.order)) {
        result[module.id] = { enabled: option.enabled, order: Math.max(0, Math.min(20, Math.floor(option.order))) };
      }
    }
  } catch (error) { }
  return result;
}
export function orderedDayModules(preferences: DayModulePreferences, section: number): DayModule[] {
  return DAY_MODULES.filter((module: DayModule) => module.section === section)
    .sort((a: DayModule, b: DayModule) => (preferences[a.id]?.order ?? a.order) - (preferences[b.id]?.order ?? b.order) || a.order - b.order);
}
export function hasEventShots(eventId: string, projects: CosProject[], plans: PlanReadiness[]): boolean { return projects.some((project: CosProject) => project.eventId === eventId && (plans.find((plan: PlanReadiness) => plan.id === project.id)?.shots.total || 0) > 0); }
export function availableDayModules(event: CosEvent, projects: CosProject[], entries: CollectedEntry[], team: TeamMember[], now: number, hasShots: boolean = false): string[] {
  const ids = projects.filter((project: CosProject) => project.eventId === event.id).map((project: CosProject) => project.id);
  const modules: string[] = [];
  if (ids.length) { modules.push('packing', 'plans'); }
  if (entries.some((entry: CollectedEntry) => entry.scopeKind === 'event' && entry.scopeId === event.id && ['ticket', 'map', 'link'].includes(entry.kind))) { modules.push('credentials'); }
  if (team.some((member: TeamMember) => ids.includes(member.projectId))) { modules.push('people'); }
  if (hasShots) { modules.push('shots'); }
  if (event.startTime) { modules.push('timeline'); }
  if (event.dateMode !== 'pending' && event.date <= localDay(now) && eventEnd(event) >= localDay(now) && new Date(now).getHours() >= 18) { modules.push('wrapup'); }
  return modules;
}
export function assembledDayModules(available: string[], preferences: DayModulePreferences, section: number): DayModule[] {
  return orderedDayModules(preferences, section).filter((module: DayModule) => available.includes(module.id) && preferences[module.id]?.enabled !== false);
}
export function reminderState(event: CosEvent, now: number): string {
  if (event.reminderMinutes < 0) { return '未选择提醒'; }
  if (reminderTime(event) <= now) { return '提醒时间已过'; }
  return event.reminderId >= 0 ? '系统提醒已建立' : '已选择提醒，系统提醒未建立；请检查通知权限并重试';
}
