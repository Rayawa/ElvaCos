@ObservedV2
export class LedgerRoute {
    @Trace section: number = 0;
    offsets: number[] = [0, 0];
    @Trace projectId: string = '';
    @Trace category: string = '';
    @Trace range: string = 'month';
    @Trace startDate: string = '';
    @Trace endDate: string = '';
    @Trace chartZoom: number = 1;
    @Trace chartPan: number = 0;
    @Trace restoreVersion: number = 0;
    sourceProjectId: string = '';

    get offset(): number {
        return this.offsets[this.section];
    }

    set offset(value: number) {
        this.offsets[this.section] = value;
    }

    constructor(projectId: string = '') {
        this.projectId = projectId;
        this.sourceProjectId = projectId;
    }
}
