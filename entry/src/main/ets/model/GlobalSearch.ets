import { Character, CharacterVariant, CosProject, CosEvent, Asset, PhotoAsset } from './Entities';
import { CollectedEntry, entryTitle } from './CollectedEntry';
import { planDate } from './Rules';
import { photoStatusLabel } from './PhotoStages';

export const SEARCH_SECTIONS: string[] = ['计划', '角色', '日程', '资源'];
export const SEARCH_RESOURCE_KINDS: string[] = ['', 'asset', 'photo', 'entry'];
export const SEARCH_RESOURCE_LABELS: string[] = ['全部资源', '装备', '照片', '收录'];
export interface SearchData {
  projects: CosProject[];
  characters: Character[];
  variants: CharacterVariant[];
  events: CosEvent[];
  assets: Asset[];
  photos: PhotoAsset[];
  entries: CollectedEntry[];
}
export class SearchHit {
  kind: string;
  id: string;
  title: string;
  detail: string;
  ownerKind: string = '';
  ownerId: string = '';
  variantId: string = '';
  entryKind: string = '';
  constructor(kind: string, id: string, title: string, detail: string) { this.kind = kind; this.id = id; this.title = title; this.detail = detail; }
  key(): string { return this.kind + ':' + this.id; }
}
export class SearchSummary {
  sections: SearchHit[][] = [[], [], [], []];
}
@ObservedV2
export class SearchRoute {
  @Trace query: string = '';
  @Trace section: number = 0;
  @Trace resourceKind: string = '';
  @Trace restoreVersion: number = 0;
  @Trace feedback: string = '';
  offsets: number[] = [0, 0, 0, 0];
  anchorKey: string = '';
  setQuery(value: string): void {
    if (value === this.query) { return; }
    this.query = value; this.offsets = [0, 0, 0, 0]; this.anchorKey = ''; this.feedback = ''; this.restoreVersion++;
  }
  setSection(value: number): void {
    if (!Number.isInteger(value) || value < 0 || value >= SEARCH_SECTIONS.length || value === this.section) { return; }
    this.section = value; this.anchorKey = ''; this.feedback = ''; this.restoreVersion++;
  }
  setResourceKind(value: string): void {
    if (!SEARCH_RESOURCE_KINDS.includes(value) || value === this.resourceKind) { return; }
    this.resourceKind = value; this.offsets[3] = 0; this.anchorKey = ''; this.feedback = ''; this.restoreVersion++;
  }
  reconcile(hits: SearchHit[]): void {
    if (this.anchorKey && !hits.some((hit: SearchHit) => hit.key() === this.anchorKey)) {
      this.anchorKey = ''; this.feedback = '原结果已离开当前范围，保留关键词与附近位置。';
    }
  }
}
export function searchRows(summary: SearchSummary, route: SearchRoute): SearchHit[] {
  return (summary.sections[route.section] || []).filter((hit: SearchHit) => route.section !== 3 || !route.resourceKind || hit.kind === route.resourceKind);
}
export function globalSearch(data: SearchData, query: string): SearchSummary {
  const summary = new SearchSummary();
  const terms = query.trim().toLocaleLowerCase().split(/\s+/).filter((term: string) => !!term);
  if (!terms.length) { return summary; }
  const matches = (text: string): boolean => terms.every((term: string) => text.toLocaleLowerCase().includes(term));
  const characters = new Map<string, Character>(); data.characters.forEach((value: Character): void => { characters.set(value.id, value); });
  const projects = new Map<string, CosProject>(); data.projects.forEach((value: CosProject): void => { projects.set(value.id, value); });
  const events = new Map<string, CosEvent>(); data.events.forEach((value: CosEvent): void => { events.set(value.id, value); });
  const assets = new Map<string, Asset>(); data.assets.forEach((value: Asset): void => { assets.set(value.id, value); });
  const variants = new Map<string, CharacterVariant[]>();
  data.variants.forEach((value: CharacterVariant): void => { const group = variants.get(value.characterId) || []; group.push(value); variants.set(value.characterId, group); });
  for (const project of data.projects) {
    const character = characters.get(project.characterId);
    const variant = (variants.get(project.characterId) || []).find((value: CharacterVariant) => value.id === project.variantId);
    const event = events.get(project.eventId);
    const detail = [character?.name || '角色已不存在', variant?.name || '', event?.name || '', planDate(project, data.events) || '日期待定'].filter((value: string) => !!value).join(' · ');
    if (matches(project.name + ' ' + detail + ' ' + project.notes + ' ' + (character?.workName || ''))) { summary.sections[0].push(new SearchHit('project', project.id, project.name, detail)); }
  }
  for (const character of data.characters) {
    const group = variants.get(character.id) || [];
    const base = character.name + ' ' + character.workName + ' ' + character.description;
    const variantText = group.map((value: CharacterVariant) => value.name + ' ' + value.notes).join(' ');
    if (!matches(base + ' ' + variantText)) { continue; }
    const hit = new SearchHit('character', character.id, character.name, [character.workName, group.map((value: CharacterVariant) => value.name).join(' / ')].filter((value: string) => !!value).join(' · ') || '角色资料');
    const matched = group.filter((value: CharacterVariant) => matches(base + ' ' + value.name + ' ' + value.notes));
    if (!matches(base) && matched.length === 1) { hit.variantId = matched[0].id; }
    summary.sections[1].push(hit);
  }
  for (const event of data.events) {
    const detail = [event.dateMode === 'pending' ? '日期待定' : event.date, event.city, event.venue, event.eventType].filter((value: string) => !!value).join(' · ');
    if (matches(event.name + ' ' + detail + ' ' + event.notes)) { summary.sections[2].push(new SearchHit('event', event.id, event.name, detail)); }
  }
  for (const asset of data.assets) {
    if (matches([asset.name, asset.location, asset.brand, asset.size, asset.notes].join(' '))) { summary.sections[3].push(new SearchHit('asset', asset.id, asset.name, '装备 · ' + (asset.location || '位置待补充'))); }
  }
  for (const photo of data.photos) {
    const project = projects.get(photo.projectId); if (!project) { continue; }
    const character = characters.get(project.characterId);
    if (!matches([photo.caption, project.name, character?.name || '', character?.workName || ''].join(' '))) { continue; }
    const hit = new SearchHit('photo', photo.id, photo.caption || project.name + '的照片', '照片 · ' + project.name + ' · ' + photoStatusLabel(photo.status));
    hit.ownerKind = 'project'; hit.ownerId = project.id; summary.sections[3].push(hit);
  }
  for (const entry of data.entries) {
    const owner = entry.scopeKind === 'project' ? projects.get(entry.scopeId)?.name : entry.scopeKind === 'character' ? characters.get(entry.scopeId)?.name : entry.scopeKind === 'event' ? events.get(entry.scopeId)?.name : entry.scopeKind === 'asset' ? assets.get(entry.scopeId)?.name : '未归位';
    if (entry.scopeKind !== 'global' && !owner) { continue; }
    if (!matches([entry.title, entry.text, entry.url, owner || ''].join(' '))) { continue; }
    const hit = new SearchHit('entry', entry.id, entryTitle(entry).slice(0, 80), '收录 · ' + owner + ' · 查看所属收录');
    hit.ownerKind = entry.scopeKind; hit.ownerId = entry.scopeId; hit.entryKind = entry.kind; summary.sections[3].push(hit);
  }
  summary.sections.forEach((hits: SearchHit[]): void => { hits.sort((a: SearchHit, b: SearchHit) => a.title.localeCompare(b.title) || a.key().localeCompare(b.key())); });
  return summary;
}
