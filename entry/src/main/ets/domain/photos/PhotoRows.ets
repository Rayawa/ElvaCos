import { PhotoAsset } from '../../models/Entities';
/** Layout grouping preserves the collection order and original photo objects. */

export function groupPhotoRows(photos: PhotoAsset[], columns: number): PhotoAsset[][] {
    const rows: PhotoAsset[][] = [];
    for (let index = 0; index < photos.length; index += columns) {
        rows.push(photos.slice(index, index + columns));
    }
    return rows;
}

export function indexPhotoRows(rows: PhotoAsset[][]): Map<string, number> {
    const index = new Map<string, number>();
    rows.forEach((row: PhotoAsset[], position: number): void => {
        row.forEach((photo: PhotoAsset): void => {
            index.set(photo.id, position);
        });
    });
    return index;
}

export function changedPhotoRows(index: Map<string, number>, previous: Set<string>, selected: Set<string>): number[] {
    const changed = new Set<number>();
    previous.forEach((id: string): void => {
        const row = index.get(id);
        if (!selected.has(id) && row !== undefined) {
            changed.add(row);
        }
    });
    selected.forEach((id: string): void => {
        const row = index.get(id);
        if (!previous.has(id) && row !== undefined) {
            changed.add(row);
        }
    });
    return Array.from(changed);
}
