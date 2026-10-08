import { Asset, AssetType, AssetStatus, ChecklistItem, CosProject, ProjectAsset } from './Entities';
import { CollectedEntry } from './CollectedEntry';
import { PlanReadiness } from './PlanReadiness';

@ObservedV2
export class WardrobeRoute {
  @Trace query: string = '';
  @Trace type: string = '';
  @Trace status: string = '';
  @Trace locationMode: string = 'all';
  @Trace location: string = '';
  @Trace restoreVersion: number = 0;
  @Trace feedback: string = '';
  offset: number = 0;
  anchorId: string = '';
  changed(): void { this.offset = 0; this.anchorId = ''; this.feedback = ''; this.restoreVersion++; }
  clear(): void { this.query = ''; this.type = ''; this.status = ''; this.locationMode = 'all'; this.location = ''; this.changed(); }
  get filtered(): boolean { return !!(this.query.trim() || this.type || this.status || this.locationMode !== 'all'); }
}
export function wardrobeLocations(assets: Asset[]): string[] {
  const values: string[] = [];
  for (const asset of assets) { const location = asset.location.trim(); if (location && !values.includes(location)) { values.push(location); } }
  return values.sort((a: string, b: string) => a.localeCompare(b));
}
export function wardrobeAssets(assets: Asset[], route: WardrobeRoute): Asset[] {
  const query = route.query.trim().toLocaleLowerCase();
  return assets.filter((asset: Asset) => (!query || (asset.name + ' ' + asset.location + ' ' + asset.brand).toLocaleLowerCase().includes(query)) &&
    (!route.type || asset.type === route.type as AssetType) && (!route.status || asset.status === route.status as AssetStatus) &&
    (route.locationMode === 'all' || route.locationMode === 'unrecorded' && !asset.location.trim() || route.locationMode === 'named' && asset.location.trim() === route.location));
}
export function assetRemovalKey(projectIds: string[], checklistIds: string[], entryIds: string[]): string {
  return JSON.stringify([projectIds.slice().sort(), checklistIds.slice().sort(), entryIds.slice().sort()]);
}
export class AssetUsage {
  id: string = '';
  projects: CosProject[] = [];
  activeProjects: CosProject[] = [];
  checklist: ChecklistItem[] = [];
  entryIds: string[] = [];
  get removalKey(): string { return assetRemovalKey(this.projects.map((project: CosProject) => project.id), this.checklist.map((item: ChecklistItem) => item.id), this.entryIds); }
  removalMessage(name: string): string {
    return '「' + name + '」将从衣柜永久删除，解除 ' + this.projects.length + ' 份计划关联。' +
      this.checklist.length + ' 条打包项保留名称与装包状态，取消装备引用。' +
      (this.entryIds.length ? this.entryIds.length + ' 条收录回到未归位。' : '') + '花费记录保留；此操作不能撤销。';
  }
  unlinkMessage(project: CosProject): string {
    return '仅解除「' + project.name + '」的装备关联，并移除该计划中 ' + this.checklist.filter((item: ChecklistItem) => item.projectId === project.id).length + ' 条对应打包项。衣柜装备和其他计划关联保留。';
  }
}
export function buildAssetUsage(assetId: string, projects: CosProject[], links: ProjectAsset[], checklist: ChecklistItem[], entries: CollectedEntry[], readiness: PlanReadiness[]): AssetUsage {
  const result = new AssetUsage(); result.id = assetId;
  const ids = links.filter((link: ProjectAsset) => link.assetId === assetId).map((link: ProjectAsset) => link.projectId);
  result.projects = projects.filter((project: CosProject) => ids.includes(project.id));
  result.activeProjects = result.projects.filter((project: CosProject) => readiness.some((item: PlanReadiness) => item.id === project.id && item.active));
  result.checklist = checklist.filter((item: ChecklistItem) => item.assetId === assetId);
  result.entryIds = entries.filter((entry: CollectedEntry) => entry.scopeKind === 'asset' && entry.scopeId === assetId).map((entry: CollectedEntry) => entry.id);
  return result;
}

/** Brief facts plus at most one use row can remain a single compact view. */
export function assetUsesSegments(asset: Asset, usage: AssetUsage): boolean {
  return usage.projects.length > 1 || usage.projects.length > 0 && !!(asset.brand || asset.size || asset.purchaseUrl || asset.notes);
}
