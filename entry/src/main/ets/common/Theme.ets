import {
  LAYOUT_CONTENT_TOP,
  LAYOUT_DETAIL_TOP,
  LAYOUT_DETAIL_TOP_WITH_SEGMENT,
  LAYOUT_CONTENT_BOTTOM,
  LAYOUT_HOME_CONTENT_BOTTOM,
  LAYOUT_TOOLBAR_BOTTOM_RESERVATION,
  LAYOUT_SECTION_SPACING,
  LAYOUT_SECTION_CONTENT_GAP,
  LAYOUT_SECTION_TITLE_PADDING,
  LAYOUT_CARD_RADIUS,
  LAYOUT_PAGE_PADDING,
  LAYOUT_WIDE_BREAKPOINT,
  LAYOUT_CONTENT_MAX_WIDTH,
  LAYOUT_WIDE_OVERVIEW_TOP,
  LAYOUT_WIDE_SCROLL_TOP,
  LAYOUT_MAIN_TABS_WIDTH,
  LAYOUT_TITLE_SEGMENT_WIDTH,
} from './constants';
/**
 * 全应用唯一的视觉令牌入口。
 *
 * 与 Dashboard 保持一致：颜色全部走同名资源，深浅色由 dark 资源目录解析。
 * 主题是一份 @ObservedV2 单例：颜色值来自 Dashboard 同名资源，深浅色由「应用外观」
 * （天蓝=浅色 / 雾蓝=深色 / 跟随系统）决定的 ColorMode 解析，切换后即时刷新。
 */
@ObservedV2
class ThemeTokens {
  @Trace transparent: Resource = $r('app.color.transparent');
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

  readonly contentTop: number = LAYOUT_CONTENT_TOP;
  /** 二级页面与一级页面共用同一套标题栏几何，顶部留白一致（与 Dashboard AppDetailPage 对照确认）。 */
  readonly detailTop: number = LAYOUT_DETAIL_TOP;
  /** 标题栏内还有分段按钮时，分段会向下溢出标题栏，内容再多留一点。 */
  readonly detailTopWithSegment: number = LAYOUT_DETAIL_TOP_WITH_SEGMENT;
  readonly contentBottom: number = LAYOUT_CONTENT_BOTTOM;
  readonly homeContentBottom: number = LAYOUT_HOME_CONTENT_BOTTOM;
  readonly toolbarBottomReservation: number = LAYOUT_TOOLBAR_BOTTOM_RESERVATION;
  readonly sectionSpacing: number = LAYOUT_SECTION_SPACING;
  readonly sectionContentGap: number = LAYOUT_SECTION_CONTENT_GAP;
  readonly sectionTitlePadding: number = LAYOUT_SECTION_TITLE_PADDING;
  readonly cardRadius: number = LAYOUT_CARD_RADIUS;
  readonly pagePadding: number = LAYOUT_PAGE_PADDING;
  readonly wideBreakpoint: number = LAYOUT_WIDE_BREAKPOINT;
  readonly contentMaxWidth: number = LAYOUT_CONTENT_MAX_WIDTH;
  readonly wideOverviewTop: number = LAYOUT_WIDE_OVERVIEW_TOP;
  readonly wideScrollTop: number = LAYOUT_WIDE_SCROLL_TOP;
  /** Dashboard 四项底栏为 250vp；五个业务入口沿用相同的单项密度。 */
  readonly mainTabsWidth: number = LAYOUT_MAIN_TABS_WIDTH;
  readonly titleSegmentWidth: Length = LAYOUT_TITLE_SEGMENT_WIDTH;
}

export const Theme: ThemeTokens = new ThemeTokens();
