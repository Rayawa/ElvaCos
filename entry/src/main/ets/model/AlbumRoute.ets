import { PhotoCollectionRoute } from './PhotoCollection';
import { CosProject, PhotoAsset } from './Entities';
@ObservedV2
export class AlbumRoute {
  @Trace mode: string = 'byPlan';
  @Trace byPlan: PhotoCollectionRoute = new PhotoCollectionRoute();
  @Trace queue: PhotoCollectionRoute = new PhotoCollectionRoute('', false, true);
  groupOffset: number = 0;
  @Trace restoreVersion: number = 0;
  constructor(planId: string = '', queue: boolean = false) { this.byPlan.planId = planId; this.mode = queue ? 'queue' : 'byPlan'; }
  get collection(): PhotoCollectionRoute { return this.mode === 'queue' ? this.queue : this.byPlan; }
  reconcile(projects: CosProject[], photos: PhotoAsset[], deletedPlanId: string = ''): void {
    [this.byPlan, this.queue].forEach((collection: PhotoCollectionRoute): void => {
      if (collection.planId && (collection.planId === deletedPlanId || !projects.some((project: CosProject) => project.id === collection.planId))) {
        collection.setPlan(''); collection.feedback = '所属计划已不存在，已返回全部场次 / 计划';
      }
      collection.reconcile(photos);
    });
  }
  showMode(mode: string): void {
    if (!['byPlan', 'queue'].includes(mode) || mode === this.mode || this.collection.submitting) { return; }
    const hadSelection = this.collection.selectedIds.length > 0;
    this.collection.clearSelection(); this.mode = mode; if (hadSelection) { this.collection.feedback = '模式已改变，已清空照片选择'; } this.restoreVersion++;
  }
}
