import { PhotoAsset, PhotoStatus } from './Entities';

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
  for (const photo of photos) { const index = photoStageIndex(photo.status); if (index >= 0) { counts[index]++; } }
  return counts;
}
// Existing filter indexes are runtime UI state, not persisted business values.
export function matchesPhotoFilter(status: PhotoStatus, filter: number): boolean {
  const stage = photoStageIndex(status);
  return filter === 0 || stage === [0, 0, 1, 2, 4, 3, 5][filter] || (filter === 7 && status === PhotoStatus.PUBLISHED);
}
