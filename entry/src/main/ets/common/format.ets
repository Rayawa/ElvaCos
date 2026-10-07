export function formatBytes(bytes: number | undefined): string {
  if (bytes === undefined || bytes === null) { return '-'; }
  return `${bytes} B`;
}

export function today(): string {
  const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function daysUntil(date: string): number { 
  return Math.ceil((new Date(date + 'T00:00:00').getTime() - new Date(today() + 'T00:00:00').getTime()) / 86400000); }
export function formatTime(time: number): string { 
  const d = new Date(time); 
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`; 
}
