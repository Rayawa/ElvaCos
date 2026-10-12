import { PhotoAsset } from './Entities';

export class PhotoImportFailure {
  uri: string; message: string;
  constructor(uri: string, message: string) { this.uri = uri; this.message = message; }
}
export interface PhotoImportPorts {
  find: (projectId: string, uri: string) => Promise<PhotoAsset | undefined>;
  exists: (photo: PhotoAsset) => Promise<boolean>;
  import: (uri: string, projectId: string) => Promise<PhotoAsset>;
  add: (photo: PhotoAsset) => Promise<void>;
  replace: (existing: PhotoAsset, imported: PhotoAsset) => Promise<void>;
  remove: (photo: PhotoAsset) => Promise<void>;
}

/** Runtime only: Picker grants and failed URIs are never business records. */
@ObservedV2
export class PhotoImportJob {
  @Trace phase: string = 'idle';
  @Trace projectId: string = '';
  @Trace total: number = 0;
  @Trace processed: number = 0;
  @Trace succeeded: number = 0;
  @Trace skipped: number = 0;
  @Trace cancelled: number = 0;
  @Trace failures: PhotoImportFailure[] = [];
  @Trace stopRequested: boolean = false;
  begin(projectId: string, phase: string = 'picking'): void {
    this.projectId = projectId; this.phase = phase; this.total = 0; this.processed = 0;
    this.succeeded = 0; this.skipped = 0; this.cancelled = 0; this.failures = []; this.stopRequested = false;
  }
  cancel(): void { if (this.phase === 'importing') { this.stopRequested = true; } }
  clear(): void { if (this.phase !== 'importing' && this.phase !== 'picking') { this.phase = 'idle'; this.failures = []; } }
  summary(): string {
    return '成功 ' + this.succeeded + ' 张，跳过重复 ' + this.skipped + ' 张，失败 ' + this.failures.length + ' 张' + (this.cancelled ? '，未处理 ' + this.cancelled + ' 张' : '');
  }
  async run(uris: string[], ports: PhotoImportPorts): Promise<void> {
    this.phase = 'importing'; this.total = uris.length;
    const seen: string[] = [];
    for (const uri of uris) {
      if (this.stopRequested) { this.cancelled = this.total - this.processed; break; }
      let staged: PhotoAsset | undefined;
      try {
        if (seen.includes(uri)) { this.skipped++; }
        else {
          seen.push(uri);
          // Read the committed repository each time, including earlier items in this batch.
          const existing = await ports.find(this.projectId, uri);
          if (existing && await ports.exists(existing)) { this.skipped++; }
          else {
            staged = await ports.import(uri, this.projectId);
            // Cancellation never deletes a committed item or interrupts a transaction.
            if (this.stopRequested) {
              await ports.remove(staged); staged = undefined; this.cancelled = this.total - this.processed; break;
            }
            if (existing) { await ports.replace(existing, staged); }
            else { await ports.add(staged); }
            staged = undefined; this.succeeded++;
          }
        }
      } catch (error) {
        let cleanup = '';
        if (staged) { try { await ports.remove(staged); } catch (failure) { cleanup = '；未提交文件清理未完成'; } }
        this.failures = this.failures.concat(new PhotoImportFailure(uri, ((error as Error).message || '图片无法读取或保存，请检查格式、授权与空间') + cleanup));
      }
      this.processed++;
    }
    this.phase = 'completed';
  }
}
