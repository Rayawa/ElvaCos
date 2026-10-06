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

@ObservedV2
export class AppState {
  @Trace ready: boolean = false;
  @Trace busy: boolean = false;
  @Trace error: string = '';
  @Trace notice: string = '';
  @Trace feedbackVersion: number = 0;
  @Trace characters: Character[] = [];
  @Trace variants: CharacterVariant[] = [];
  @Trace projects: CosProject[] = [];
  @Trace assets: Asset[] = [];
  @Trace events: CosEvent[] = [];
  @Trace checklist: ChecklistItem[] = [];
  @Trace photos: PhotoAsset[] = [];
  @Trace diary: DiaryEntry[] = [];
  @Trace links: ProjectAsset[] = [];
  @Trace settings: AppSettings = new AppSettings();
  @Trace account: HuaweiAccount = new HuaweiAccount();
  @Trace sensedHand: string = 'auto';
  private db: Database = new Database();
  private characterRepo = new CharacterRepository(this.db);
  private variantRepo = new CharacterVariantRepository(this.db);
  private projectRepo = new CosProjectRepository(this.db);
  private assetRepo = new AssetRepository(this.db);
  private eventRepo = new CosEventRepository(this.db);
  private checklistRepo = new ChecklistItemRepository(this.db);
  private photoRepo = new PhotoAssetRepository(this.db);
  private diaryRepo = new DiaryEntryRepository(this.db);
  private relations = new RelationRepository(this.db);
  private preference = new SettingsService();
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
      await this.media?.collect(this.photos);
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
    this.busy = true; this.error = ''; this.notice = '';
    try {
      const result: AccountResult = await new AccountService().signIn(this.context);
      if (result.ok) {
        this.account = result.account;
        await setStoredAccount({ openId: result.account.openId, unionId: result.account.unionId, name: result.account.displayName, signedAt: result.account.signedAt });
      }
      this.reportNotice(result.message);
      return result.ok;
    } catch (error) {
      this.reportError((error as Error).message || '华为账号登录失败，请重试');
      return false;
    } finally {
      this.busy = false;
    }
  }
  async signOutHuawei(): Promise<boolean> {
    if (!this.context) { return false; }
    if (this.busy) { return false; }
    this.busy = true; this.error = ''; this.notice = '';
    try {
      const result: AccountResult = await new AccountService().signOut(this.context);
      if (result.ok) {
        this.account = new HuaweiAccount();
        await clearStoredAccount();
      }
      this.reportNotice(result.message);
      return result.ok;
    } catch (error) {
      this.reportError((error as Error).message || '退出登录失败，请重试');
      return false;
    } finally {
      this.busy = false;
    }
  }
  async refresh(): Promise<void> {
    this.characters = await this.characterRepo.list(); this.variants = await this.variantRepo.list();
    this.projects = await this.projectRepo.list(); this.assets = await this.assetRepo.list();
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
  async saveProject(item: CosProject, character?: Character): Promise<boolean> {
    return this.perform(async () => {
      item.name = requiredName(item.name); checkProjectDate(item);
      if (character) { character.name = requiredName(character.name); item.characterId = character.id; }
      if (!item.characterId) { throw new Error('请选择或填写角色'); }
      const old = this.projects.find((p: CosProject) => p.id === item.id);
      item.updatedAt = Date.now();
      const text = !old ? '开始了「' + item.name + '」' : old.status !== item.status ? item.name + ' → ' + PROJECT_LABELS[PROJECT_STATUSES.indexOf(item.status)] : '';
      await this.projectRepo.save(item, text, character);
      if (item.status === ProjectStatus.READY || item.status === ProjectStatus.COMPLETED) { await HapticService.confirm(this.settings.haptic, this.settings.hapticLevel); }
    });
  }
  async saveAsset(item: Asset, projectId: string = ''): Promise<boolean> {
    return this.perform(async () => { item.name = requiredName(item.name); item.purchaseUrl = safeUrl(item.purchaseUrl); await this.assetRepo.save(item, projectId); });
  }
  async saveEvent(item: CosEvent): Promise<boolean> {
    return this.perform(async () => { item.name = requiredName(item.name); if (!validDate(item.date)) { throw new Error('漫展日期格式为 YYYY-MM-DD'); } item.url = safeUrl(item.url); await this.eventRepo.save(item); });
  }
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
        await this.characterRepo.remove(id);
      } else if (kind === 'project') {
        const photos = this.photos.filter((p: PhotoAsset) => p.projectId === id);
        await this.projectRepo.remove(id); for (const photo of photos) { await this.media?.remove(photo); }
      } else if (kind === 'asset') { await this.assetRepo.remove(id); }
      else if (kind === 'event') { await this.eventRepo.remove(id); }
      else if (kind === 'variant') { if (this.projects.some((p: CosProject) => p.variantId === id)) { throw new Error('请先在计划中取消此版本关联'); } await this.variantRepo.remove(id); }
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
        if (existing?.localPath) { continue; }
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
    await this.perform(async () => { if (this.context) { this.settings = await this.preference.load(this.context); } }, false);
  }
  async updateSettings(settings: AppSettings): Promise<boolean> {
    return this.perform(async () => { if (this.context) {
        if (settings.grip && !this.settings.grip) {
          try { await this.grip.start(this.context, (hand: string) => { this.sensedHand = hand; }); }
          catch (error) { this.grip.stop(); this.sensedHand = 'auto'; }
        }
        await this.preference.save(this.context, settings); this.settings = settings;
        if (!settings.grip) { this.grip.stop(); this.sensedHand = 'auto'; }
      } }, false);
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
    return this.perform(async () => { if (this.context && await new BackupService(this.db, this.context).restore()) { this.reportNotice('元数据已恢复。本机已有原片会保留，缺失照片可重新导入。'); } });
  }
  async clearData(): Promise<boolean> {
    return this.perform(async () => { await this.relations.clear(); await this.media?.collect([]); });
  }
  projectAssets(id: string): Asset[] { const ids = this.links.filter((p: ProjectAsset) => p.projectId === id).map((p: ProjectAsset) => p.assetId); return this.assets.filter((a: Asset) => ids.includes(a.id)); }
  characterName(id: string): string { return this.characters.find((c: Character) => c.id === id)?.name || '未关联角色'; }
  projectName(id: string): string { return this.projects.find((p: CosProject) => p.id === id)?.name || '未关联计划'; }
  progress(id: string): number { return projectProgress(id, this.links, this.assets).percent; }
  hand(): string { return this.settings.hand === 'auto' ? this.sensedHand : this.settings.hand; }
}

export const applicationState: AppState = new AppState();
