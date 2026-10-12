import { InboxRoute } from './CollectedEntry';
export class EventReturnPath {
  name: string; param: Object;
  constructor(name: string, param: Object) { this.name = name; this.param = param; }
}
// Navigation context belongs to the destination instance, never the database.
@ObservedV2
export class EventRoute {
  id: string;
  @Trace dayMode: boolean;
  @Trace section: number = 0;
  @Trace configuring: boolean = false;
  @Trace recording: boolean = false;
  @Trace recordKind: number = -1;
  @Trace restoreVersion: number = 0;
  sourceTab: number = 2;
  returnPaths: EventReturnPath[] = [];
  entries: InboxRoute;
  offsets: number[] = [0, 0, 0, 0, 0, 0];
  constructor(id: string, dayMode: boolean = false, section: number = 0) { this.id = id; this.entries = new InboxRoute('event', id); this.dayMode = dayMode; this.section = section; }
}
