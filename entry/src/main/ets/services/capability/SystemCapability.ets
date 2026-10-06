import { HdsNavigationTitleBarOptions, HdsNavigationMenuItemOptions, HdsTabsFloatingStyle, hdsMaterial, BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from '../../common/Theme';
import { HDS_TITLE_SIZE_SMALL, SUPPORTS_HARMONY_API_23 } from '../../common/platformCompatibility';

export class SystemCapability {
  static effects(): boolean { return canIUse('SystemCapability.UIDesign.HDSComponent.Core'); }
  static haptic(): boolean { return canIUse('SystemCapability.Sensors.MiscDevice'); }
  static grip(): boolean { return canIUse('SystemCapability.MultimodalAwareness.Motion'); }
  static share(): boolean { return canIUse('SystemCapability.Collaboration.SystemShare'); }
  // Dashboard.ets titleBar style, with its title and setting injected by the caller.
  static titleBar(title: ResourceStr, enabled: boolean, level: number = 1, segment?: CustomBuilder, menus: HdsNavigationMenuItemOptions[] = []): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: { backgroundColor: $r('sys.color.comp_background_tertiary'), iconColor: $r('sys.color.icon_primary') },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: { backgroundColor: $r('sys.color.comp_background_tertiary'), iconColor: $r('sys.color.icon_primary') },
          },
        },
        systemMaterialEffect: SUPPORTS_HARMONY_API_23 ? {
          materialType: enabled ? hdsMaterial.MaterialType.ADAPTIVE : hdsMaterial.MaterialType.NONE,
          materialLevel: level,
        } : undefined,
      },
      content: { title: { mainTitle: title, mainTitleSize: HDS_TITLE_SIZE_SMALL, mainTitleAccessibilityText: title }, stackBuilder: segment, menu: { value: menus } },
    };
  }
  static tabs(enabled: boolean, level: number = 1): HdsTabsFloatingStyle {
    return {
      barBottomMargin: 28,
      lightColor: Theme.accent,
      gradientMask: { maskColor: Color.Transparent, maskHeight: 92 },
      systemMaterialEffect: {
        materialType: enabled ? hdsMaterial.MaterialType.ADAPTIVE : hdsMaterial.MaterialType.NONE,
        materialLevel: level,
      },
    };
  }
}
