import { PlanReadiness } from './PlanReadiness';
import { CosProject, CosEvent, PhotoAsset, PhotoStatus } from './Entities';
export class AlbumPlan {
  id: string = '';
  name: string = '';
  event: string = '';
  date: string = '';
  counts: number[] = [];
  total: number = 0;
  cover?: PhotoAsset;
}
export class AlbumSummary {
  plans: AlbumPlan[] = [];
  counts: number[] = [0, 0, 0, 0, 0, 0];
  get total(): number { return this.counts.reduce((sum: number, count: number) => sum + count, 0); }
}
/** Album stage totals come from the exact same per-plan readiness as tasks. */
export function buildAlbumSummary(readiness: PlanReadiness[], projects: CosProject[], events: CosEvent[], photos: PhotoAsset[]): AlbumSummary {
  const summary = new AlbumSummary(); const stages = new Map<string, PlanReadiness>(); const byPlan = new Map<string, PhotoAsset[]>();
  readiness.forEach((value: PlanReadiness): void => { stages.set(value.id, value); });
  photos.forEach((photo: PhotoAsset): void => { const scoped = byPlan.get(photo.projectId) || []; scoped.push(photo); byPlan.set(photo.projectId, scoped); });
  for (const project of projects) {
    const value = stages.get(project.id); if (!value) { continue; }
    const plan = new AlbumPlan(); plan.id = project.id; plan.name = project.name; plan.date = value.date;
    plan.event = events.find((event: CosEvent) => event.id === project.eventId)?.name || '独立计划';
    plan.counts = value.photos.byStage.slice(); plan.total = value.photos.total;
    const scoped = byPlan.get(project.id) || []; plan.cover = scoped.find((photo: PhotoAsset) => [PhotoStatus.FINAL, PhotoStatus.PUBLISHED].includes(photo.status)) || scoped[0];
    plan.counts.forEach((count: number, index: number): void => { summary.counts[index] += count; }); summary.plans.push(plan);
  }
  summary.plans.sort((a: AlbumPlan, b: AlbumPlan) => (!a.date ? 1 : 0) - (!b.date ? 1 : 0) || b.date.localeCompare(a.date) || a.id.localeCompare(b.id)); return summary;
}
