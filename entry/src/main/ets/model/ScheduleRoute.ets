import { validDate } from './Rules';

function dateKey(date: Date): string {
  return String(date.getFullYear()).padStart(4, '0') + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0');
}

@ObservedV2
export class ScheduleRoute {
  @Trace calendar: boolean = false;
  @Trace selectedDate: string = '';
  @Trace dateFocused: boolean = false;
  @Trace year: number = new Date().getFullYear();
  @Trace month: number = new Date().getMonth();
  @Trace filter: number = 0;
  @Trace eventType: string = '';
  offsets: number[] = [0, 0];
  constructor(date: string) {
    this.selectDate(date); this.dateFocused = false;
  }
  selectDate(date: string): void {
    if (!validDate(date)) { return; }
    this.selectedDate = date; this.year = Number(date.slice(0, 4)); this.month = Number(date.slice(5, 7)) - 1;
    this.dateFocused = true; this.filter = 0;
  }
  showCalendar(value: boolean): void { this.calendar = value; if (value) { this.dateFocused = true; } }
  moveMonth(step: number): void {
    const next = new Date(this.year, this.month + step, 1, 12);
    const last = new Date(next.getFullYear(), next.getMonth() + 1, 0, 12).getDate();
    next.setDate(Math.min(Number(this.selectedDate.slice(8)) || 1, last));
    this.selectDate(dateKey(next));
  }
  showPending(): void { this.calendar = false; this.dateFocused = false; this.filter = 2; }
  clearDate(): void { this.dateFocused = false; this.filter = 0; }
}
