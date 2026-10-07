import { DEFAULT_THEME_COLOR } from './constants';

/** 每组颜色均在 base / dark 定义同名资源；蓝色保留原资源，扩展配色不改变警示语义。 */
export interface ThemePalette {
  id: string;
  label: string;
  bg: Resource;
  surface: Resource;
  ink: Resource;
  muted: Resource;
  line: Resource;
  divider: Resource;
  groupDivider: Resource;
  onAccent: Resource;
  /** 明亮的按钮、滑块与色块用色。 */ brand: Resource;
  /** 背景上的可读强调文字用色。 */ accent: Resource;
  tint: Resource;
  shadow: Resource;
}

export const THEME_PALETTES: ThemePalette[] = [
  {
    id: 'blue', label: '蓝',
    bg: $r('app.color.background'),
    surface: $r('app.color.v3_surface'),
    ink: $r('app.color.v3_text_primary'),
    muted: $r('app.color.v3_text_secondary'),
    line: $r('app.color.nd_card_border'),
    divider: $r('app.color.border'),
    groupDivider: $r('app.color.v3_chart_grid'),
    onAccent: $r('app.color.on_accent'),
    brand: $r('app.color.diff_content'),
    accent: $r('app.color.diff_content'),
    tint: $r('app.color.v3_surface_alt'),
    shadow: $r('app.color.v3_shadow'),
  },
  {
    id: 'green', label: '绿',
    bg: $r('app.color.theme_green_bg'),
    surface: $r('app.color.theme_green_surface'),
    ink: $r('app.color.theme_green_ink'),
    muted: $r('app.color.theme_green_muted'),
    line: $r('app.color.theme_green_line'),
    divider: $r('app.color.theme_green_divider'),
    groupDivider: $r('app.color.theme_green_groupDivider'),
    onAccent: $r('app.color.theme_green_onAccent'),
    brand: $r('app.color.theme_green_brand'),
    accent: $r('app.color.theme_green_accent'),
    tint: $r('app.color.theme_green_tint'),
    shadow: $r('app.color.theme_green_shadow'),
  },
  {
    id: 'pink', label: '粉',
    bg: $r('app.color.theme_pink_bg'),
    surface: $r('app.color.theme_pink_surface'),
    ink: $r('app.color.theme_pink_ink'),
    muted: $r('app.color.theme_pink_muted'),
    line: $r('app.color.theme_pink_line'),
    divider: $r('app.color.theme_pink_divider'),
    groupDivider: $r('app.color.theme_pink_groupDivider'),
    onAccent: $r('app.color.theme_pink_onAccent'),
    brand: $r('app.color.theme_pink_brand'),
    accent: $r('app.color.theme_pink_accent'),
    tint: $r('app.color.theme_pink_tint'),
    shadow: $r('app.color.theme_pink_shadow'),
  },
  {
    id: 'orange', label: '橙',
    bg: $r('app.color.theme_orange_bg'),
    surface: $r('app.color.theme_orange_surface'),
    ink: $r('app.color.theme_orange_ink'),
    muted: $r('app.color.theme_orange_muted'),
    line: $r('app.color.theme_orange_line'),
    divider: $r('app.color.theme_orange_divider'),
    groupDivider: $r('app.color.theme_orange_groupDivider'),
    onAccent: $r('app.color.theme_orange_onAccent'),
    brand: $r('app.color.theme_orange_brand'),
    accent: $r('app.color.theme_orange_accent'),
    tint: $r('app.color.theme_orange_tint'),
    shadow: $r('app.color.theme_orange_shadow'),
  },
  {
    id: 'red', label: '红',
    bg: $r('app.color.theme_red_bg'),
    surface: $r('app.color.theme_red_surface'),
    ink: $r('app.color.theme_red_ink'),
    muted: $r('app.color.theme_red_muted'),
    line: $r('app.color.theme_red_line'),
    divider: $r('app.color.theme_red_divider'),
    groupDivider: $r('app.color.theme_red_groupDivider'),
    onAccent: $r('app.color.theme_red_onAccent'),
    brand: $r('app.color.theme_red_brand'),
    accent: $r('app.color.theme_red_accent'),
    tint: $r('app.color.theme_red_tint'),
    shadow: $r('app.color.theme_red_shadow'),
  },
];

export function normalizeThemeColor(value: string): string {
  return THEME_PALETTES.some((palette: ThemePalette) => palette.id === value) ? value : DEFAULT_THEME_COLOR;
}

export function resolveThemePalette(value: string): ThemePalette {
  return THEME_PALETTES.find((palette: ThemePalette) => palette.id === value) || THEME_PALETTES[0];
}
