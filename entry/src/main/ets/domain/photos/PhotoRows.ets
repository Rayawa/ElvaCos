import { PhotoAsset } from '../../models/Entities';
/** Layout grouping preserves the collection order and original photo objects. */

export function groupPhotoRows(photos: PhotoAsset[], columns: number): PhotoAsset[][] {
    const rows: PhotoAsset[][] = [];
    for (let index = 0; index < photos.length; index += columns) {
        rows.push(photos.slice(index, index + columns));
    }
    return rows;
}
