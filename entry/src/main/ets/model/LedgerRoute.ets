@ObservedV2
export class LedgerRoute {
  @Trace projectId: string = '';
  @Trace category: string = '';
  offset: number = 0;
  constructor(projectId: string = '') { this.projectId = projectId; }
}
