import { PhotoCollectionRoute } from './PhotoCollection';
// Each detail destination keeps its own task view when another detail is opened.
@ObservedV2
export class ProjectRoute {
  id: string = '';
  @Trace section: number = 0;
  @Trace outing: boolean = false;
  @Trace sheetKind: number = 0;
  @Trace preparing: boolean = false;
  @Trace linking: boolean = false;
  @Trace expandedCategories: string[] = [];
  @Trace photos: PhotoCollectionRoute;
  @Trace contextSheet: string = '';
  @Trace restoreVersion: number = 0;
  @Trace showCompleted: boolean = false;
  packingOrder: string[] = [];
  focusTaskId: string = '';
  focusPackingId: string = '';
  focusHandled: boolean = false;
  offsets: number[] = [0, 0, 0, 0];
  constructor(id: string, section: number = 0) { this.id = id; this.section = section; this.photos = new PhotoCollectionRoute(id); }
}
