/**
 * 全应用唯一的视觉令牌入口。
 *
 * 与 Dashboard 保持一致：颜色全部走同名资源，深浅色由 dark 资源目录解析。
 * 主题是一份 @ObservedV2 单例：颜色值来自 Dashboard 同名资源，深浅色由「应用外观」
 * （天蓝=浅色 / 雾蓝=深色 / 跟随系统）决定的 ColorMode 解析，切换后即时刷新。
 */
/**
 * 应用外观三档（设置页顺序）：天蓝 = 浅色，跟随系统，雾蓝 = 深色。
 * 三档只切换应用的深浅色模式，颜色资源仍然是 Dashboard 那一套同名资源。
 */
export const APPEARANCE_LIGHT: string = 'sky';
export const APPEARANCE_DARK: string = 'mist';
export const APPEARANCE_SYSTEM: string = 'system';
export const APPEARANCE_VALUES: string[] = [APPEARANCE_LIGHT, APPEARANCE_SYSTEM, APPEARANCE_DARK];
export const APPEARANCE_LABELS: string[] = ['天蓝', '跟随系统', '雾蓝'];

/** 单手操作三档：左手、智感握持、右手。 */
export const HAND_VALUES: string[] = ['left', 'auto', 'right'];
export const HAND_LABELS: string[] = ['左手', '智感握持', '右手'];

@ObservedV2
class ThemeTokens {
  @Trace bg: Resource = $r('app.color.background');
  @Trace surface: Resource = $r('app.color.v3_surface');
  @Trace ink: Resource = $r('app.color.v3_text_primary');
  @Trace muted: Resource = $r('app.color.v3_text_secondary');
  @Trace line: Resource = $r('app.color.nd_card_border');
  @Trace divider: Resource = $r('app.color.border');
  @Trace groupDivider: Resource = $r('app.color.v3_chart_grid');
  @Trace onAccent: Resource = $r('app.color.on_accent');
  @Trace accent: Resource = $r('app.color.diff_content');
  @Trace tint: Resource = $r('app.color.v3_surface_alt');
  @Trace shadow: Resource = $r('app.color.v3_shadow');
  @Trace scrim: Resource = $r('app.color.v3_scrim');
  @Trace danger: Resource = $r('app.color.v3_accent_red');
  @Trace segmentedSelected: Resource = $r('app.color.segmented_color_selected');

  readonly contentTop: number = 100;
  /** 二级页面与一级页面共用同一套标题栏几何，顶部留白一致（与 Dashboard AppDetailPage 对照确认）。 */
  readonly detailTop: number = 100;
  /** 标题栏内还有分段按钮时，分段会向下溢出标题栏，内容再多留一点。 */
  readonly detailTopWithSegment: number = 112;
  readonly contentBottom: number = 110;
  readonly homeContentBottom: number = 96;
  readonly toolbarBottomReservation: number = 96;
  readonly sectionSpacing: number = 14;
  readonly sectionContentGap: number = 8;
  readonly sectionTitlePadding: number = 4;
  readonly cardRadius: number = 16;
  readonly pagePadding: number = 14;
  readonly wideBreakpoint: number = 840;
  readonly contentMaxWidth: number = 1440;
  readonly wideOverviewTop: number = 80;
  readonly wideScrollTop: number = 110;
  /** Dashboard 四项底栏为 250vp；五个业务入口沿用相同的单项密度。 */
  readonly mainTabsWidth: number = 250 * 5 / 4;
  readonly titleSegmentWidth: Length = '50%';
}

export const Theme: ThemeTokens = new ThemeTokens();

export function today(): string {
  const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function daysUntil(date: string): number { return Math.ceil((new Date(date + 'T00:00:00').getTime() - new Date(today() + 'T00:00:00').getTime()) / 86400000); }
export function formatTime(time: number): string { const d = new Date(time); return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`; }
