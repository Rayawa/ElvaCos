import { AppState } from '../common/AppState';
import { Asset, Character, CharacterVariant, CosEvent, CosProject, AssetType, AssetStatus, ProjectStatus } from './Entities';
import { moneyToCents } from './Rules';
import { today } from '../common/Theme';

@ObservedV2
export class EditDraft {
  @Trace kind: string = '';
  @Trace id: string = '';
  @Trace parentId: string = '';
  @Trace name: string = '';
  @Trace work: string = '';
  @Trace notes: string = '';
  @Trace characterId: string = '';
  @Trace variantId: string = '';
  @Trace eventId: string = '';
  @Trace date: string = '';
  @Trace city: string = '';
  @Trace venue: string = '';
  @Trace url: string = '';
  @Trace location: string = '';
  @Trace brand: string = '';
  @Trace size: string = '';
  @Trace money: string = '0';
  @Trace status: string = '';
  @Trace type: string = '';
  @Trace ticket: boolean = false;
  @Trace newCharacter: boolean = false;
  @Trace characterName: string = '';
  @Trace advanced: boolean = false;
  static make(state: AppState, kind: string, id: string = '', parent: string = ''): EditDraft {
    const d = new EditDraft(); d.kind = kind; d.id = id; d.parentId = parent;
    if (kind === 'character') { const c = state.characters.find((item: Character) => item.id === id); if (c) { d.name = c.name; d.work = c.workName; d.notes = c.description; } }
    if (kind === 'variant') { const v = state.variants.find((item: CharacterVariant) => item.id === id); d.characterId = parent; if (v) { d.name = v.name; d.notes = v.notes; d.characterId = v.characterId; } }
    if (kind === 'project') {
      d.characterId = state.characters.some((c: Character) => c.id === parent) ? parent : state.characters[0]?.id || '';
      const event = state.events.find((e: CosEvent) => e.id === parent);
      if (event) { d.eventId = event.id; d.date = event.date; }
      d.newCharacter = !d.characterId; d.status = ProjectStatus.PREPARING;
      d.name = d.characterId ? state.characterName(d.characterId) + ' · Cos 计划' : '';
      const p = state.projects.find((item: CosProject) => item.id === id);
      if (p) { d.name = p.name; d.characterId = p.characterId; d.newCharacter = false; d.advanced = true; d.variantId = p.variantId; d.eventId = p.eventId; d.notes = p.notes; d.date = p.targetDate; d.money = String(p.budgetCents / 100); d.status = p.status; }
    }
    if (kind === 'asset') {
      d.type = AssetType.COSTUME; d.status = AssetStatus.OWNED;
      const a = state.assets.find((item: Asset) => item.id === id);
      if (a) { d.name = a.name; d.type = a.type; d.status = a.status; d.location = a.location; d.brand = a.brand; d.size = a.size; d.money = String(a.priceCents / 100); d.url = a.purchaseUrl; d.notes = a.notes; }
    }
    if (kind === 'event') {
      d.date = today(); d.status = 'Planned'; const e = state.events.find((item: CosEvent) => item.id === id);
      if (e) { d.name = e.name; d.date = e.date; d.city = e.city; d.venue = e.venue; d.url = e.url; d.status = e.status; d.ticket = e.ticketPurchased; d.notes = e.notes; }
    }
    return d;
  }
  async save(state: AppState): Promise<boolean> {
    if (this.kind === 'character') {
      const old = state.characters.find((c: Character) => c.id === this.id); const c = old ? JSON.parse(JSON.stringify(old)) as Character : new Character();
      c.name = this.name; c.workName = this.work; c.description = this.notes; return state.saveCharacter(c);
    }
    if (this.kind === 'variant') { const v = new CharacterVariant(); if (this.id) { v.id = this.id; } v.characterId = this.characterId; v.name = this.name; v.notes = this.notes; return state.saveVariant(v); }
    if (this.kind === 'project') {
      const old = state.projects.find((p: CosProject) => p.id === this.id); const p = old ? JSON.parse(JSON.stringify(old)) as CosProject : new CosProject();
      let character: Character | undefined;
      if (this.newCharacter && !old) { character = new Character(); character.name = this.characterName; character.workName = this.work; }
      p.name = this.name; p.characterId = this.characterId; p.variantId = this.variantId; p.eventId = this.eventId; p.targetDate = this.date; p.status = this.status as ProjectStatus; p.notes = this.notes; p.budgetCents = moneyToCents(this.money);
      const saved = await state.saveProject(p, character); if (saved) { this.id = p.id; } return saved;
    }
    if (this.kind === 'asset') {
      const old = state.assets.find((a: Asset) => a.id === this.id); const a = old ? JSON.parse(JSON.stringify(old)) as Asset : new Asset();
      a.name = this.name; a.type = this.type as AssetType; a.status = this.status as AssetStatus; a.location = this.location; a.brand = this.brand; a.size = this.size; a.priceCents = moneyToCents(this.money); a.purchaseUrl = this.url; a.notes = this.notes; return state.saveAsset(a, old ? '' : this.parentId);
    }
    if (this.kind === 'event') {
      const old = state.events.find((e: CosEvent) => e.id === this.id); const e = old ? JSON.parse(JSON.stringify(old)) as CosEvent : new CosEvent();
      e.name = this.name; e.date = this.date; e.city = this.city; e.venue = this.venue; e.url = this.url; e.status = this.status; e.ticketPurchased = this.ticket; e.notes = this.notes; return state.saveEvent(e);
    }
    if (this.kind === 'checklist') { return state.addChecklist(this.parentId, this.name); }
    return false;
  }
  title(): string { const labels = new Map<string, string>([['character', '角色'], ['variant', '角色版本'], ['project', 'Cos 计划'], ['asset', '装备'], ['event', '漫展'], ['checklist', '清单项']]); return (this.id ? '编辑' : this.kind === 'project' ? '新建' : '添加') + (this.kind === 'project' ? ' ' : '') + labels.get(this.kind); }
}
