import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Database } from '../storage/database/Database';
import { MetadataBackupRepository } from '../storage/repositories/MetadataBackupRepository';
import { MetadataBackupPreview } from '../../models/MetadataBackupPreview';

export interface BackupRestoreSelection {
    input: string;
    preview: MetadataBackupPreview;
}
// System document-picker boundary; metadata validation and SQL belong to the repository.

export class BackupService {
    private metadata: MetadataBackupRepository;
    private context: common.Context;

    constructor(db: Database, context: common.Context) {
        this.metadata = new MetadataBackupRepository(db);
        this.context = context;
    }

    async exportMetadata(): Promise<string> {
        return this.metadata.exportMetadata();
    }

    async export(): Promise<boolean> {
        const output = await this.exportMetadata();
        const uris = await new picker.DocumentViewPicker(this.context)
            .save({ newFileNames: ['ElvaCos-metadata-' + Date.now() + '.json'], fileSuffixChoices: ['JSON|.json'] });
        if (uris.length === 0) {
            return false;
        }
        const file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
            const bytes = util.TextEncoder.create('utf-8').encodeInto(output);
            if (await fs.write(file.fd, bytes.buffer as ArrayBuffer) !== bytes.byteLength) {
                throw new Error('备份文件未完整写入，请重新导出');
            }
        } finally {
            await fs.close(file);
        }
        return true;
    }

    async prepareRestore(): Promise<BackupRestoreSelection | undefined> {
        const uris = await new picker.DocumentViewPicker(this.context).select({ maxSelectNumber: 1, fileSuffixFilters: ['.json'] });
        if (uris.length === 0) {
            return undefined;
        }
        const file = await fs.open(uris[0], fs.OpenMode.READ_ONLY);
        let input: string;
        try {
            const stat = await fs.stat(file.fd);
            if (stat.size > 10 * 1024 * 1024 || stat.size === 0) {
                throw new Error('元数据文件为空或超过 10 MB');
            }
            const bytes = new ArrayBuffer(stat.size);
            let offset = 0;
            while (offset < stat.size) {
                const chunk = new ArrayBuffer(stat.size - offset);
                const count = await fs.read(file.fd, chunk, { offset: offset });
                if (count === 0) {
                    throw new Error('备份文件读取不完整');
                }
                new Uint8Array(bytes).set(new Uint8Array(chunk, 0, count), offset);
                offset += count;
            }
            input = new util.TextDecoder('utf-8').decodeToString(new Uint8Array(bytes));
        } finally {
            await fs.close(file);
        }
        return { input: input, preview: await this.metadata.previewMetadata(input) };
    }

    async restoreMetadata(input: string): Promise<void> {
        await this.metadata.restoreMetadata(input);
    }
}
