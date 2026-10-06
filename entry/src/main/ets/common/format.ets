export function formatBytes(bytes: number | undefined): string {
  if (bytes === undefined || bytes === null) { return '-'; }
  return `${bytes} B`;
}
