import { Expense } from './Planning';
import { PhotoAsset, PhotoStatus } from './Entities';

export interface MonthlyExpensePoint { label: string; value: number; detail: string; }
export interface PhotoDistributionItem { label: string; value: number; }

/** 以记账日期归月，先累计整数分；没有记录的月份补零。 */
export function monthlyExpenses(records: Expense[], date: string, count: number = 6): MonthlyExpensePoint[] {
  const points: MonthlyExpensePoint[] = [];
  const year = Number(date.slice(0, 4));
  const month = Number(date.slice(5, 7)) - 1;
  for (let offset = count - 1; offset >= 0; offset--) {
    const cursor = new Date(year, month - offset, 1, 12);
    const key = String(cursor.getFullYear()) + '-' + String(cursor.getMonth() + 1).padStart(2, '0');
    const matching = records.filter((record: Expense): boolean => record.date.slice(0, 7) === key);
    const cents = matching.reduce((sum: number, record: Expense): number => sum + record.amountCents, 0);
    points.push({ label: key, value: cents / 100, detail: key + ' · ¥' + (cents / 100).toFixed(2) + ' · ' + matching.length + ' 笔' });
  }
  return points;
}

/** 各照片状态仅落入一个分组，含已归档，合计与照片总数一致。 */
export function photoDistribution(photos: PhotoAsset[]): PhotoDistributionItem[] {
  const labels = ['待选', '已选', '待修', '成片', '已发布', '已归档'];
  const groups: PhotoStatus[][] = [
    [PhotoStatus.IMPORTED, PhotoStatus.RAW], [PhotoStatus.SELECTED], [PhotoStatus.WAITING],
    [PhotoStatus.RETOUCHED, PhotoStatus.FINAL], [PhotoStatus.PUBLISHED], [PhotoStatus.ARCHIVED],
  ];
  return labels.map((label: string, index: number): PhotoDistributionItem => ({
    label: label, value: photos.filter((photo: PhotoAsset): boolean => groups[index].includes(photo.status)).length,
  }));
}
