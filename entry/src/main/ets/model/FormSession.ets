import { EditDraft } from './EditDraft';
import { AppState } from './ApplicationState';
import { FormDraftStore, StoredFormDraft, formDraftKey } from './FormDraftStore';

/** Runtime editing session; its drafts never enter business collections or backups. */
@ObservedV2
export class FormSession {
  @Trace draft: EditDraft;
  @Trace loading: boolean = true;
  @Trace recoveryChecked: boolean = false;
  @Trace skipDrafts: boolean = false;
  @Trace pendingRestore?: StoredFormDraft;
  @Trace recoveredAt: number = 0;
  @Trace savedAt: number = 0;
  @Trace saving: boolean = false;
  @Trace submitting: boolean = false;
  @Trace error: string = '';
  @Trace sourceChanged: boolean = false;
  private baseline: string;
  private key: string;
  private store: FormDraftStore;
  private timer: number = -1;
  private closed: boolean = false;
  private lastSaved: string = '';
  constructor(draft: EditDraft, store: FormDraftStore) { this.draft = draft; this.baseline = draft.fingerprint(); this.key = formDraftKey(draft); this.store = store; }
  get dirty(): boolean { return this.draft.fingerprint() !== this.baseline; }
  async initialize(state: AppState): Promise<void> {
    this.loading = true; this.recoveryChecked = false;
    try {
      const record = await this.store.load(this.key);
      this.recoveryChecked = true; this.error = '';
      if (record && EditDraft.fromJSON(record.payload).committedCreation(state)) {
        await this.store.remove(this.key); this.error = '上次创建已保存，已清理对应草稿；可以继续新建'; return;
      }
      if (!this.closed) { this.pendingRestore = record; }
    } catch (error) { this.recoveryChecked = false; this.error = '无法读取本地草稿：' + (error as Error).message; }
    finally { this.loading = false; }
  }
  ignoreRecovery(): void {
    this.skipDrafts = true; this.recoveryChecked = true; this.error = '本次未启用自动草稿，现有草稿保留';
  }
  restore(): void {
    const record = this.pendingRestore; if (!record || this.closed) { return; }
    this.sourceChanged = record.baseline !== this.baseline;
    this.draft = EditDraft.fromJSON(record.payload); this.recoveredAt = record.savedAt; this.savedAt = record.savedAt;
    this.lastSaved = this.draft.fingerprint(); this.pendingRestore = undefined;
  }
  async discardRecovery(): Promise<boolean> {
    const record = this.pendingRestore; if (!record) { return true; }
    try { await this.store.remove(this.key); this.pendingRestore = undefined; this.error = ''; return true; }
    catch (error) { this.error = '草稿未删除：' + (error as Error).message; return false; }
  }
  changed(): void {
    if (this.closed || this.loading || this.pendingRestore || !this.recoveryChecked || this.skipDrafts) { return; }
    this.cancelTimer(); this.timer = setTimeout((): void => { this.timer = -1; void this.flush(); }, 350);
  }
  private cancelTimer(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  async flush(): Promise<boolean> {
    this.cancelTimer(); if (this.closed || this.loading || this.pendingRestore || this.skipDrafts) { return true; }
    if (!this.recoveryChecked) { return false; }
    const fingerprint = this.draft.fingerprint(); if (fingerprint === this.lastSaved) { return true; }
    const record = new StoredFormDraft(); record.key = this.key; record.payload = this.draft.serialize(); record.baseline = this.baseline; record.savedAt = Date.now();
    this.saving = true;
    try {
      if (fingerprint === this.baseline) { await this.store.remove(this.key); } else { await this.store.save(record); }
      this.lastSaved = fingerprint; this.savedAt = fingerprint === this.baseline ? 0 : record.savedAt; this.error = ''; return true;
    } catch (error) { this.error = '草稿尚未保存：' + (error as Error).message; return false; }
    finally { this.saving = false; }
  }
  /** Call after a committed save or explicit abandonment; queued writes precede deletion. */
  async finish(discard: boolean, committed: boolean = false): Promise<boolean> {
    this.cancelTimer(); this.closed = true;
    if (discard && !this.skipDrafts) {
      try { await this.store.remove(this.key); }
      catch (error) { this.closed = committed; this.error = '草稿未清理：' + (error as Error).message; return false; }
    }
    this.closed = true; return true;
  }
}
