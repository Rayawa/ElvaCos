export class Theme {
  static bg: ResourceColor = $r('app.color.background');
  static surface: ResourceColor = $r('app.color.v3_surface');
  static ink: ResourceColor = $r('app.color.v3_text_primary');
  static muted: ResourceColor = $r('app.color.v3_text_secondary');
  static line: ResourceColor = $r('app.color.nd_card_border');
  static onAccent: ResourceColor = $r('app.color.on_accent');
  static accent: ResourceColor = $r('app.color.diff_content');
  static tint: ResourceColor = $r('app.color.v3_surface_alt');
  static shadow: ResourceColor = $r('app.color.v3_shadow');
  static scrim: ResourceColor = $r('app.color.v3_scrim');
  static contentTop: number = 100;
  static contentBottom: number = 110;
  static homeContentBottom: number = 96;
  static toolbarBottomReservation: number = 96;
  static sectionSpacing: number = 14;
  static sectionContentGap: number = 8;
  static sectionTitlePadding: number = 4;
  static cardRadius: number = 16;
  static pagePadding: number = 14;
  static danger: ResourceColor = $r('app.color.v3_accent_red');
}
export function today(): string {
  const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function daysUntil(date: string): number { return Math.ceil((new Date(date + 'T00:00:00').getTime() - new Date(today() + 'T00:00:00').getTime()) / 86400000); }
export function formatTime(time: number): string { const d = new Date(time); return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`; }
