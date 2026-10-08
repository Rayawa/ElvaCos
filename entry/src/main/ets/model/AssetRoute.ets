import { WardrobeRoute } from './Wardrobe';
import { ProjectRoute } from './ProjectRoute';
import { TaskRoute } from './TaskQueue';
import { EventRoute } from './EventRoute';

@ObservedV2
export class AssetRoute {
  id: string;
  from: string;
  projectId: string;
  sourceTab: number;
  @Trace section: number = 0;
  @Trace linking: boolean = false;
  @Trace projectQuery: string = '';
  @Trace restoreVersion: number = 0;
  offsets: number[] = [0, 0];
  wardrobe?: WardrobeRoute;
  project?: ProjectRoute;
  event?: EventRoute;
  tasks?: TaskRoute;
  constructor(id: string, from: string = 'wardrobe', projectId: string = '', sourceTab: number = 3) {
    this.id = id; this.from = from; this.projectId = projectId; this.sourceTab = sourceTab;
  }
  restoreSource(deleted: boolean = false): void {
    if (this.wardrobe) {
      this.wardrobe.restoreVersion++;
      if (deleted) { this.wardrobe.feedback = '装备已删除，保留原筛选与附近位置'; this.wardrobe.anchorId = ''; }
    }
    if (this.project) { this.project.restoreVersion++; }
    if (this.event) { this.event.restoreVersion++; }
    if (this.tasks) { this.tasks.restoreVersion++; }
  }
}
