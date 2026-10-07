export class ArrayDataSource<T> implements IDataSource {
  private data: T[];
  private listeners: Set<DataChangeListener> = new Set<DataChangeListener>();
  constructor(data: T[]) { this.data = data; }
  totalCount(): number { return this.data.length; }
  getData(index: number): T { return this.data[index]; }
  registerDataChangeListener(listener: DataChangeListener): void { this.listeners.add(listener); }
  unregisterDataChangeListener(listener: DataChangeListener): void { this.listeners.delete(listener); }
  replace(data: T[]): void {
    this.data = data;
    this.listeners.forEach((listener: DataChangeListener): void => { listener.onDataReloaded(); });
  }
}
