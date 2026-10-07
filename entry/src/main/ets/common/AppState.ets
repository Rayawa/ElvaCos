import { DeviceCalendarService } from '../services/DeviceCalendarService';
import { EventSaveCoordinator } from '../services/EventSaveCoordinator';
import { EventReminderService } from '../services/EventReminderService';
import { checkSchedule } from '../model/Schedule';
import { TeamMember, Expense, ReferenceImage } from '../model/Planning';
import { PlanningRepository } from '../data/repository/PlanningRepository';
import { PreparationCategory, PreparationTask, PreparationBundle, makePreparation, preparationProgress } from '../model/Preparation';
import { PreparationRepository } from '../data/repository/PreparationRepository';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { Database } from '../data/database/Database';
import { CharacterRepository, CharacterVariantRepository, CosProjectRepository, AssetRepository, CosEventRepository, ChecklistItemRepository, PhotoAssetRepository, DiaryEntryRepository, RelationRepository } from '../data/repository/Repositories';
import { Character, CharacterVariant, CosProject, Asset, CosEvent, ChecklistItem, PhotoAsset, DiaryEntry, ProjectAsset, AppSettings, HuaweiAccount, ProjectStatus, PhotoStatus, PROJECT_LABELS, PROJECT_STATUSES } from '../model/Entities';
import { requiredName, safeUrl, validDate, checkProjectDate, projectProgress } from '../model/Rules';
import { MediaRepository } from '../data/media/MediaRepository';
import { SettingsService } from '../services/SettingsService';
import { AccountService, AccountResult } from '../services/account/AccountService';
import { HapticService } from '../services/haptic/HapticService';
import { GripService } from '../services/grip/GripService';
import { ShareService } from '../services/share/ShareService';
import { BackupService } from '../services/BackupService';
import { clearStoredAccount, getStoredAccount, setStoredAccount, StoredAccount } from './storage';

export interface SettingsSelection {
  appearance?: string;
  hand?: string;
}

@ObservedV2
export class AppState {
  @Trace pendingEventId: string = '';
  @Trace ready: boolean = false;
  @Trace busy: boolean = false;
  @Trace settingsBusy: boolean = false;
  @Trace error: string = '';
  @Trace notice: string = '';
  @Trace feedbackVersion: number = 0;
  @Trace characters: Character[] = [];
  @Trace variants: CharacterVariant[] = [];
  @Trace projects: CosProject[] = [];
  @Trace assets: Asset[] = [];
  @Trace events: CosEvent[] = [];
  @Trace preparationCategories: PreparationCategory[] = [];
  @Trace preparationTasks: PreparationTask[] = [];
  @Trace checklist: ChecklistItem[] = [];
  @Trace photos: PhotoAsset[] = [];
  @Trace team: TeamMember[] = [];
  @Trace expenses: Expense[] = [];
  @Trace references: ReferenceImage[] = [];
  @Trace diary: DiaryEntry[] = [];
  @Trace links: ProjectAsset[] = [];
  @Trace settings: AppSettings = new AppSettings();
  @Trace account: HuaweiAccount = new HuaweiAccount();
  @Trace accountBusy: boolean = false;
  @Trace sensedHand: string = 'auto';
  private db: Database = new Database();
  private characterRepo = new CharacterRepository(this.db);
  private variantRepo = new CharacterVariantRepository(this.db);
  private projectRepo = new CosProjectRepository(this.db);
  private assetRepo = new AssetRepository(this.db);
  private eventRepo = new CosEventRepository(this.db);
  private planningRepo = new PlanningRepository(this.db);
  private preparationRepo = new PreparationRepository(this.db);
  private checklistRepo = new ChecklistItemRepository(this.db);
  private photoRepo = new PhotoAssetRepository(this.db);
  private diaryRepo = new DiaryEntryRepository(this.db);
  private relations = new RelationRepository(this.db);
  private reminder = new EventReminderService();
  private preference = new SettingsService();
  private settingsQueue: Promise<void> = Promise.resolve();
  private pendingSettings: number = 0;
  private grip = new GripService();
  private context?: common.UIAbilityContext;
  private media?: MediaRepository;
  async start(context: common.UIAbilityContext): Promise<void> {
    this.context = context; this.media = new MediaRepository(context);
    await this.perform(async () => {
      await this.db.open(context);
      this.settings = await this.preference.load(context);
      this.account = this.toAccount(await getStoredAccount());
      await this.refresh();
      await this.media?.collect(this.photos, this.references);
      try { await this.reminder.reconcile(this.events); } catch (error) { this.reportNotice('系统提醒暂未核对，可重新打开应用后重试'); }
      this.ready = true;
    }, false);
  }
  private toAccount(stored: StoredAccount): HuaweiAccount {
    const account = new HuaweiAccount();
    account.signedIn = stored.openId.length > 0;
    account.openId = stored.openId;
    account.unionId = stored.unionId;
    account.displayName = stored.name;
    account.signedAt = stored.signedAt;
    return account;
  }
  /** 华为账号登录入口；云同步尚未开放，登录态当前只用于本机身份展示。 */
  async signInHuawei(): Promise<boolean> {
    if (!this.context) { return false; }
    if (this.busy) { return false; }
    this.busy = true; this.accountBusy = true; this.error = ''; this.notice = '';
    try {
      const result: AccountResult = await new AccountService().signIn(this.context);
      if (result.ok) {
        await setStoredAccount({ openId: result.account.openId, unionId: result.account.unionId, name: result.account.displayName, signedAt: result.account.signedAt });
        this.account = result.account;
      }
      this.reportNotice(result.message);
      return result.ok;
    } catch (error) {
      this.reportError((error as Error).message || '华为账号登录失败，请重试');
      return false;
    } finally {
      this.busy = false; this.accountBusy = false;
    }
  }
  async signOutHuawei(): Promise<boolean> {
    if (!this.context) { return false; }
    if (this.busy) { return false; }
    this.busy = true; this.accountBusy = true; this.error = ''; this.notice = '';
    try {
      const result: AccountResult = await new AccountService().signOut(this.context);
      if (result.ok) {
        await clearStoredAccount();
        this.account = new HuaweiAccount();
      }
      this.reportNotice(result.message);
      return result.ok;
    } catch (error) {
      this.reportError((error as Error).message || '退出登录失败，请重试');
      return false;
    } finally {
      this.busy = false; this.accountBusy = false;
    }
  }
  async refresh(): Promise<void> {
    this.team = await this.planningRepo.team(); this.expenses = await this.planningRepo.expenses(); this.references = await this.planningRepo.references();
    this.characters = await this.characterRepo.list(); this.variants = await this.variantRepo.list();
    this.projects = await this.projectRepo.list(); this.assets = await this.assetRepo.list();
    this.preparationCategories = await this.preparationRepo.categories(); this.preparationTasks = await this.preparationRepo.tasks();
    this.events = await this.eventRepo.list(); this.checklist = await this.checklistRepo.list();
    this.photos = await this.photoRepo.list(); this.links = await this.relations.links(); this.diary = await this.diaryRepo.list();
  }
  reportError(message: string): void { this.error = message; this.feedbackVersion++; }
  reportNotice(message: string): void { this.notice = message; this.feedbackVersion++; }
  async perform(action: () => Promise<void>, refresh: boolean = true): Promise<boolean> {
    if (this.busy) { return false; }
    this.busy = true; this.error = ''; this.notice = '';
    try { await action(); if (refresh) { await this.refresh(); } return true; }
    catch (error) { const code = (error as BusinessError).code;
      this.reportError(code ? (code === 14800029 || code === 13900028 ? '设备空间不足，请释放空间后重试' : '本地操作未完成，请重试。仍有问题时可重新打开应用。') : (error as Error).message || '操作失败，请重试'); return false; }
    finally { this.busy = false; }
  }
  async saveCharacter(item: Character): Promise<boolean> {
    return this.perform(async () => { item.name = requiredName(item.name); item.updatedAt = Date.now(); await this.characterRepo.save(item); });
  }
  async saveVariant(item: CharacterVariant): Promise<boolean> {
    return this.perform(async () => { item.name = requiredName(item.name); if (!item.characterId) { throw new Error('请先选择角色'); } await this.variantRepo.save(item); });
  }
  async saveProject(item: CosProject, character?: Character, preparation?: PreparationBundle): Promise<boolean> {
    return this.perform(async () => {
      item.name = requiredName(item.name); checkProjectDate(item);
      if (character) { character.name = requiredName(character.name); item.characterId = character.id; }
      if (!item.characterId) { throw new Error('请选择或填写角色'); }
      const old = this.projects.find((p: CosProject) => p.id === item.id);
      item.updatedAt = Date.now();
      const text = !old ? '开始了「' + item.name + '」' : old.status !== item.status ? item.name + ' → ' + PROJECT_LABELS[PROJECT_STATUSES.indexOf(item.status)] : '';
      await this.projectRepo.save(item, text, character, preparation);
      if (item.status === ProjectStatus.READY || item.status === ProjectStatus.COMPLETED) { await HapticService.confirm(this.settings.haptic, this.settings.hapticLevel); }
    });
  }
  async saveAsset(item: Asset, projectId: string = ''): Promise<boolean> {
    return this.perform(async () => { item.name = requiredName(item.name); item.purchaseUrl = safeUrl(item.purchaseUrl); await this.assetRepo.save(item, projectId); });
  }
  async openReminderSettings(): Promise<boolean> {
    return this.perform(async () => { if (this.context) { await this.reminder.settings(this.context); } }, false);
  }
  async addEventToCalendar(item: CosEvent): Promise<boolean> {
    return this.perform(async () => {
      if (!this.context) { throw new Error('日历暂不可用，请重新打开应用后重试'); }
      const added = await new DeviceCalendarService().add(item, this.context);
      this.reportNotice(added ? '已添加到设备日历，后续日期与提醒请在系统日历中管理' : '已取消添加日历，应用内活动保留');
    }, false);
  }
  async saveEvent(item: CosEvent): Promise<boolean> {
    return this.perform(async () => {
      item.name = requiredName(item.name); checkSchedule(item); item.url = safeUrl(item.url);
      const old = this.events.find((e: CosEvent) => e.id === item.id);
      const coordinator = new EventSaveCoordinator(
        async (event: CosEvent): Promise<void> => { await this.eventRepo.save(event); },
        async (event: CosEvent): Promise<number> => {
          if (!this.context) { throw new Error('活动已保存，提醒暂不可用，请重新打开应用后重试'); }
          return this.reminder.publish(event, this.context);
        },
        async (id: number): Promise<void> => { await this.reminder.cancel(id); });
      const warning = await coordinator.save(item, old);
      if (warning) { this.reportNotice(warning); }
    });
  }
  async saveTeam(item: TeamMember): Promise<boolean> { return this.perform(async () => { await this.planningRepo.saveTeam(item); }); }
  async saveExpense(item: Expense): Promise<boolean> { return this.perform(async () => { await this.planningRepo.saveExpense(item); }); }
  async saveReference(item: ReferenceImage): Promise<boolean> { return this.perform(async () => { await this.planningRepo.saveReference(item); }); }
  async importReferences(projectId: string = '', characterId: string = ''): Promise<boolean> {
    return this.perform(async () => {
      if (!this.media || (!projectId && !characterId) || (projectId && characterId)) { throw new Error('请选择参考图所属计划或角色'); }
      if (projectId && !this.projects.some((p: CosProject) => p.id === projectId)) { throw new Error('计划已不存在'); }
      if (characterId && !this.characters.some((c: Character) => c.id === characterId)) { throw new Error('角色已不存在'); }
      const uris = await this.media.select(); let count = 0; let failed = 0;
      for (const uri of uris) {
        const old = this.references.find((r: ReferenceImage) => r.projectId === projectId && r.characterId === characterId && r.sourceUri === uri);
        if (old && await this.media.exists(old)) { continue; }
        let imported: ReferenceImage | undefined;
        try {
          imported = await this.media.importReference(uri, projectId, characterId);
          if (old) { imported.id = old.id; imported.caption = old.caption; }
          await this.planningRepo.saveReference(imported); count++;
        } catch (error) { if (imported) { await this.media.remove(imported); } failed++; }
      }
      if (uris.length > 0) { this.reportNotice('已添加 ' + count + ' 张参考图' + (failed > 0 ? '，' + failed + ' 张失败，请检查格式或空间后重试' : '')); }
    });
  }
  async referenceCover(item: ReferenceImage): Promise<boolean> {
    return this.perform(async () => {
      const characterId = item.characterId || this.projects.find((p: CosProject) => p.id === item.projectId)?.characterId || '';
      if (!characterId || !item.thumbnailPath) { throw new Error('参考图缺失，请重新导入'); }
      await this.planningRepo.setReferenceCover(item, characterId);
    });
  }
  async savePreparationCategory(item: PreparationCategory): Promise<boolean> {
    return this.perform(async () => { await this.preparationRepo.saveCategory(item); });
  }
  async savePreparationTask(item: PreparationTask): Promise<boolean> {
    return this.perform(async () => { await this.preparationRepo.saveTask(item); });
  }
  async togglePreparation(item: PreparationTask): Promise<boolean> {
    return this.perform(async () => { await this.preparationRepo.setDone(item.id, !item.done); if (!item.done) { await HapticService.confirm(this.settings.haptic, this.settings.hapticLevel); } });
  }
  async addPreparationTemplate(projectId: string, keys: string[]): Promise<boolean> {
    return this.perform(async () => { await this.preparationRepo.addTemplate(makePreparation(projectId, keys)); this.reportNotice('已补入所选模板任务，原有进度保留'); });
  }
  preparationPercent(projectId: string): number { return preparationProgress(projectId, this.preparationTasks).percent; }
  async addChecklist(projectId: string, label: string): Promise<boolean> {
    return this.perform(async () => { const item = new ChecklistItem(); item.projectId = projectId; item.label = requiredName(label); item.sortOrder = this.checklist.length; await this.checklistRepo.save(item); });
  }
  async toggleChecklist(item: ChecklistItem): Promise<boolean> {
    return this.perform(async () => {
      const copy = JSON.parse(JSON.stringify(item)) as ChecklistItem; copy.done = !item.done;
      await this.checklistRepo.save(copy); if (copy.done) { await HapticService.confirm(this.settings.haptic, this.settings.hapticLevel); }
    });
  }
  async linkAsset(projectId: string, asset: Asset): Promise<boolean> {
    return this.perform(async () => { await this.relations.link(projectId, asset); });
  }
  async unlinkAsset(projectId: string, assetId: string): Promise<boolean> {
    return this.perform(async () => { await this.relations.unlink(projectId, assetId); });
  }
  async generateChecklist(projectId: string): Promise<boolean> {
    return this.perform(async () => {
      for (const asset of this.projectAssets(projectId)) { await this.relations.link(projectId, asset); }
      for (const label of ['手机', '充电宝', '补妆', '门票', '身份证件', '发网']) {
        if (!this.checklist.some((c: ChecklistItem) => c.projectId === projectId && c.label === label)) { const item = new ChecklistItem(); item.projectId = projectId; item.label = label; item.sortOrder = 10; await this.checklistRepo.save(item); }
      }
    });
  }
  async remove(kind: string, id: string): Promise<boolean> {
    return this.perform(async () => {
      if (kind === 'character') {
        if (this.projects.some((p: CosProject) => p.characterId === id)) { throw new Error('请先删除此角色的计划，避免丢失计划关联'); }
        const refs = this.references.filter((r: ReferenceImage) => r.characterId === id);
        await this.characterRepo.remove(id); for (const r of refs) { await this.media?.remove(r); }
      } else if (kind === 'project') {
        const photos = this.photos.filter((p: PhotoAsset) => p.projectId === id);
        const refs = this.references.filter((r: ReferenceImage) => r.projectId === id);
        await this.projectRepo.remove(id); for (const r of refs) { await this.media?.remove(r); } for (const photo of photos) { await this.media?.remove(photo); }
      } else if (kind === 'asset') { await this.assetRepo.remove(id); }
      else if (kind === 'event') { const old = this.events.find((e: CosEvent) => e.id === id); await this.eventRepo.remove(id); if (old) { try { await this.reminder.cancel(old.reminderId); } catch (error) { this.reportNotice('活动已删除，提醒取消失败，重新打开应用后会再次清理'); } } }
      else if (kind === 'variant') { if (this.projects.some((p: CosProject) => p.variantId === id)) { throw new Error('请先在计划中取消此版本关联'); } await this.variantRepo.remove(id); }
      else if (kind === 'team') { await this.planningRepo.removeTeam(id); }
      else if (kind === 'expense') { await this.planningRepo.removeExpense(id); }
      else if (kind === 'reference') { const r = this.references.find((r: ReferenceImage) => r.id === id); if (r) { await this.planningRepo.removeReference(r); await this.media?.remove(r); } }
      else if (kind === 'preparation') { await this.preparationRepo.removeTask(id); }
      else if (kind === 'category') { await this.preparationRepo.removeCategory(id); }
      else if (kind === 'checklist') { await this.checklistRepo.remove(id); }
      else if (kind === 'photo') { const photo = this.photos.find((p: PhotoAsset) => p.id === id); await this.photoRepo.remove(id); if (photo) { await this.media?.remove(photo); } }
    });
  }
  async importPhotos(projectId: string): Promise<boolean> {
    return this.perform(async () => {
      if (!this.media || !this.projects.some((p: CosProject) => p.id === projectId)) { throw new Error('请先选择照片所属计划'); }
      const uris = await this.media.select(); let count = 0; let failed = 0;
      for (const uri of uris) {
        const existing = this.photos.find((p: PhotoAsset) => p.projectId === projectId && p.sourceUri === uri);
        if (existing && await this.media.exists(existing)) { continue; }
        let imported: PhotoAsset | undefined;
        try {
          imported = await this.media.import(uri, projectId);
          if (existing) { imported.id = existing.id; imported.status = existing.status; imported.caption = existing.caption; await this.photoRepo.save(imported); }
          else { await this.relations.addPhoto(imported); }
          count++;
        } catch (error) { if (imported) { await this.media.remove(imported); } failed++; }
      }
      this.reportNotice(`已导入 ${count} 张${failed > 0 ? `，${failed} 张失败，请检查格式或空间后重试` : ''}`);
    });
  }
  async setPhotoStatus(photo: PhotoAsset, status: PhotoStatus): Promise<boolean> {
    return this.perform(async () => { const copy = JSON.parse(JSON.stringify(photo)) as PhotoAsset; copy.status = status; await this.photoRepo.save(copy); if (status === PhotoStatus.SELECTED) { await HapticService.confirm(this.settings.haptic, this.settings.hapticLevel); } });
  }
  async setPhotoStatuses(ids: string[], status: PhotoStatus): Promise<boolean> {
    return this.perform(async () => {
      await this.photoRepo.setStatuses(ids, status);
      this.reportNotice('已更新 ' + ids.length + ' 张照片');
      await HapticService.confirm(this.settings.haptic, this.settings.hapticLevel);
    });
  }
  async setCover(photo: PhotoAsset): Promise<boolean> {
    const project = this.projects.find((p: CosProject) => p.id === photo.projectId);
    const character = this.characters.find((c: Character) => c.id === project?.characterId);
    if (!character || !photo.thumbnailPath) { return false; }
    const copy = JSON.parse(JSON.stringify(character)) as Character; copy.cover = photo.thumbnailPath; return this.saveCharacter(copy);
  }
  async reloadSettings(): Promise<void> {
    if (!this.context) { return; }
    await this.enqueueSettings(async () => { if (this.context) { this.settings = await this.preference.load(this.context, false); } });
  }
  // 偏好单独排队，不能触发业务 loading，也不能丢弃连续松手提交。
  private enqueueSettings(action: () => Promise<void>): Promise<boolean> {
    this.pendingSettings++; this.settingsBusy = true;
    const result = this.settingsQueue.then(async (): Promise<boolean> => {
      try { await action(); return true; }
      catch (error) { this.reportError((error as Error).message || '保存设置失败，请重试'); return false; }
      finally { this.pendingSettings--; this.settingsBusy = this.pendingSettings > 0; }
    });
    this.settingsQueue = result.then((): void => {});
    return result;
  }
  async updateSettings(changes: SettingsSelection): Promise<boolean> {
    if (!this.context) { return false; }
    return this.enqueueSettings(async () => { if (this.context) {
        // 在队列执行时合并，避免一行的旧快照覆盖另一行刚保存的选择。
        const settings = JSON.parse(JSON.stringify(this.settings)) as AppSettings;
        if (changes.appearance !== undefined) { settings.appearance = changes.appearance; }
        if (changes.hand !== undefined) { settings.hand = changes.hand; settings.grip = settings.hand === 'auto'; }
        if (settings.grip && !this.settings.grip) {
          try { await this.grip.start(this.context, (hand: string) => { this.sensedHand = hand; }); }
          catch (error) { this.grip.stop(); this.sensedHand = 'auto'; }
        }
        await this.preference.save(this.context, settings, this.settings); this.settings = settings;
        if (!settings.grip) { this.grip.stop(); this.sensedHand = 'auto'; }
      } });
  }
  suspend(): void { this.grip.stop(); this.sensedHand = 'auto'; }
  async resume(): Promise<void> {
    if (this.settings.grip && this.context) { try { await this.grip.start(this.context, (hand: string) => { this.sensedHand = hand; }); } catch (error) { this.sensedHand = 'auto'; } }
  }
  async shareProject(id: string): Promise<boolean> {
    return this.perform(async () => { const p = this.projects.find((item: CosProject) => item.id === id); if (p && this.context) { await ShareService.project(this.context, ShareService.object(p, this.characters.find((c: Character) => c.id === p.characterId), this.events.find((e: CosEvent) => e.id === p.eventId))); } }, false);
  }
  async exportData(): Promise<boolean> {
    return this.perform(async () => { if (this.context && await new BackupService(this.db, this.context).export()) { this.reportNotice('元数据已导出。原照片请使用系统备份另行保护。'); } }, false);
  }
  async restoreData(): Promise<boolean> {
    return this.perform(async () => { if (this.context && await new BackupService(this.db, this.context).restore()) { const canceled = await this.cancelEventReminders(); this.reportNotice('元数据已恢复。缺失图片需重新导入，活动提醒需在本机重新开启。' + (canceled ? '' : '旧提醒取消失败，重新打开应用后会再次清理。')); } });
  }
  private async cancelEventReminders(): Promise<boolean> {
    let canceled = true;
    for (const event of this.events) { try { await this.reminder.cancel(event.reminderId); } catch (error) { canceled = false; this.reportNotice('提醒清理未完成，重新打开应用后会重试'); } }
    return canceled;
  }
  async clearData(): Promise<boolean> {
    return this.perform(async () => { await this.relations.clear(); await this.cancelEventReminders(); await this.media?.collect([]); });
  }
  projectAssets(id: string): Asset[] { const ids = this.links.filter((p: ProjectAsset) => p.projectId === id).map((p: ProjectAsset) => p.assetId); return this.assets.filter((a: Asset) => ids.includes(a.id)); }
  characterName(id: string): string { return this.characters.find((c: Character) => c.id === id)?.name || '未关联角色'; }
  projectName(id: string): string { return this.projects.find((p: CosProject) => p.id === id)?.name || '未关联计划'; }
  progress(id: string): number { return projectProgress(id, this.links, this.assets).percent; }
  hand(): string { return this.settings.hand === 'auto' ? this.sensedHand : this.settings.hand; }
}

export const applicationState: AppState = new AppState();
