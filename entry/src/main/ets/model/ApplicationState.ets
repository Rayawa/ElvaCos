import { CollectedEntry, entryFromText } from './CollectedEntry';
import { EntryRepository } from '../data/repository/EntryRepository';
import { today } from '../common/format';
import { buildTaskQueue, TaskQueueItem, taskNeedsAction } from './TaskQueue';
import { DayModulePreferences, dayEntries, localDay, DAY_MODULES, orderedDayModules } from './DayMode';
import { getDayModules, setDayModules, getDayDismissals, setDayDismissals } from '../common/storage';
import { PlanReadiness, buildPlanReadiness } from './PlanReadiness';
import { OperationResult, executeOperation, operationCommitted } from './OperationResult';
import { PROJECT_LABELS, PROJECT_STATUSES } from '../common/constants';
import BuildProfile from 'BuildProfile';
import { DemoDataRepository } from '../data/repository/DemoDataRepository';
import { DeviceCalendarService } from '../common/DeviceCalendarService';
import { EventSaveCoordinator } from '../common/EventSaveCoordinator';
import { EventReminderService } from '../common/EventReminderService';
import { checkSchedule } from './Schedule';
import { TeamMember, Expense, ReferenceImage } from './Planning';
import { PlanningRepository } from '../data/repository/PlanningRepository';
import { PreparationCategory, PreparationTask, PreparationBundle, makePreparation } from './Preparation';
import { PreparationRepository } from '../data/repository/PreparationRepository';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { Database } from '../data/database/Database';
import {
  CharacterRepository,
  CharacterVariantRepository,
  CosProjectRepository,
  AssetRepository,
  CosEventRepository,
  ChecklistItemRepository,
  PhotoAssetRepository,
  DiaryEntryRepository,
  RelationRepository,
} from '../data/repository/Repositories';
import {
  Character,
  CharacterVariant,
  CosProject,
  Asset,
  CosEvent,
  ChecklistItem,
  PhotoAsset,
  DiaryEntry,
  ProjectAsset,
  AppSettings,
  HuaweiAccount,
  ProjectStatus,
  PhotoStatus,
} from './Entities';
import { requiredName, safeUrl, validDate, checkProjectDate } from './Rules';
import { MediaRepository } from '../data/media/MediaRepository';
import { SettingsService } from '../common/SettingsService';
import { AccountService, AccountResult } from '../common/AccountService';
import { HapticService } from '../common/HapticService';
import { GripService } from '../common/GripService';
import { ShareService } from '../common/ShareService';
import { BackupService } from '../common/BackupService';
import { clearStoredAccount, getStoredAccount, setStoredAccount, StoredAccount } from '../common/storage';

export interface SettingsSelection {
  appearance?: string;
  themeColor?: string;
  hand?: string;
}

class DataSnapshot {
  entries: CollectedEntry[] = [];
  team: TeamMember[] = [];
  expenses: Expense[] = [];
  references: ReferenceImage[] = [];
  characters: Character[] = [];
  variants: CharacterVariant[] = [];
  projects: CosProject[] = [];
  assets: Asset[] = [];
  preparationCategories: PreparationCategory[] = [];
  preparationTasks: PreparationTask[] = [];
  events: CosEvent[] = [];
  checklist: ChecklistItem[] = [];
  photos: PhotoAsset[] = [];
  links: ProjectAsset[] = [];
  diary: DiaryEntry[] = [];
}
const DATA_SCOPES: string[] = ['entries', 'team', 'expenses', 'references', 'characters', 'variants', 'projects', 'assets', 'preparationCategories', 'preparationTasks', 'events', 'checklist', 'photos', 'links', 'diary'];

@ObservedV2
export class AppState {
  @Trace operationScope: string = '';
  @Trace lastOperation: OperationResult = { status: 'ok' };
  @Trace staleScopes: string[] = [];
  @Trace localDate: string = today();
  @Trace clockTime: number = Date.now();
  @Trace dayModules: DayModulePreferences = {};
  @Trace dayDismissals: Record<string, string> = {};
  @Trace pendingEventId: string = '';
  @Trace ready: boolean = false;
  @Trace busy: boolean = false;
  @Trace settingsBusy: boolean = false;
  @Trace error: string = '';
  @Trace notice: string = '';
  @Trace feedbackVersion: number = 0;
  @Trace entries: CollectedEntry[] = [];
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
  private entryRepo = new EntryRepository(this.db);
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
  private startTask?: Promise<void>;
  private operationPartial: boolean = false;
  private reloadTask?: Promise<boolean>;
  private operationTask?: Promise<OperationResult>;
  private disposeTask?: Promise<void>;
  private preferencesTask?: Promise<void>;

  loadPreferences(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (!this.preferencesTask) {
      this.preferencesTask = this.preference.load(context).then(async (settings: AppSettings): Promise<void> => {
        this.settings = settings;
        this.dayModules = await getDayModules(); this.dayDismissals = await getDayDismissals(); this.tickClock();
      }).catch((error: Error): void => {
        this.preferencesTask = undefined;
        throw error;
      });
    }
    return this.preferencesTask;
  }

  start(context: common.UIAbilityContext): Promise<void> {
    if (this.disposeTask) { return this.disposeTask.then((): Promise<void> => this.start(context)); }
    if (this.ready) { return Promise.resolve(); }
    if (!this.startTask) {
      this.startTask = this.initialize(context).finally((): void => { this.startTask = undefined; });
    }
    return this.startTask;
  }

  private async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context; this.media = new MediaRepository(context);
    await this.perform(async () => {
      await this.db.open(context);
      await this.loadPreferences(context);
      this.account = this.toAccount(await getStoredAccount());
      if (BuildProfile.DEBUG && this.media) {
        try {
          if (await new DemoDataRepository(this.db, context, this.media).load(true)) {
            this.reportNotice('已载入原神与绝区零示例数据，可直接编辑和调试');
          }
        } catch (error) { this.reportNotice('示例数据载入未完成，可在开发者选项中重试'); }
      }
      await this.refresh();
      this.ready = true;
    }, false);
  }
  async maintain(): Promise<void> {
    if (!this.ready || this.busy) { return; }
    await this.perform(async () => {
      await this.media?.collect(this.photos, this.references, this.entries);
      try { await this.reminder.reconcile(this.events); }
      catch (error) { this.reportNotice('系统提醒暂未核对，可重新打开应用后重试'); }
    }, false);
  }

  dispose(): Promise<void> {
    if (!this.disposeTask) {
      this.suspend();
      this.disposeTask = this.closeAfterTasks().finally((): void => { this.disposeTask = undefined; });
    }
    return this.disposeTask;
  }

  private async closeAfterTasks(): Promise<void> {
    // 初始化、写入和偏好保存完成后再关闭，避免销毁期间切断事务或重新置 ready。
    try {
      await this.startTask;
      await this.operationTask;
      await this.reloadTask;
      await this.settingsQueue;
      await this.preferencesTask;
    } catch (error) {
      this.reportError('结束应用任务时发生错误，下次启动将重新加载');
    } finally {
      try { await this.db.close(); }
      catch (error) { this.reportError('数据库关闭未完成，下次启动将重新加载'); }
      this.ready = false; this.staleScopes = []; this.lastOperation = { status: 'ok' };
      this.context = undefined;
      this.media = undefined;
      this.preferencesTask = undefined;
    }
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
  async refresh(scopes: string[] = DATA_SCOPES): Promise<void> {
    const snapshot = new DataSnapshot();
    if (scopes.includes('entries')) { snapshot.entries = await this.entryRepo.list(); }
    if (scopes.includes('team')) { snapshot.team = await this.planningRepo.team(); }
    if (scopes.includes('expenses')) { snapshot.expenses = await this.planningRepo.expenses(); }
    if (scopes.includes('references')) { snapshot.references = await this.planningRepo.references(); }
    if (scopes.includes('characters')) { snapshot.characters = await this.characterRepo.list(); }
    if (scopes.includes('variants')) { snapshot.variants = await this.variantRepo.list(); }
    if (scopes.includes('projects')) { snapshot.projects = await this.projectRepo.list(); }
    if (scopes.includes('assets')) { snapshot.assets = await this.assetRepo.list(); }
    if (scopes.includes('preparationCategories')) { snapshot.preparationCategories = await this.preparationRepo.categories(); }
    if (scopes.includes('preparationTasks')) { snapshot.preparationTasks = await this.preparationRepo.tasks(); }
    if (scopes.includes('events')) { snapshot.events = await this.eventRepo.list(); }
    if (scopes.includes('checklist')) { snapshot.checklist = await this.checklistRepo.list(); }
    if (scopes.includes('photos')) { snapshot.photos = await this.photoRepo.list(); }
    if (scopes.includes('links')) { snapshot.links = await this.relations.links(); }
    if (scopes.includes('diary')) { snapshot.diary = await this.diaryRepo.list(); }
    // Publish a coherent snapshot only after all dependent reads succeed.
    if (scopes.includes('team')) { this.team = snapshot.team; }
    if (scopes.includes('expenses')) { this.expenses = snapshot.expenses; }
    if (scopes.includes('references')) { this.references = snapshot.references; }
    if (scopes.includes('characters')) { this.characters = snapshot.characters; }
    if (scopes.includes('variants')) { this.variants = snapshot.variants; }
    if (scopes.includes('projects')) { this.projects = snapshot.projects; }
    if (scopes.includes('assets')) { this.assets = snapshot.assets; }
    if (scopes.includes('preparationCategories')) { this.preparationCategories = snapshot.preparationCategories; }
    if (scopes.includes('preparationTasks')) { this.preparationTasks = snapshot.preparationTasks; }
    if (scopes.includes('events')) { this.events = snapshot.events; }
    if (scopes.includes('checklist')) { this.checklist = snapshot.checklist; }
    if (scopes.includes('photos')) { this.photos = snapshot.photos; }
    if (scopes.includes('links')) { this.links = snapshot.links; }
    if (scopes.includes('diary')) { this.diary = snapshot.diary; }
    if (scopes.includes('entries')) { this.entries = snapshot.entries; }
    this.localDate = today();
  }
  @Computed
  get readinessPlans(): PlanReadiness[] {
    return this.projects.map((project: CosProject) => buildPlanReadiness(project, this.preparationTasks, this.checklist, this.assets, this.links, this.photos, this.expenses, this.events, this.localDate));
  }
  readiness(id: string): PlanReadiness { return this.readinessPlans.find((item: PlanReadiness) => item.id === id) || new PlanReadiness(); }
  @Computed
  get actionablePlans(): PlanReadiness[] { return this.readinessPlans.filter((item: PlanReadiness) => item.active); }
  @Computed
  get taskQueue(): TaskQueueItem[] { return buildTaskQueue(this.readinessPlans, this.projects, this.localDate); }
  @Computed
  get actionItems(): TaskQueueItem[] { return this.taskQueue.filter(taskNeedsAction); }
  @Computed
  get waitingItems(): TaskQueueItem[] { return this.taskQueue.filter((item: TaskQueueItem) => item.kind === 'waiting'); }
  @Computed
  get todayEvents(): CosEvent[] { return dayEntries(this.events, this.dayDismissals, this.clockTime); }
  tickClock(): void { this.clockTime = Date.now(); this.localDate = localDay(this.clockTime); }
  dismissDayEntry(id: string): Promise<boolean> {
    return this.enqueueSettings(async (): Promise<void> => {
      const dismissals: Record<string, string> = {}; const date = localDay(Date.now());
      for (const key of Object.keys(this.dayDismissals)) { if (this.dayDismissals[key] === date) { dismissals[key] = date; } }
      dismissals[id] = date; await setDayDismissals(dismissals); this.dayDismissals = dismissals;
    });
  }
  configureDayModule(id: string, enabled?: boolean, move: number = 0): Promise<boolean> {
    return this.enqueueSettings(async (): Promise<void> => {
      const module = DAY_MODULES.find((item) => item.id === id); if (!module) { return; }
      const preferences = JSON.parse(JSON.stringify(this.dayModules)) as DayModulePreferences;
      const modules = orderedDayModules(preferences, module.section); const index = modules.findIndex((item) => item.id === id);
      if (move !== 0 && index + move >= 0 && index + move < modules.length) {
        const other = modules[index + move]; modules[index + move] = modules[index]; modules[index] = other;
      }
      modules.forEach((item, order: number): void => { preferences[item.id] = { enabled: item.id === id && enabled !== undefined ? enabled : preferences[item.id]?.enabled !== false, order: order }; });
      await setDayModules(preferences); this.dayModules = preferences;
    });
  }
  reloadRecords(): Promise<boolean> {
    if (this.reloadTask) { return this.reloadTask; }
    if (this.busy || this.disposeTask) { return Promise.resolve(false); }
    this.reloadTask = this.reloadSnapshot().finally((): void => { this.reloadTask = undefined; });
    return this.reloadTask;
  }
  private async reloadSnapshot(): Promise<boolean> {
    this.busy = true;
    try {
      await this.refresh(this.staleScopes.length ? this.staleScopes : DATA_SCOPES);
      this.staleScopes = []; this.error = ''; this.lastOperation = { status: 'ok' };
      this.reportNotice('显示已更新'); return true;
    } catch (error) { this.reportError('重新加载失败，已保存的记录保留，请重试加载。'); return false; }
    finally { this.busy = false; }
  }
  reportError(message: string): void { this.error = message; this.feedbackVersion++; }
  reportNotice(message: string): void { this.notice = message; this.feedbackVersion++; }
  // Existing boolean callers interpret true as committed, never as a refresh guarantee.
  perform(action: () => Promise<void>, refresh: boolean = true, scopes: string[] = DATA_SCOPES): Promise<boolean> {
    return this.performResult(action, refresh, scopes).then(operationCommitted);
  }
  performResult(action: () => Promise<void>, refresh: boolean = true, scopes: string[] = DATA_SCOPES): Promise<OperationResult> {
    if (this.busy || this.disposeTask) { return Promise.resolve<OperationResult>({ status: 'failed', detail: '已有数据操作进行中' }); }
    if (this.staleScopes.length) {
      const detail = '记录已保存，但显示尚未更新。请先重新加载，避免重复操作。';
      this.reportError(detail); return Promise.resolve<OperationResult>({ status: 'failed', detail: detail });
    }
    this.operationTask = this.runOperation(action, refresh, scopes).finally((): void => { this.operationTask = undefined; });
    return this.operationTask;
  }
  private async runOperation(action: () => Promise<void>, refresh: boolean, scopes: string[]): Promise<OperationResult> {
    this.busy = true; this.operationScope = scopes.join(','); this.error = ''; this.notice = ''; this.operationPartial = false;
    try {
      const result = await executeOperation(async (): Promise<void> => {
        try { await action(); }
        catch (error) {
          const code = (error as BusinessError).code;
          throw new Error(code ? (code === 14800029 || code === 13900028 ? '设备空间不足，请释放空间后重试' : '本地操作未完成，请重试。仍有问题时可重新打开应用。') : (error as Error).message || '操作失败，请重试');
        }
      }, async (): Promise<void> => { if (refresh) { await this.refresh(scopes); } });
      if (result.status === 'ok' && this.operationPartial) { result.status = 'partial'; result.detail = this.notice; }
      this.lastOperation = result;
      if (result.status === 'savedNotRefreshed') { this.staleScopes = scopes; this.reportError(result.detail || '记录已保存，请重新加载'); }
      else if (result.status === 'failed') { this.reportError(result.detail || '操作失败，请重试'); }
      return result;
    } finally { this.busy = false; this.operationScope = ''; }
  }
  @Computed
  get untriagedEntries(): CollectedEntry[] { return this.entries.filter((entry: CollectedEntry) => entry.scopeKind === 'global'); }
  saveEntry(entry: CollectedEntry): Promise<OperationResult> {
    return this.performResult(async () => { await this.entryRepo.save(entry); }, true, ['entries']);
  }
  captureEntry(text: string, scopeKind: string = 'global', scopeId: string = ''): Promise<OperationResult> {
    return this.performResult(async () => { await this.entryRepo.save(entryFromText(text, scopeKind, scopeId)); }, true, ['entries']);
  }
  captureEntryImage(scopeKind: string = 'global', scopeId: string = ''): Promise<OperationResult> {
    return this.performResult(async () => {
      if (!this.media) { throw new Error('图片选择暂不可用，请重试'); }
      const uris = await this.media.select(1); if (!uris.length) { return; }
      const media = await this.media.import(uris[0], '');
      const entry = new CollectedEntry(); entry.id = media.id; entry.kind = 'image';
      entry.scopeKind = scopeKind; entry.scopeId = scopeId; entry.localPath = media.localPath; entry.thumbnailPath = media.thumbnailPath;
      try { await this.entryRepo.save(entry); }
      catch (error) { await this.media.remove(media); throw error as Error; }
    }, true, ['entries']);
  }
  repairEntryImage(entry: CollectedEntry): Promise<OperationResult> {
    return this.performResult(async () => {
      if (!this.media || !this.entries.some((item: CollectedEntry) => item.id === entry.id)) { throw new Error('收录已不存在，请重新加载'); }
      const uris = await this.media.select(1); if (!uris.length) { return; }
      const media = await this.media.import(uris[0], '');
      const copy = JSON.parse(JSON.stringify(entry)) as CollectedEntry; copy.localPath = media.localPath; copy.thumbnailPath = media.thumbnailPath;
      try { await this.entryRepo.save(copy); }
      catch (error) { await this.media.remove(media); throw error as Error; }
      await this.media.remove(entry);
    }, true, ['entries']);
  }
  convertEntry(entry: CollectedEntry, kind: string, scopeKind: string, scopeId: string, amount: string, date: string): Promise<OperationResult> {
    return this.performResult(async () => {
      if (kind === 'reference' && (!this.media || !await this.media.exists(entry))) { throw new Error('图片缺失，请先重新选图'); }
      await this.entryRepo.convert(entry, kind, scopeKind, scopeId, amount, date);
      // Task/expense conversions no longer retain the attachment's media.
      if (kind !== 'reference') { await this.media?.remove(entry); }
    }, true, ['entries', 'preparationCategories', 'preparationTasks', 'expenses', 'references']);
  }
  removeEntry(entry: CollectedEntry): Promise<OperationResult> {
    return this.performResult(async () => { await this.entryRepo.remove(entry.id); await this.media?.remove(entry); }, true, ['entries']);
  }
  async saveCharacter(item: Character): Promise<boolean> {
    return this.perform(async () => {
      item.name = requiredName(item.name);
      item.updatedAt = Date.now();
      await this.characterRepo.save(item);
    }, true, ['characters']);
  }
  async saveVariant(item: CharacterVariant): Promise<boolean> {
    return this.perform(async () => {
      item.name = requiredName(item.name);
      if (!item.characterId) {
        throw new Error('请先选择角色');
      }
      await this.variantRepo.save(item);
    }, true, ['variants']);
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
      if (item.status === ProjectStatus.READY || item.status === ProjectStatus.COMPLETED) {
        void HapticService.confirm(this.settings.haptic, this.settings.hapticLevel).catch((): void => {});
      }
    }, true, ['projects', 'characters', 'diary', 'preparationCategories', 'preparationTasks']);
  }
  async saveAsset(item: Asset, projectId: string = ''): Promise<boolean> {
    return this.perform(async () => {
      item.name = requiredName(item.name);
      item.purchaseUrl = safeUrl(item.purchaseUrl);
      await this.assetRepo.save(item, projectId);
    }, true, ['assets', 'links', 'checklist']);
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
      if (warning) { this.operationPartial = true; this.reportNotice(warning); }
    }, true, ['events']);
  }
  async saveTeam(item: TeamMember): Promise<boolean> { return this.perform(async () => { await this.planningRepo.saveTeam(item); }, true, ['team']); }
  async saveExpense(item: Expense): Promise<boolean> { return this.perform(async () => { await this.planningRepo.saveExpense(item); }, true, ['expenses']); }
  async saveReference(item: ReferenceImage): Promise<boolean> {
    return this.perform(async () => {
      await this.planningRepo.saveReference(item);
    }, true, ['references']);
  }
  async importReferences(projectId: string = '', characterId: string = ''): Promise<boolean> {
    return this.perform(async () => {
      if (!this.media || (!projectId && !characterId) || (projectId && characterId)) { throw new Error('请选择参考图所属计划或角色'); }
      if (projectId && !this.projects.some((p: CosProject) => p.id === projectId)) { throw new Error('计划已不存在'); }
      if (characterId && !this.characters.some((c: Character) => c.id === characterId)) { throw new Error('角色已不存在'); }
      const uris = await this.media.select(); let count = 0; let failed = 0; let skipped = 0;
      if (uris.length === 0) { return; }
      const seen: string[] = [];
      for (const uri of uris) {
        if (seen.includes(uri)) { skipped++; continue; }
        seen.push(uri);
        const old = this.references.find((r: ReferenceImage) => r.projectId === projectId && r.characterId === characterId && r.sourceUri === uri);
        if (old && await this.media.exists(old)) { skipped++; continue; }
        let imported: ReferenceImage | undefined;
        try {
          imported = await this.media.importReference(uri, projectId, characterId);
          if (old) { imported.id = old.id; imported.caption = old.caption; }
          await this.planningRepo.saveReference(imported); count++;
        } catch (error) { if (imported) { await this.media.remove(imported); } failed++; }
      }
      if (failed > 0 && count === 0) { throw new Error('参考图未添加，' + failed + ' 张失败，跳过重复 ' + skipped + ' 张。请检查格式或空间后重试。'); }
      this.operationPartial = failed > 0;
      this.reportNotice((count ? '已添加 ' + count + ' 张参考图，' : '') + '跳过重复 ' + skipped + ' 张，失败 ' + failed + ' 张' + (failed ? '。可重试失败项。' : ''));
    }, true, ['references']);
  }
  async referenceCover(item: ReferenceImage): Promise<boolean> {
    return this.perform(async () => {
      const characterId = item.characterId || this.projects.find((p: CosProject) => p.id === item.projectId)?.characterId || '';
      if (!characterId || !item.thumbnailPath) { throw new Error('参考图缺失，请重新导入'); }
      await this.planningRepo.setReferenceCover(item, characterId);
    }, true, ['characters']);
  }
  async savePreparationCategory(item: PreparationCategory): Promise<boolean> {
    return this.perform(async () => { await this.preparationRepo.saveCategory(item); }, true, ['preparationCategories']);
  }
  async savePreparationTask(item: PreparationTask): Promise<boolean> {
    return this.perform(async () => { await this.preparationRepo.saveTask(item); }, true, ['preparationTasks']);
  }
  async togglePreparation(item: PreparationTask): Promise<boolean> {
    return this.perform(async () => {
      await this.preparationRepo.setDone(item.id, !item.done);
      if (!item.done) {
        void HapticService.confirm(this.settings.haptic, this.settings.hapticLevel).catch((): void => {});
      }
    }, true, ['preparationTasks']);
  }
  async addPreparationTemplate(projectId: string, keys: string[]): Promise<boolean> {
    return this.perform(async () => {
      await this.preparationRepo.addTemplate(makePreparation(projectId, keys));
      this.reportNotice('已补入所选模板任务，原有进度保留');
    }, true, ['preparationCategories', 'preparationTasks']);
  }
  preparationPercent(projectId: string): number { return this.readiness(projectId).prep.percent; }
  async addChecklist(projectId: string, label: string): Promise<boolean> {
    return this.perform(async () => {
      const item = new ChecklistItem();
      item.projectId = projectId;
      item.label = requiredName(label);
      item.sortOrder = this.checklist.length;
      await this.checklistRepo.save(item);
    }, true, ['checklist']);
  }
  async toggleChecklist(item: ChecklistItem): Promise<boolean> {
    return this.perform(async () => {
      const copy = JSON.parse(JSON.stringify(item)) as ChecklistItem; copy.done = !item.done;
      await this.checklistRepo.save(copy); if (copy.done) { void HapticService.confirm(this.settings.haptic, this.settings.hapticLevel).catch((): void => {}); }
    }, true, ['checklist']);
  }
  async linkAsset(projectId: string, asset: Asset): Promise<boolean> {
    return this.perform(async () => { await this.relations.link(projectId, asset); }, true, ['links', 'checklist']);
  }
  async unlinkAsset(projectId: string, assetId: string): Promise<boolean> {
    return this.perform(async () => { await this.relations.unlink(projectId, assetId); }, true, ['links', 'checklist']);
  }
  async generateChecklist(projectId: string): Promise<boolean> {
    return this.perform(async () => {
      await this.relations.generateChecklist(projectId, this.projectAssets(projectId), this.checklist);
    }, true, ['checklist']);
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
        await this.projectRepo.remove(id);
        for (const r of refs) {
          await this.media?.remove(r);
        }
        for (const photo of photos) {
          await this.media?.remove(photo);
        }
      } else if (kind === 'asset') { await this.assetRepo.remove(id); }
      else if (kind === 'event') {
        const old = this.events.find((e: CosEvent) => e.id === id);
        await this.eventRepo.remove(id);
        if (old) {
          try {
            await this.reminder.cancel(old.reminderId);
          } catch (error) {
            this.reportNotice('活动已删除，提醒取消失败，重新打开应用后会再次清理');
          }
        }
      }
      else if (kind === 'variant') {
        if (this.projects.some((p: CosProject) => p.variantId === id)) {
          throw new Error('请先在计划中取消此版本关联');
        }
        await this.variantRepo.remove(id);
      }
      else if (kind === 'team') { await this.planningRepo.removeTeam(id); }
      else if (kind === 'expense') { await this.planningRepo.removeExpense(id); }
      else if (kind === 'reference') {
        const r = this.references.find((r: ReferenceImage) => r.id === id);
        if (r) {
          await this.planningRepo.removeReference(r);
          await this.media?.remove(r);
        }
      }
      else if (kind === 'preparation') { await this.preparationRepo.removeTask(id); }
      else if (kind === 'category') { await this.preparationRepo.removeCategory(id); }
      else if (kind === 'checklist') { await this.checklistRepo.remove(id); }
      else if (kind === 'photo') {
        const photo = this.photos.find((p: PhotoAsset) => p.id === id);
        await this.photoRepo.remove(id);
        if (photo) {
          await this.media?.remove(photo);
        }
      }
    });
  }
  async importPhotos(projectId: string): Promise<boolean> {
    return this.perform(async () => {
      if (!this.media || !this.projects.some((p: CosProject) => p.id === projectId)) { throw new Error('请先选择照片所属计划'); }
      const uris = await this.media.select(); let count = 0; let failed = 0; let skipped = 0;
      if (uris.length === 0) { return; }
      const seen: string[] = [];
      for (const uri of uris) {
        if (seen.includes(uri)) { skipped++; continue; }
        seen.push(uri);
        const existing = this.photos.find((p: PhotoAsset) => p.projectId === projectId && p.sourceUri === uri);
        if (existing && await this.media.exists(existing)) { skipped++; continue; }
        let imported: PhotoAsset | undefined;
        try {
          imported = await this.media.import(uri, projectId);
          if (existing) {
            imported.id = existing.id;
            imported.status = existing.status;
            imported.caption = existing.caption;
            await this.photoRepo.save(imported);
          }
          else { await this.relations.addPhoto(imported); }
          count++;
        } catch (error) { if (imported) { await this.media.remove(imported); } failed++; }
      }
      if (failed > 0 && count === 0) { throw new Error('照片未导入，' + failed + ' 张失败，跳过重复 ' + skipped + ' 张。请检查格式或空间后重试。'); }
      this.operationPartial = failed > 0;
      this.reportNotice((count ? '已导入 ' + count + ' 张，' : '') + '跳过重复 ' + skipped + ' 张，失败 ' + failed + ' 张' + (failed ? '。可重试失败项。' : ''));
    }, true, ['photos']);
  }
  async setPhotoStatus(photo: PhotoAsset, status: PhotoStatus): Promise<boolean> {
    return this.perform(async () => {
      const copy = JSON.parse(JSON.stringify(photo)) as PhotoAsset;
      copy.status = status;
      await this.photoRepo.save(copy);
      if (status === PhotoStatus.SELECTED) {
        void HapticService.confirm(this.settings.haptic, this.settings.hapticLevel).catch((): void => {});
      }
    }, true, ['photos']);
  }
  async setPhotoStatuses(ids: string[], status: PhotoStatus): Promise<boolean> {
    return this.perform(async () => {
      await this.photoRepo.setStatuses(ids, status);
      this.reportNotice('已更新 ' + ids.length + ' 张照片');
      void HapticService.confirm(this.settings.haptic, this.settings.hapticLevel).catch((): void => {});
    }, true, ['photos']);
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
    this.settingsQueue = result.then((): void => { });
    return result;
  }
  async updateSettings(changes: SettingsSelection): Promise<boolean> {
    if (!this.context) { return false; }
    return this.enqueueSettings(async () => {
      if (this.context) {
        // 在队列执行时合并，避免一行的旧快照覆盖另一行刚保存的选择。
        const settings = JSON.parse(JSON.stringify(this.settings)) as AppSettings;
        if (changes.appearance !== undefined) { settings.appearance = changes.appearance; }
        if (changes.themeColor !== undefined) { settings.themeColor = changes.themeColor; }
        if (changes.hand !== undefined) { settings.hand = changes.hand; settings.grip = settings.hand === 'auto'; }
        if (settings.grip && !this.settings.grip) {
          try { await this.grip.authorize(this.context); }
          catch (error) { this.grip.stop(); this.sensedHand = 'auto'; throw error as Error; }
        }
        await this.preference.save(this.context, settings, this.settings); this.settings = settings;
        if (!settings.grip) { this.grip.stop(); this.sensedHand = 'auto'; }
      }
    });
  }
  suspend(): void { this.grip.stop(); this.sensedHand = 'auto'; }
  async resume(): Promise<void> {
    this.tickClock();
    if (this.settings.grip && this.context) {
      try {
        await this.grip.start(this.context, (hand: string) => {
          this.sensedHand = hand;
        });
      } catch (error) {
        this.sensedHand = 'auto';
      }
    }
  }
  async shareProject(id: string): Promise<boolean> {
    return this.perform(async () => {
      const p = this.projects.find((item: CosProject) => item.id === id);
      if (p && this.context) {
        await ShareService.project(this.context, ShareService.object(p, this.characters.find((c: Character) => c.id === p.characterId), this.events.find((e: CosEvent) => e.id === p.eventId)));
      }
    }, false);
  }
  async exportData(): Promise<boolean> {
    return this.perform(async () => {
      if (this.context && await new BackupService(this.db, this.context)
        .export()) { this.reportNotice('元数据已导出。原照片请使用系统备份另行保护。'); }
    }, false);
  }
  async loadDemoData(): Promise<boolean> {
    return this.perform(async (): Promise<void> => {
      if (!this.ready || !this.context || !this.media) { throw new Error('应用尚未就绪'); }
      const loaded = await new DemoDataRepository(this.db, this.context, this.media).load();
      this.reportNotice(loaded ? '已添加原神与绝区零示例数据' : '示例数据已存在，可直接编辑；清空数据后可重新载入');
    });
  }
  async restoreData(): Promise<boolean> {
    let restored = false;
    const success = await this.perform(async () => {
      if (this.context) { restored = await new BackupService(this.db, this.context).restore(); }
      if (restored) {
        const canceled = await this.cancelEventReminders();
        this.reportNotice('元数据已恢复。缺失图片需重新导入，活动提醒需在本机重新开启。' + (canceled ? '' : '旧提醒取消失败，重新打开应用后会再次清理。'));
      }
    });
    return success && restored;
  }
  private async cancelEventReminders(): Promise<boolean> {
    let canceled = true;
    for (const event of this.events) {
      try {
        await this.reminder.cancel(event.reminderId);
      } catch (error) {
        canceled = false;
        this.reportNotice('提醒清理未完成，重新打开应用后会重试');
      }
    }
    return canceled;
  }
  async clearData(): Promise<boolean> {
    return this.perform(async () => { await this.relations.clear(); await this.cancelEventReminders(); await this.media?.collect([]); });
  }
  projectAssets(id: string): Asset[] {
    const ids = this.links.filter((p: ProjectAsset) => p.projectId === id)
      .map((p: ProjectAsset) => p.assetId); return this.assets.filter((a: Asset) => ids.includes(a.id));
  }
  characterName(id: string): string { return this.characters.find((c: Character) => c.id === id)?.name || '未关联角色'; }
  projectName(id: string): string { return this.projects.find((p: CosProject) => p.id === id)?.name || '未关联计划'; }
  progress(id: string): number { return this.readiness(id).equipment.percent; }
  hand(): string { return this.settings.hand === 'auto' ? this.sensedHand : this.settings.hand; }
}
