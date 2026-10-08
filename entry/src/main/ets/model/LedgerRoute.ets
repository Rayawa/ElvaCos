@ObservedV2
export class LedgerRoute {
  @Trace projectId: string = '';
  @Trace category: string = '';
  @Trace range: string = 'month';
  @Trace startDate: string = '';
  @Trace endDate: string = '';
  @Trace chartZoom: number = 1;
  @Trace chartPan: number = 0;
  @Trace restoreVersion: number = 0;
  sourceProjectId: string = '';
  offset: number = 0;
  constructor(projectId: string = '') { this.projectId = projectId; this.sourceProjectId = projectId; }
}
