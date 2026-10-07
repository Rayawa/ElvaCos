import { today } from '../common/format';
import { TeamMember, Expense, ReferenceImage } from './Planning';
import { PreparationCategory, PreparationTask, makePreparation, preparationKeys } from './Preparation';
import { AppState } from './ApplicationState';
import { Asset, Character, CharacterVariant, CosEvent, CosProject, AssetType, AssetStatus, ProjectStatus } from './Entities';
import { moneyToCents, validDate } from './Rules';

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
  @Trace deviceCalendar: boolean = false;
  @Trace newCharacter: boolean = false;
  @Trace characterName: string = '';
  @Trace advanced: boolean = false;
  @Trace dateMode: string = 'single';
  @Trace endDate: string = '';
  @Trace timeMode: string = 'none';
  @Trace startTime: string = '';
  @Trace endTime: string = '';
  @Trace reminderMinutes: number = -1;
  @Trace categoryId: string = '';
  @Trace preparationMode: number = 1;
  @Trace preparationExpanded: boolean = false;
  @Trace preparationKeys: string[] = preparationKeys(1);
  static make(state: AppState, kind: string, id: string = '', parent: string = ''): EditDraft {
    const d = new EditDraft(); d.kind = kind; d.id = id; d.parentId = parent;
    if (kind === 'character') { 
    const c = state.characters.find((item: Character) => item.id === id); 
    if (c) { 
      d.name = c.name; 
      d.work = c.workName; 
      d.notes = c.description; } 
  }
    if (kind === 'variant') { 
    const v = state.variants.find((item: CharacterVariant) => item.id === id); 
    d.characterId = parent; 
    if (v) { 
      d.name = v.name; 
      d.notes = v.notes; 
      d.characterId = v.characterId; } 
  }
    if (kind === 'project') {
      d.characterId = state.characters.some((c: Character) => c.id === parent) ? parent : state.characters[0]?.id || '';
      const event = state.events.find((e: CosEvent) => e.id === parent);
      if (event) { d.eventId = event.id; d.date = event.date; }
      d.newCharacter = !d.characterId; d.status = ProjectStatus.PREPARING;
      d.name = d.characterId ? state.characterName(d.characterId) + ' · Cos 计划' : '';
      const p = state.projects.find((item: CosProject) => item.id === id);
      if (p) { 
      d.name = p.name; 
      d.characterId = p.characterId; 
      d.newCharacter = false; 
      d.advanced = true; 
      d.variantId = p.variantId; 
      d.eventId = p.eventId; 
      d.notes = p.notes; 
      d.date = p.targetDate; 
      d.money = String(p.budgetCents / 100); 
      d.status = p.status; 
    }
    }
    if (kind === 'asset') {
      d.type = AssetType.COSTUME; d.status = AssetStatus.OWNED;
      const a = state.assets.find((item: Asset) => item.id === id);
      if (a) { 
      d.name = a.name; 
      d.type = a.type; 
      d.status = a.status; 
      d.location = a.location; 
      d.brand = a.brand; 
      d.size = a.size; 
      d.money = String(a.priceCents / 100); 
      d.url = a.purchaseUrl; 
      d.notes = a.notes; 
    }
    }
    if (kind === 'event') {
      d.date = validDate(parent) ? parent : today(); 
    d.status = 'Planned'; 
    d.type = '漫展'; 
    const e = state.events.find((item: CosEvent) => item.id === id);
      if (e) { 
      d.name = e.name; 
      d.date = e.date; 
      d.city = e.city; 
      d.venue = e.venue; 
      d.url = e.url; 
      d.status = e.status; 
      d.ticket = e.ticketPurchased; 
      d.notes = e.notes; 
      d.dateMode = e.dateMode; 
      d.endDate = e.endDate; 
      d.timeMode = e.timeMode; 
      d.startTime = e.startTime; 
      d.endTime = e.endTime; 
      d.type = e.eventType; 
      d.reminderMinutes = e.reminderMinutes; 
    }
    }
    if (kind === 'category') {
      const c = state.preparationCategories.find((c: PreparationCategory) => c.id === id);
      if (c) { d.name = c.name; d.parentId = c.projectId; }
    }
    if (kind === 'preparation') {
      const t = state.preparationTasks.find((t: PreparationTask) => t.id === id);
      const category = state.preparationCategories.find((c: PreparationCategory) => c.id === parent);
      d.categoryId = category?.id || state.preparationCategories.find((c: PreparationCategory) => c.projectId === parent)?.id || '';
      d.parentId = category?.projectId || parent;
      if (t) { d.name = t.label; d.notes = t.notes; d.date = t.dueDate; d.categoryId = t.categoryId; d.parentId = t.projectId; }
    }
    if (kind === 'team') {
      d.type = '摄影'; const m = state.team.find((m: TeamMember) => m.id === id);
      if (m) { d.name = m.name; d.type = m.role; d.notes = m.notes; d.parentId = m.projectId; }
    }
    if (kind === 'expense') {
      d.type = '服装'; d.date = today(); d.parentId = parent || state.projects[0]?.id || '';
      const e = state.expenses.find((e: Expense) => e.id === id);
      if (e) { 
      d.name = e.name; 
      d.type = e.category; 
      d.money = String(e.amountCents / 100); 
      d.notes = e.notes; 
      d.date = e.date; 
      d.parentId = e.projectId; 
    }
    }
    if (kind === 'reference') {
      const r = state.references.find((r: ReferenceImage) => r.id === id); if (r) { d.notes = r.caption; }
    }
    return d;
  }
  async save(state: AppState): Promise<boolean> {
    if (this.kind === 'character') {
      const old = state.characters.find((c: Character) => c.id === this.id); 
    const c = old ? JSON.parse(JSON.stringify(old)) as Character : new Character();
      c.name = this.name; c.workName = this.work; c.description = this.notes; return state.saveCharacter(c);
    }
    if (this.kind === 'variant') { 
    const v = new CharacterVariant(); 
    if (this.id) { 
      v.id = this.id; } 
    v.characterId = this.characterId; 
    v.name = this.name; 
    v.notes = this.notes; 
    return state.saveVariant(v); 
  }
    if (this.kind === 'project') {
      const old = state.projects.find((p: CosProject) => p.id === this.id); 
    const p = old ? JSON.parse(JSON.stringify(old)) as CosProject : new CosProject();
      let character: Character | undefined;
      if (this.newCharacter && !old) { character = new Character(); character.name = this.characterName; character.workName = this.work; }
      p.name = this.name; 
    p.characterId = this.characterId; 
    p.variantId = this.variantId; 
    p.eventId = this.eventId; 
    p.targetDate = this.date; 
    p.status = this.status as ProjectStatus; 
    p.notes = this.notes; 
    p.budgetCents = moneyToCents(this.money);
      const saved = await state.saveProject(p, character, old ? undefined : makePreparation(p.id, this.preparationKeys)); 
    if (saved) { 
      this.id = p.id; } 
    return saved;
    }
    if (this.kind === 'asset') {
      const old = state.assets.find((a: Asset) => a.id === this.id); const a = old ? JSON.parse(JSON.stringify(old)) as Asset : new Asset();
      a.name = this.name; 
    a.type = this.type as AssetType; 
    a.status = this.status as AssetStatus; 
    a.location = this.location; 
    a.brand = this.brand; 
    a.size = this.size; 
    a.priceCents = moneyToCents(this.money); 
    a.purchaseUrl = this.url; 
    a.notes = this.notes; 
    return state.saveAsset(a, old ? '' : this.parentId);
    }
    if (this.kind === 'event') {
      const old = state.events.find((e: CosEvent) => e.id === this.id); 
    const e = old ? JSON.parse(JSON.stringify(old)) as CosEvent : new CosEvent();
      e.name = this.name; 
    e.date = this.date; 
    e.city = this.city; 
    e.venue = this.venue; 
    e.url = this.url; 
    e.status = this.status; 
    e.ticketPurchased = this.ticket; 
    e.notes = this.notes; 
    e.dateMode = this.dateMode; 
    e.endDate = this.endDate; 
    e.timeMode = this.timeMode; 
    e.startTime = this.startTime; 
    e.endTime = this.endTime; 
    e.eventType = this.type; 
    e.reminderMinutes = this.reminderMinutes; 
    const saved = await state.saveEvent(e); 
    if (saved) { 
      this.id = e.id; } 
    return saved;
    }
    if (this.kind === 'team') {
      const old = state.team.find((m: TeamMember) => m.id === this.id);
      const m = old ? JSON.parse(JSON.stringify(old)) as TeamMember : new TeamMember();
      m.projectId = this.parentId; m.name = this.name; m.role = this.type; m.notes = this.notes; return state.saveTeam(m);
    }
    if (this.kind === 'expense') {
      const old = state.expenses.find((e: Expense) => e.id === this.id);
      const e = old ? JSON.parse(JSON.stringify(old)) as Expense : new Expense();
      e.projectId = this.parentId; 
    e.name = this.name; 
    e.category = this.type; 
    e.amountCents = moneyToCents(this.money); 
    e.date = this.date; 
    e.notes = this.notes;
      if (!e.projectId) { state.reportError('请先创建花费所属计划'); return false; }
      return state.saveExpense(e);
    }
    if (this.kind === 'reference') {
      const old = state.references.find((r: ReferenceImage) => r.id === this.id); if (!old) { state.reportError('参考图已不存在'); return false; }
      const r = JSON.parse(JSON.stringify(old)) as ReferenceImage; r.caption = this.notes; return state.saveReference(r);
    }
    if (this.kind === 'category') {
      const old = state.preparationCategories.find((c: PreparationCategory) => c.id === this.id);
      const c = old ? JSON.parse(JSON.stringify(old)) as PreparationCategory : new PreparationCategory();
      c.projectId = this.parentId; 
    c.name = this.name; 
    if (!old) { 
      c.sortOrder = state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.parentId)
        .length; }
      return state.savePreparationCategory(c);
    }
    if (this.kind === 'preparation') {
      const old = state.preparationTasks.find((t: PreparationTask) => t.id === this.id);
      const t = old ? JSON.parse(JSON.stringify(old)) as PreparationTask : new PreparationTask();
      t.projectId = this.parentId; t.categoryId = this.categoryId; t.label = this.name; t.notes = this.notes; t.dueDate = this.date;
      if (!t.categoryId) { state.reportError('请先添加准备分类'); return false; }
      if (!old) { t.sortOrder = state.preparationTasks.filter((t: PreparationTask) => t.categoryId === this.categoryId).length; }
      return state.savePreparationTask(t);
    }
    if (this.kind === 'checklist') { return state.addChecklist(this.parentId, this.name); }
    return false;
  }
  title(): string { 
  const labels = new Map<string, string>([['character', '角色'], ['variant', '角色版本'], ['project', 'Cos 计划'], ['asset', '装备'], ['event', '活动'], ['checklist', '清单项'], ['preparation', '准备任务'], ['category', '准备分类'], ['team', '团队成员'], ['expense', '花费'], ['reference', '参考图说明']]); 
  return (this.id ? '编辑' : this.kind === 'project' ? '新建' : '添加') + (this.kind === 'project' ? ' ' : '') + labels.get(this.kind); 
}
}
