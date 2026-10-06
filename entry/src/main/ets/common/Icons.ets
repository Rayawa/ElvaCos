import { SymbolGlyphModifier } from '@kit.ArkUI';

// Match Dashboard: system resources for navigation and standard actions.
// Business pages use semantic names; replace an icon once here.
export class Icons {
  static home: Resource = $r('sys.media.return_home_fill');
  static cos: Resource = $r('sys.media.ohos_user_auth_icon_face');
  static event: Resource = $r('sys.media.ohos_ic_public_clock');
  static library: Resource = $r('sys.media.rectangle_filled_and_line_horizontal_and_rectangle');
  static me: Resource = $r('sys.media.person_badge_waveform');
  static user: Resource = $r('app.media.user');
  static vibration: Resource = $r('app.media.vibrate');
  static material: Resource = $r('app.media.immersive');
  static light: Resource = $r('app.media.light');
  static trash: Resource = $r('app.media.trash');
  static help: Resource = $r('app.media.question');
  static settings: Resource = $r('sys.symbol.gearshape');
  static add: Resource = $r('sys.media.ohos_ic_public_add');
  static edit: Resource = $r('sys.media.ohos_ic_public_edit');
  static share: Resource = $r('sys.media.ohos_ic_public_share');
  static check: Resource = $r('sys.media.ohos_ic_public_ok');
  static remove: Resource = $r('sys.media.ohos_ic_public_remove');
  static importPhoto: Resource = $r('sys.media.ohos_ic_public_albums');
  static cloud: Resource = $r('app.media.cloud');
  static toolbarAdd(): SymbolGlyphModifier { return new SymbolGlyphModifier($r('sys.symbol.plus')).fontColor([$r('sys.color.icon_primary')]); }
  static toolbarCover(): SymbolGlyphModifier { return new SymbolGlyphModifier($r('sys.symbol.picture')).fontColor([$r('sys.color.icon_primary')]); }
}
