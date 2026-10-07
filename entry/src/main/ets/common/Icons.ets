import { SymbolGlyphModifier } from '@kit.ArkUI';

/**
 * 图标集中定义。
 *
 * - 设置页 HdsListItemCard 的图标一律使用 app.media 里的浅/深两版 PNG，
 *   与 Dashboard 的 MyPage / SettingsPanel 用法一致（user / vibrate / immersive / light /
 *   trash / tutorial / privacy / right / cloud / export / load）。
 * - 导航、标题菜单与详情动作栏继续使用系统符号，跟随系统色调。
 */
export class Icons {
  // 一级导航与标题菜单
  static home: Resource = $r('sys.media.return_home_fill');
  static cos: Resource = $r('sys.media.ohos_user_auth_icon_face');
  static event: Resource = $r('sys.media.ohos_ic_public_clock');
  static library: Resource = $r('sys.media.rectangle_filled_and_line_horizontal_and_rectangle');
  static me: Resource = $r('sys.media.person_badge_waveform');
  static settings: Resource = $r('sys.symbol.gearshape');

  // 设置页列表项图标（app.media，浅/深各一版）
  static user: Resource = $r('app.media.user');
  static vibration: Resource = $r('app.media.vibrate');
  static material: Resource = $r('app.media.immersive');
  static light: Resource = $r('app.media.light');
  static trash: Resource = $r('app.media.trash');
  static help: Resource = $r('app.media.question');
  static tutorial: Resource = $r('app.media.tutorial');
  static privacy: Resource = $r('app.media.privacy');
  static cloud: Resource = $r('app.media.cloud');
  static exportData: Resource = $r('app.media.export');
  static restoreData: Resource = $r('app.media.load');
  static chevronRight: Resource = $r('app.media.right');

  // 详情与表单动作
  static add: Resource = $r('sys.media.ohos_ic_public_add');
  static edit: Resource = $r('sys.media.ohos_ic_public_edit');
  static share: Resource = $r('sys.media.ohos_ic_public_share');
  static check: Resource = $r('sys.media.ohos_ic_public_ok');
  static pending: Resource = $r('sys.symbol.circle');
  static remove: Resource = $r('sys.media.ohos_ic_public_remove');
  static importPhoto: Resource = $r('sys.media.ohos_ic_public_albums');
  static toolbarAdd(): SymbolGlyphModifier { 
  return new SymbolGlyphModifier($r('sys.symbol.plus')).fontColor([$r('sys.color.icon_primary')]); }
  static toolbarCover(): SymbolGlyphModifier { 
  return new SymbolGlyphModifier($r('sys.symbol.picture')).fontColor([$r('sys.color.icon_primary')]); }
}
