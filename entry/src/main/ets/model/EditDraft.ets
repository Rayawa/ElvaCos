import { today } from '../common/format';
import { TeamMember, Expense, ReferenceImage } from './Planning';
import { PreparationCategory, PreparationTask, makePreparation, preparationKeys } from './Preparation';
import { AppState } from './ApplicationState';
import { Asset, Character, CharacterVariant, CosEvent, CosProject, AssetType, AssetStatus, ProjectStatus, ChecklistItem, newId } from './Entities';
import { moneyToCents, validDate, requiredName, safeUrl } from './Rules';
import { checkSchedule, ScheduleError } from './Schedule';

export class FormIssue {
  field: string; message: string;
  constructor(field: string, message: string) { this.field = field; this.message = message; }
}

@ObservedV2
export class EditDraft {
  @Trace creationId: string = newId();
  @Trace creationCharacterId: string = newId();
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
  @Trace budgetEdited: boolean = false;
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
  @Trace waitingOn: string = '';
  @Trace waitingUntil: string = '';
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
        d.notes = c.description;
      }
    }
    if (kind === 'variant') {
      const v = state.variants.find((item: CharacterVariant) => item.id === id);
      d.characterId = parent;
      if (v) {
        d.name = v.name;
        d.notes = v.notes;
        d.characterId = v.characterId;
      }
    }
    if (kind === 'project') {
      d.money = '';
      d.characterId = state.characters.some((c: Character) => c.id === parent) ? parent : state.characters[0]?.id || '';
      const event = state.events.find((e: CosEvent) => e.id === parent);
      if (event) { d.eventId = event.id; d.date = event.date; }
      d.newCharacter = !d.characterId; d.status = ProjectStatus.PREPARING;
      d.name = d.characterId ? state.characterName(d.characterId) + ' · 计划' : '';
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
        d.money = p.budgetConfigured === true ? String(p.budgetCents / 100) : '';
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
      if (t) { d.name = t.label; d.notes = t.notes; d.date = t.dueDate; d.categoryId = t.categoryId; d.parentId = t.projectId; d.waitingOn = t.waitingOn; d.waitingUntil = t.waitingUntil; }
    }
    if (kind === 'team') {
      d.type = '摄影'; const m = state.team.find((m: TeamMember) => m.id === id);
      if (m) { d.name = m.name; d.type = m.role; d.notes = m.notes; d.parentId = m.projectId; }
    }
    if (kind === 'expense') {
      d.type = '服装'; d.date = today(); d.parentId = parent;
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
  serialize(): string {
    const value: EditDraft = new EditDraft();
    value.creationId = this.creationId; value.creationCharacterId = this.creationCharacterId;
    value.kind = this.kind;
    value.id = this.id;
    value.parentId = this.parentId;
    value.name = this.name;
    value.work = this.work;
    value.notes = this.notes;
    value.characterId = this.characterId;
    value.variantId = this.variantId;
    value.eventId = this.eventId;
    value.date = this.date;
    value.city = this.city;
    value.venue = this.venue;
    value.url = this.url;
    value.location = this.location;
    value.brand = this.brand;
    value.size = this.size;
    value.money = this.money;
    value.status = this.status;
    value.type = this.type;
    value.characterName = this.characterName;
    value.dateMode = this.dateMode;
    value.endDate = this.endDate;
    value.timeMode = this.timeMode;
    value.startTime = this.startTime;
    value.endTime = this.endTime;
    value.categoryId = this.categoryId;
    value.waitingOn = this.waitingOn;
    value.waitingUntil = this.waitingUntil;
    value.budgetEdited = this.budgetEdited;
    value.ticket = this.ticket;
    value.deviceCalendar = this.deviceCalendar;
    value.newCharacter = this.newCharacter;
    value.advanced = this.advanced;
    value.preparationExpanded = this.preparationExpanded;
    value.reminderMinutes = this.reminderMinutes;
    value.preparationMode = this.preparationMode;
    value.preparationKeys = this.preparationKeys.slice();
    return JSON.stringify(value);
  }
  fingerprint(): string {
    const value = EditDraft.fromJSON(this.serialize()); value.advanced = false; value.preparationExpanded = false;
    value.creationId = 'fingerprint'; value.creationCharacterId = 'fingerprint';
    return value.serialize();
  }
  static fromJSON(payload: string): EditDraft {
    const source = JSON.parse(payload) as EditDraft; const value = new EditDraft();
    if (!source || typeof source !== 'object') { throw new Error('草稿格式无法读取'); }
    if (typeof source.creationId !== 'string' || !source.creationId || source.creationId.length > 80 || typeof source.creationCharacterId !== 'string' || !source.creationCharacterId || source.creationCharacterId.length > 80) { throw new Error('草稿记录标识无法读取'); }
    value.creationId = source.creationId; value.creationCharacterId = source.creationCharacterId;
    if (typeof source.kind !== 'string') { throw new Error('草稿字段无法读取'); } value.kind = source.kind;
    if (typeof source.id !== 'string') { throw new Error('草稿字段无法读取'); } value.id = source.id;
    if (typeof source.parentId !== 'string') { throw new Error('草稿字段无法读取'); } value.parentId = source.parentId;
    if (typeof source.name !== 'string') { throw new Error('草稿字段无法读取'); } value.name = source.name;
    if (typeof source.work !== 'string') { throw new Error('草稿字段无法读取'); } value.work = source.work;
    if (typeof source.notes !== 'string') { throw new Error('草稿字段无法读取'); } value.notes = source.notes;
    if (typeof source.characterId !== 'string') { throw new Error('草稿字段无法读取'); } value.characterId = source.characterId;
    if (typeof source.variantId !== 'string') { throw new Error('草稿字段无法读取'); } value.variantId = source.variantId;
    if (typeof source.eventId !== 'string') { throw new Error('草稿字段无法读取'); } value.eventId = source.eventId;
    if (typeof source.date !== 'string') { throw new Error('草稿字段无法读取'); } value.date = source.date;
    if (typeof source.city !== 'string') { throw new Error('草稿字段无法读取'); } value.city = source.city;
    if (typeof source.venue !== 'string') { throw new Error('草稿字段无法读取'); } value.venue = source.venue;
    if (typeof source.url !== 'string') { throw new Error('草稿字段无法读取'); } value.url = source.url;
    if (typeof source.location !== 'string') { throw new Error('草稿字段无法读取'); } value.location = source.location;
    if (typeof source.brand !== 'string') { throw new Error('草稿字段无法读取'); } value.brand = source.brand;
    if (typeof source.size !== 'string') { throw new Error('草稿字段无法读取'); } value.size = source.size;
    if (typeof source.money !== 'string') { throw new Error('草稿字段无法读取'); } value.money = source.money;
    if (typeof source.status !== 'string') { throw new Error('草稿字段无法读取'); } value.status = source.status;
    if (typeof source.type !== 'string') { throw new Error('草稿字段无法读取'); } value.type = source.type;
    if (typeof source.characterName !== 'string') { throw new Error('草稿字段无法读取'); } value.characterName = source.characterName;
    if (typeof source.dateMode !== 'string') { throw new Error('草稿字段无法读取'); } value.dateMode = source.dateMode;
    if (typeof source.endDate !== 'string') { throw new Error('草稿字段无法读取'); } value.endDate = source.endDate;
    if (typeof source.timeMode !== 'string') { throw new Error('草稿字段无法读取'); } value.timeMode = source.timeMode;
    if (typeof source.startTime !== 'string') { throw new Error('草稿字段无法读取'); } value.startTime = source.startTime;
    if (typeof source.endTime !== 'string') { throw new Error('草稿字段无法读取'); } value.endTime = source.endTime;
    if (typeof source.categoryId !== 'string') { throw new Error('草稿字段无法读取'); } value.categoryId = source.categoryId;
    if (typeof source.waitingOn !== 'string') { throw new Error('草稿字段无法读取'); } value.waitingOn = source.waitingOn;
    if (typeof source.waitingUntil !== 'string') { throw new Error('草稿字段无法读取'); } value.waitingUntil = source.waitingUntil;
    if (typeof source.budgetEdited !== 'boolean') { throw new Error('草稿字段无法读取'); } value.budgetEdited = source.budgetEdited;
    if (typeof source.ticket !== 'boolean') { throw new Error('草稿字段无法读取'); } value.ticket = source.ticket;
    if (typeof source.deviceCalendar !== 'boolean') { throw new Error('草稿字段无法读取'); } value.deviceCalendar = source.deviceCalendar;
    if (typeof source.newCharacter !== 'boolean') { throw new Error('草稿字段无法读取'); } value.newCharacter = source.newCharacter;
    if (typeof source.advanced !== 'boolean') { throw new Error('草稿字段无法读取'); } value.advanced = source.advanced;
    if (typeof source.preparationExpanded !== 'boolean') { throw new Error('草稿字段无法读取'); } value.preparationExpanded = source.preparationExpanded;
    if (typeof source.reminderMinutes !== 'number' || !Number.isFinite(source.reminderMinutes)) { throw new Error('草稿字段无法读取'); } value.reminderMinutes = source.reminderMinutes;
    if (typeof source.preparationMode !== 'number' || !Number.isFinite(source.preparationMode)) { throw new Error('草稿字段无法读取'); } value.preparationMode = source.preparationMode;
    if (!Array.isArray(source.preparationKeys) || source.preparationKeys.some((key: string) => typeof key !== 'string' || key.length > 80)) { throw new Error('草稿模板无法读取'); }
    value.preparationKeys = source.preparationKeys.slice(); return value;
  }
  exists(state: AppState, id: string = this.id): boolean {
    if (!id) { return true; }
    if (this.kind === 'character') { return state.characters.some((item: Character) => item.id === id); }
    if (this.kind === 'variant') { return state.variants.some((item: CharacterVariant) => item.id === id); }
    if (this.kind === 'project') { return state.projects.some((item: CosProject) => item.id === id); }
    if (this.kind === 'event') { return state.events.some((item: CosEvent) => item.id === id); }
    if (this.kind === 'asset') { return state.assets.some((item: Asset) => item.id === id); }
    if (this.kind === 'preparation') { return state.preparationTasks.some((item: PreparationTask) => item.id === id); }
    if (this.kind === 'category') { return state.preparationCategories.some((item: PreparationCategory) => item.id === id); }
    if (this.kind === 'expense') { return state.expenses.some((item: Expense) => item.id === id); }
    if (this.kind === 'team') { return state.team.some((item: TeamMember) => item.id === id); }
    if (this.kind === 'reference') { return state.references.some((item: ReferenceImage) => item.id === id); }
    if (this.kind === 'checklist') { return state.checklist.some((item: ChecklistItem) => item.id === id); }
    return false;
  }
  committedCreation(state: AppState): boolean { return !this.id && this.exists(state, this.creationId); }
  issues(state: AppState): FormIssue[] {
    const errors: FormIssue[] = [];
    const check = (field: string, action: () => void): void => { try { action(); } catch (error) { errors.push(new FormIssue(field, (error as Error).message)); } };
    if (this.committedCreation(state)) { return [new FormIssue('object', '这份草稿已保存，请关闭后查看现有记录')]; }
    if (!this.exists(state)) { return [new FormIssue('object', '记录已不存在，请关闭表单后返回有效页面')]; }
    if (this.kind === 'project') {
      if (this.newCharacter && !this.id) { check('characterName', (): void => { requiredName(this.characterName); }); }
      else if (!state.characters.some((item: Character) => item.id === this.characterId)) { errors.push(new FormIssue('characterId', '请选择现有角色')); }
    }
    if (this.kind !== 'reference') { check('name', (): void => { requiredName(this.name); }); }
    if (this.kind === 'project' && this.date || this.kind === 'preparation' && this.date || this.kind === 'expense') {
      if (!validDate(this.date)) { errors.push(new FormIssue('date', '请选择有效日期')); }
    }
    if (this.kind === 'preparation') {
      if (!state.preparationCategories.some((item: PreparationCategory) => item.id === this.categoryId && item.projectId === this.parentId)) { errors.push(new FormIssue('categoryId', '请选择此计划的准备分类')); }
      if (this.waitingUntil && !validDate(this.waitingUntil)) { errors.push(new FormIssue('waitingUntil', '请选择有效等待日期')); }
    }
    if (['team', 'expense', 'category', 'preparation', 'checklist'].includes(this.kind) && !state.projects.some((item: CosProject) => item.id === this.parentId)) { errors.push(new FormIssue('parentId', '请选择现有计划')); }
    if (this.kind === 'asset' && this.parentId && !this.id && !state.projects.some((item: CosProject) => item.id === this.parentId)) { errors.push(new FormIssue('parentId', '关联计划已不存在')); }
    if (this.kind === 'variant' && !state.characters.some((item: Character) => item.id === this.characterId)) { errors.push(new FormIssue('characterId', '所属角色已不存在')); }
    if (this.kind === 'project') {
      if (this.variantId && !state.variants.some((item: CharacterVariant) => item.id === this.variantId && item.characterId === this.characterId)) { errors.push(new FormIssue('variantId', '版本已不存在或不属于当前角色')); }
      if (this.eventId && !state.events.some((item: CosEvent) => item.id === this.eventId)) { errors.push(new FormIssue('eventId', '关联活动已不存在')); }
    }
    if (['asset', 'expense'].includes(this.kind) || this.kind === 'project' && this.money.trim()) { check('money', (): void => { moneyToCents(this.money); }); }
    if (['asset', 'event'].includes(this.kind)) { check('url', (): void => { safeUrl(this.url); }); }
    if (this.kind === 'team') { check('type', (): void => { requiredName(this.type); }); }
    if (this.kind === 'event') {
      const event = new CosEvent(); event.eventType = this.type; event.dateMode = this.dateMode; event.date = this.date; event.endDate = this.endDate;
      event.timeMode = this.timeMode; event.startTime = this.startTime; event.endTime = this.endTime; event.reminderMinutes = this.reminderMinutes;
      try { checkSchedule(event); } catch (error) { errors.push(new FormIssue((error as ScheduleError).field || 'date', (error as Error).message)); }
    }
    return errors;
  }
  async save(state: AppState): Promise<boolean> {
    const issues = this.issues(state);
    if (issues.length) { state.reportError(issues[0].message); return false; }

    if (this.kind === 'character') {
      const old = state.characters.find((c: Character) => c.id === this.id);
      const c = old ? JSON.parse(JSON.stringify(old)) as Character : new Character();
      if (!old) { c.id = this.creationId; }
      c.name = this.name; c.workName = this.work; c.description = this.notes; return state.saveCharacter(c);
    }
    if (this.kind === 'variant') {
      const v = new CharacterVariant(); v.id = this.creationId;
      if (this.id) {
        v.id = this.id;
      }
      v.characterId = this.characterId;
      v.name = this.name;
      v.notes = this.notes;
      return state.saveVariant(v);
    }
    if (this.kind === 'project') {
      const old = state.projects.find((p: CosProject) => p.id === this.id);
      const p = old ? JSON.parse(JSON.stringify(old)) as CosProject : new CosProject();
      if (!old) { p.id = this.creationId; }
      let character: Character | undefined;
      if (this.newCharacter && !old) { character = new Character(); character.id = this.creationCharacterId; character.name = this.characterName; character.workName = this.work; }
      p.name = this.name;
      p.characterId = this.characterId;
      p.variantId = this.variantId;
      p.eventId = this.eventId;
      p.targetDate = this.date;
      p.status = this.status as ProjectStatus;
      p.notes = this.notes;
      const budgetEntered = this.money.trim() !== '';
      p.budgetCents = budgetEntered ? moneyToCents(this.money) : 0;
      p.budgetConfigured = budgetEntered ? true : old && old.budgetConfigured === undefined && !this.budgetEdited ? undefined : false;
      const saved = await state.saveProject(p, character, old ? undefined : makePreparation(p.id, this.preparationKeys));
      if (saved) {
        this.id = p.id;
      }
      return saved;
    }
    if (this.kind === 'asset') {
      const old = state.assets.find((a: Asset) => a.id === this.id); const a = old ? JSON.parse(JSON.stringify(old)) as Asset : new Asset();
      if (!old) { a.id = this.creationId; }
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
      if (!old) { e.id = this.creationId; }
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
        this.id = e.id;
      }
      return saved;
    }
    if (this.kind === 'team') {
      const old = state.team.find((m: TeamMember) => m.id === this.id);
      const m = old ? JSON.parse(JSON.stringify(old)) as TeamMember : new TeamMember();
      if (!old) { m.id = this.creationId; }
      m.projectId = this.parentId; m.name = this.name; m.role = this.type; m.notes = this.notes; return state.saveTeam(m);
    }
    if (this.kind === 'expense') {
      const old = state.expenses.find((e: Expense) => e.id === this.id);
      const e = old ? JSON.parse(JSON.stringify(old)) as Expense : new Expense();
      if (!old) { e.id = this.creationId; }
      e.projectId = this.parentId;
      e.name = this.name;
      e.category = this.type;
      e.amountCents = moneyToCents(this.money);
      e.date = this.date;
      e.notes = this.notes;
      if (!e.projectId) { state.reportError('请选择花费所属计划'); return false; }
      return state.saveExpense(e);
    }
    if (this.kind === 'reference') {
      const old = state.references.find((r: ReferenceImage) => r.id === this.id); if (!old) { state.reportError('参考图已不存在'); return false; }
      const r = JSON.parse(JSON.stringify(old)) as ReferenceImage; r.caption = this.notes; return state.saveReference(r);
    }
    if (this.kind === 'category') {
      const old = state.preparationCategories.find((c: PreparationCategory) => c.id === this.id);
      const c = old ? JSON.parse(JSON.stringify(old)) as PreparationCategory : new PreparationCategory();
      if (!old) { c.id = this.creationId; }
      c.projectId = this.parentId;
      c.name = this.name;
      if (!old) {
        c.sortOrder = state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.parentId)
          .length;
      }
      return state.savePreparationCategory(c);
    }
    if (this.kind === 'preparation') {
      const old = state.preparationTasks.find((t: PreparationTask) => t.id === this.id);
      const t = old ? JSON.parse(JSON.stringify(old)) as PreparationTask : new PreparationTask();
      if (!old) { t.id = this.creationId; }
      t.projectId = this.parentId; t.categoryId = this.categoryId; t.label = this.name; t.notes = this.notes; t.dueDate = this.date; t.waitingOn = this.waitingOn.trim(); t.waitingUntil = this.waitingUntil;
      if (!t.categoryId) { state.reportError('请先添加准备分类'); return false; }
      if (!old) { t.sortOrder = state.preparationTasks.filter((t: PreparationTask) => t.categoryId === this.categoryId).length; }
      return state.savePreparationTask(t);
    }
    if (this.kind === 'checklist') { return state.addChecklist(this.parentId, this.name, this.creationId); }
    return false;
  }
  title(): string {
    const labels = new Map<string, string>([['character', '角色'], ['variant', '角色版本'], ['project', '计划'], ['asset', '装备'], ['event', '活动'], ['checklist', '清单项'], ['preparation', '准备任务'], ['category', '准备分类'], ['team', '团队成员'], ['expense', '花费'], ['reference', '参考图说明']]);
    return (this.id ? '编辑' : this.kind === 'project' ? '新建' : '添加') + labels.get(this.kind);
  }
}
