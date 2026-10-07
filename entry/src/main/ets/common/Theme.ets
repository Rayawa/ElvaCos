import { CustomTheme } from '@kit.ArkUI';
import { DEFAULT_THEME_COLOR } from './constants';
import { resolveThemePalette } from './ThemePalettes';
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
 * 蓝色沿用 Dashboard 同名资源，其他配色通过同一语义入口替换资源引用。
 * 每组都有 base / dark 对应资源，ColorMode 独立决定深浅色；保留 Resource 对象，
 * 不提前解析成字符串，系统切换时无需手动监听配置或重建导航。
 */
@ObservedV2
class ThemeTokens {
  @Trace paletteId: string = DEFAULT_THEME_COLOR;
  @Trace nativeTheme: CustomTheme = {};
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
  /** 图形填充与强调文字独立，使浅色主题能明亮且易读；蓝色两者保持原值。 */
  @Trace brand: Resource = $r('app.color.diff_content');
  @Trace tint: Resource = $r('app.color.v3_surface_alt');
  @Trace shadow: Resource = $r('app.color.v3_shadow');
  @Trace scrim: Resource = $r('app.color.v3_scrim');
  @Trace releaseBadge: Resource = $r('app.color.v3_accent_orange');
  @Trace danger: Resource = $r('app.color.v3_accent_red');
  @Trace segmentedSelected: Resource = $r('app.color.segmented_color_selected');

  applyPalette(value: string): void {
    const palette = resolveThemePalette(value);
    this.paletteId = palette.id;
    this.bg = palette.bg;
    this.surface = palette.surface;
    this.ink = palette.ink;
    this.muted = palette.muted;
    this.line = palette.line;
    this.divider = palette.divider;
    this.groupDivider = palette.groupDivider;
    this.onAccent = palette.onAccent;
    this.accent = palette.accent;
    this.brand = palette.brand;
    this.tint = palette.tint;
    this.shadow = palette.shadow;
    // 蓝色保持原生控件原有默认风格；其他主题只覆盖强调色，系统负责中性色与警示色。
    this.nativeTheme = palette.id === DEFAULT_THEME_COLOR ? {} : {
      colors: {
        brand: palette.brand,
        fontEmphasize: palette.accent,
        iconEmphasize: palette.accent,
        iconSubEmphasize: palette.accent,
        backgroundEmphasize: palette.brand,
        compBackgroundEmphasize: palette.brand,
        fontOnPrimary: palette.onAccent,
        iconOnPrimary: palette.onAccent,
        interactiveFocus: palette.accent,
        interactiveActive: palette.brand,
      },
    };
    // 根 WithTheme 观察新对象即时更新；不改变系统默认主题，切回蓝色即可恢复原风格。
  }

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
