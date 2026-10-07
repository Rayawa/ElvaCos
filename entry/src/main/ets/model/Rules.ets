import {
  Asset,
  AssetStatus,
  ChecklistItem,
  CosProject,
  CosEvent,
  PhotoAsset,
  PhotoStatus,
  ProjectStatus,
  ProjectAsset,
  ProjectProgress,
} from './Entities';

export function requiredName(value: string): string {
  const name = value.trim();
  if (name.length === 0 || name.length > 80) { throw new Error('名称需要 1–80 个字'); }
  return name;
}
export function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) { return false; }
  const date = new Date(value + 'T12:00:00');
  return !isNaN(date.getTime()) && date.getFullYear() === Number(value.slice(0, 4)) && date.getMonth() + 1 === Number(value.slice(5, 7)) && date.getDate() === Number(value.slice(8, 10));
}
export function moneyToCents(value: string): number {
  if (!/^\d{1,7}(\.\d{1,2})?$/.test(value.trim())) { throw new Error('金额请输入非负数字，最多两位小数'); }
  return Math.round(Number(value) * 100);
}
export function safeUrl(value: string): string {
  const url = value.trim();
  if (url.length > 0 && !/^https?:\/\/[^\s]+$/i.test(url)) { throw new Error('链接需要以 https:// 或 http:// 开头'); }
  return url;
}
export function projectProgress(id: string, links: ProjectAsset[], assets: Asset[]): ProjectProgress {
  const ids = links.filter((link: ProjectAsset) => link.projectId === id).map((link: ProjectAsset) => link.assetId);
  const ready = assets.filter((asset: Asset) => ids.includes(asset.id) && asset.status === AssetStatus.OWNED).length;
  return { ready: ready, total: ids.length, percent: ids.length === 0 ? 0 : Math.round(ready * 100 / ids.length) };
}
export function checklistProgress(items: ChecklistItem[]): number {
  return items.length === 0 ? 0 : Math.round(items.filter((item: ChecklistItem) => item.done).length * 100 / items.length);
}
export function checkProjectDate(project: CosProject): void {
  if (project.targetDate !== '' && !validDate(project.targetDate)) { throw new Error('目标日期格式为 YYYY-MM-DD'); }
}

export function planDate(project: CosProject, events: CosEvent[]): string {
  return project.targetDate || events.find((event: CosEvent) => event.id === project.eventId)?.date || '';
}

export function nextPlan(projects: CosProject[], events: CosEvent[], date: string): CosProject | undefined {
  return projects.filter((project: CosProject) => project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED)
    .sort((a: CosProject, b: CosProject) => {
      const ad = planDate(a, events); const bd = planDate(b, events);
      // Upcoming dates first, overdue work next, undated plans last.
      const ag = !ad ? 2 : ad < date ? 1 : 0; const bg = !bd ? 2 : bd < date ? 1 : 0;
      return ag - bg || (ag === 1 ? bd.localeCompare(ad) : ad.localeCompare(bd)) || b.updatedAt - a.updatedAt || a.id.localeCompare(b.id);
    })[0];
}

export function photoStage(photos: PhotoAsset[], filter: number): PhotoAsset[] {
  return photos.filter((photo: PhotoAsset) => filter === 0 ||
    (filter === 1 && (photo.status === PhotoStatus.IMPORTED || photo.status === PhotoStatus.RAW)) ||
    (filter === 2 && photo.status === PhotoStatus.SELECTED) ||
    (filter === 3 && photo.status === PhotoStatus.WAITING) ||
    (filter === 4 && (photo.status === PhotoStatus.RETOUCHED || photo.status === PhotoStatus.FINAL || photo.status === PhotoStatus.PUBLISHED)));
}
