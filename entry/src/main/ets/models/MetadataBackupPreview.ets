export class BackupObjectCount {
    table: string = '';
    label: string = '';
    incoming: number = 0;
    current: number = 0;
}

export class MetadataBackupPreview {
    version: number = 0;
    exportedAt: number = 0;
    counts: BackupObjectCount[] = [];
    mediaWithoutLocalPath: number = 0;

    get incomingCount(): number {
        return this.counts.reduce((sum: number, count: BackupObjectCount) => sum + count.incoming, 0);
    }

    get currentCount(): number {
        return this.counts.reduce((sum: number, count: BackupObjectCount) => sum + count.current, 0);
    }
}
