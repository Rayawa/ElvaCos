import { EditDraft } from './EditDraft';

export const FORM_KINDS: string[] = ['character', 'variant', 'project', 'asset', 'event', 'category', 'preparation', 'team', 'expense', 'reference', 'checklist', 'photo', 'shot'];
export interface FormDraftIO { read: () => Promise<string>; write: (value: string) => Promise<void>; }
export class StoredFormDraft {
  key: string = '';
  payload: string = '';
  baseline: string = '';
  savedAt: number = 0;
}
interface FormDraftFile { version: number; records: StoredFormDraft[]; }
export function formDraftKey(draft: EditDraft): string { return JSON.stringify([draft.kind, draft.id, draft.parentId]); }
export class FormDraftStore {
  private io: FormDraftIO;
  private pending: Promise<void> = Promise.resolve();
  constructor(io: FormDraftIO) { this.io = io; }
  private async records(): Promise<StoredFormDraft[]> {
    const text = await this.io.read(); if (!text) { return []; }
    const file = JSON.parse(text) as FormDraftFile;
    if (!file || file.version !== 1 || !Array.isArray(file.records)) { throw new Error('本地草稿格式无法读取，原草稿已保留'); }
    for (const record of file.records) {
      if (!record || typeof record.key !== 'string' || typeof record.payload !== 'string' || typeof record.baseline !== 'string' || typeof record.savedAt !== 'number' || !Number.isFinite(record.savedAt) || record.savedAt <= 0) { throw new Error('本地草稿格式无法读取，原草稿已保留'); }
      const draft = EditDraft.fromJSON(record.payload);
      const baseline = EditDraft.fromJSON(record.baseline);
      // The key identifies where editing began. Global expense entry can choose
      // a plan later without becoming a different recovery slot.
      if (!FORM_KINDS.includes(draft.kind) || formDraftKey(baseline) !== record.key || draft.kind !== baseline.kind || draft.id !== baseline.id) { throw new Error('草稿归属不匹配，原草稿已保留'); }
    }
    return file.records;
  }
  async load(key: string): Promise<StoredFormDraft | undefined> {
    await this.pending; return (await this.records()).find((record: StoredFormDraft) => record.key === key);
  }
  private change(action: (records: StoredFormDraft[]) => StoredFormDraft[]): Promise<void> {
    const task = this.pending.then(async (): Promise<void> => {
      const records = action(await this.records()); const file: FormDraftFile = { version: 1, records: records };
      await this.io.write(JSON.stringify(file));
    });
    this.pending = task.catch((): void => {}); return task;
  }
  save(record: StoredFormDraft): Promise<void> { return this.change((records: StoredFormDraft[]) => records.filter((item: StoredFormDraft) => item.key !== record.key).concat(record)); }
  remove(key: string): Promise<void> { return this.change((records: StoredFormDraft[]) => records.filter((record: StoredFormDraft) => record.key !== key)); }
  clear(): Promise<void> {
    const task = this.pending.then((): Promise<void> => this.io.write(''));
    this.pending = task.catch((): void => {}); return task;
  }
}
