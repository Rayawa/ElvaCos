import { InboxRoute } from './CollectedEntry';
import { PlanListRoute } from './PlanListRoute';
import { ProjectRoute } from './ProjectRoute';
/** Navigation and version selection are runtime context, never character data. */
@ObservedV2
export class CharacterRoute {
  id: string;
  @Trace section: number = 0;
  @Trace variantId: string = '';
  @Trace restoreVersion: number = 0;
  @Trace entriesOpen: boolean = false;
  entries: InboxRoute;
  offsets: number[] = [0, 0, 0];
  library?: PlanListRoute;
  project?: ProjectRoute;
  restoreSource(deleted: boolean = false): void {
    if (this.library) { this.library.restoreVersion++; if (deleted) { this.library.anchorId = ''; } }
    if (this.project) { this.project.restoreVersion++; }
  }
  constructor(id: string, variantId: string = '') { this.id = id; this.entries = new InboxRoute('character', id); this.variantId = variantId; }
}
