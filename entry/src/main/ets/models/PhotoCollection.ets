import { PhotoAsset, PhotoStatus } from './Entities';
import { photoStage, portfolioStage } from '../domain/plans/Rules';
/** Runtime collection context, shared by album, plan photos and portfolio. */

@ObservedV2
export class PhotoCollectionRoute {
    @Trace planId: string = '';
    @Trace filter: number = 0;
    @Trace portfolio: boolean = false;
    @Trace queue: boolean = false;
    @Trace selecting: boolean = false;
    @Trace selectedIds: string[] = [];
    @Trace submitting: boolean = false;
    @Trace targetStatus: PhotoStatus = PhotoStatus.SELECTED;
    @Trace feedback: string = '';
    @Trace restoreVersion: number = 0;
    offset: number = 0;
    anchorId: string = '';
    private submittedIds: string[] = [];

    constructor(planId: string = '', portfolio: boolean = false, queue: boolean = false) {
        this.planId = planId;
        this.portfolio = portfolio;
        this.queue = queue;
    }

    clearSelection(message: string = ''): void {
        if (this.submitting) {
            return;
        }
        const hadSelection = this.selectedIds.length > 0;
        this.selectedIds = [];
        this.feedback = hadSelection ? message : '';
    }

    setFilter(filter: number): void {
        if (this.submitting || this.filter === filter) {
            return;
        }
        this.clearSelection('筛选已改变，已清空照片选择');
        this.filter = filter;
        this.offset = 0;
        this.anchorId = '';
    }

    setPlan(id: string): void {
        if (this.submitting || this.planId === id) {
            return;
        }
        this.clearSelection('计划范围已改变，已清空照片选择');
        this.planId = id;
        this.offset = 0;
        this.anchorId = '';
    }

    setPortfolio(value: boolean): void {
        if (this.submitting || this.portfolio === value) {
            return;
        }
        this.clearSelection('展示范围已改变，已清空照片选择');
        this.portfolio = value;
        this.filter = 0;
        this.offset = 0;
        this.anchorId = '';
    }

    toggle(id: string, photos: PhotoAsset[]): void {
        if (this.submitting || !this.selecting || !selectPhotoCollection(photos, this).some((photo: PhotoAsset) => photo.id === id)) {
            return;
        }
        this.selectedIds = this.selectedIds.includes(id) ? this.selectedIds.filter((selected: string) => selected !== id) : this.selectedIds.concat(id);
    }

    selectAll(photos: PhotoAsset[]): void {
        if (this.submitting || !this.selecting) {
            return;
        }
        const ids = selectPhotoCollection(photos, this).map((photo: PhotoAsset) => photo.id);
        const selected = new Set<string>(this.selectedIds);
        this.selectedIds = ids.length && ids.every((id: string) => selected.has(id)) ? [] : ids;
    }

    reconcile(photos: PhotoAsset[]): void {
        if (this.submitting) {
            return;
        }
        const visible = new Set<string>(selectPhotoCollection(photos, this).map((photo: PhotoAsset) => photo.id));
        const retained = this.selectedIds.filter((id: string) => visible.has(id));
        if (retained.length !== this.selectedIds.length) {
            this.selectedIds = retained;
            this.feedback = '照片范围已更新，已移除失效选择';
        }
    }

    begin(photos: PhotoAsset[]): string[] {
        if (this.submitting || !this.selecting) {
            return [];
        }
        this.reconcile(photos);
        if (!this.selectedIds.length) {
            return [];
        }
        this.submitting = true;
        this.submittedIds = this.selectedIds.slice();
        return this.submittedIds.slice();
    }

    finish(committed: boolean): void {
        if (committed) {
            this.selectedIds = [];
            this.selecting = false;
        } else {
            this.selectedIds = this.submittedIds.slice();
        }
        this.submittedIds = [];
        this.submitting = false;
    }
}

export function selectPhotoCollection(photos: PhotoAsset[], route: PhotoCollectionRoute): PhotoAsset[] {
    const scoped = photos.filter((photo: PhotoAsset) => (!route.planId || photo.projectId === route.planId) && (!route.queue || [PhotoStatus.IMPORTED, PhotoStatus.RAW, PhotoStatus.WAITING].includes(photo.status)));
    return route.portfolio ? portfolioStage(scoped, route.filter) : photoStage(scoped, route.filter);
}

export class PhotoViewerRoute {
    id: string;
    from: string;
    context: PhotoCollectionRoute;
    filterContext: string;
    visibleIds: string[];

    constructor(id: string, from: string, context: PhotoCollectionRoute, photos: PhotoAsset[]) {
        this.id = id;
        this.from = from;
        this.context = context;
        this.filterContext = JSON.stringify([context.planId, context.filter, context.portfolio, context.queue]);
        this.visibleIds = selectPhotoCollection(photos, context).map((photo: PhotoAsset) => photo.id);
        context.anchorId = id;
    }
}

export function returnToPhotoCollection(route: PhotoViewerRoute, photos: PhotoAsset[]): void {
    if (!selectPhotoCollection(photos, route.context).some((photo: PhotoAsset) => photo.id === route.id)) {
        route.context.feedback = '原照片已离开当前筛选，已保留范围与附近位置';
    }
    route.context.restoreVersion++;
}
