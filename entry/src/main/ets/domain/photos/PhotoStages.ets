import { PhotoAsset, PhotoStatus } from '../../models/Entities';

export const PHOTO_STAGE_LABELS: string[] = ['待选', '已选', '待修', '已修', '成片', '归档'];

export const PHOTO_STAGE_STATUSES: PhotoStatus[][] = [
    [PhotoStatus.IMPORTED, PhotoStatus.RAW], [PhotoStatus.SELECTED], [PhotoStatus.WAITING],
    [PhotoStatus.RETOUCHED], [PhotoStatus.FINAL, PhotoStatus.PUBLISHED], [PhotoStatus.ARCHIVED],
];

export function photoStageIndex(status: PhotoStatus): number {
    return PHOTO_STAGE_STATUSES.findIndex((statuses: PhotoStatus[]) => statuses.includes(status));
}

export function photoStageCounts(photos: PhotoAsset[]): number[] {
    const counts: number[] = PHOTO_STAGE_LABELS.map((): number => 0);
    for (const photo of photos) {
        const index = photoStageIndex(photo.status);
        if (index >= 0) {
            counts[index]++;
        }
    }
    return counts;
}

export const PHOTO_FILTER_LABELS: string[] = ['全部'].concat(PHOTO_STAGE_LABELS).concat('已发布');

export const PHOTO_EDIT_STATUSES: PhotoStatus[] = [PhotoStatus.RAW, PhotoStatus.SELECTED, PhotoStatus.WAITING, PhotoStatus.RETOUCHED, PhotoStatus.FINAL, PhotoStatus.PUBLISHED, PhotoStatus.ARCHIVED];

export function photoStatusLabel(status: PhotoStatus): string {
    return status === PhotoStatus.PUBLISHED ? '已发布' : PHOTO_STAGE_LABELS[photoStageIndex(status)] || '状态未知';
}
// Runtime filter indexes follow the stage vocabulary; no business migration.

export function matchesPhotoFilter(status: PhotoStatus, filter: number): boolean {
    const stage = photoStageIndex(status);
    return filter === 0 || (filter >= 1 && filter <= 6 && stage === filter - 1) || (filter === 7 && status === PhotoStatus.PUBLISHED);
}
