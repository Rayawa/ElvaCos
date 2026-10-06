// Each detail destination keeps its own task view when another detail is opened.
@ObservedV2
export class ProjectRoute {
  id: string = '';
  @Trace section: number = 0;
  @Trace outing: boolean = false;
  @Trace linking: boolean = false;
  constructor(id: string, section: number = 0) { this.id = id; this.section = section; }
}
