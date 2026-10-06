export class ArrayDataSource<T> implements IDataSource {
  private data: T[];
  constructor(data: T[]) { this.data = data; }
  totalCount(): number { return this.data.length; }
  getData(index: number): T { return this.data[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {}
  unregisterDataChangeListener(listener: DataChangeListener): void {}
}
