import {
  HdsNavigationTitleBarOptions,
  HdsNavigationMenuItemOptions,
  HdsTabsFloatingStyle,
  hdsMaterial,
  BlurStrategy,
  ScrollEffectType,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from './Theme';
import { HDS_TITLE_SIZE_SMALL, SUPPORTS_HARMONY_API_23 } from './constants';

export class SystemCapability {
  static effects(): boolean { return canIUse('SystemCapability.UIDesign.HDSComponent.Core'); }
  static haptic(): boolean { return canIUse('SystemCapability.Sensors.MiscDevice'); }
  static grip(): boolean { return canIUse('SystemCapability.MultimodalAwareness.Motion'); }
  static share(): boolean { return canIUse('SystemCapability.Collaboration.SystemShare'); }
  // Dashboard.ets / AppDetailPage.ets titleBar style, with title, segment, menu and back action injected by the caller.
  // avoidSafeArea 与 Dashboard 保持一致默认 false：HDS 自己已经避让状态栏，
  // 额外开启会让标题栏再下移一个状态栏高度（二级页面标题被推入内容区的原因）。
  static titleBar(title: ResourceStr, enabled: boolean, level: number = 1, segment?: CustomBuilder, menus: HdsNavigationMenuItemOptions[] = [], avoidSafeArea: boolean = false, backAction?: () => void): HdsNavigationTitleBarOptions {
    const options: HdsNavigationTitleBarOptions = {
      avoidLayoutSafeArea: avoidSafeArea,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: Theme.transparent },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: { backgroundColor: $r('sys.color.comp_background_tertiary'), iconColor: $r('sys.color.icon_primary') },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: Theme.transparent },
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
    if (backAction !== undefined && options.content !== undefined) {
      // 与 Dashboard AppDetailPage 一致：返回按钮走调用方动作，保证返回振动与栈操作不被 HDS 默认行为吞掉。
      options.content.backIcon = { action: backAction, componentId: 'title-back' };
    }
    return options;
  }
  static tabs(enabled: boolean, level: number = 1): HdsTabsFloatingStyle {
    return {
      barBottomMargin: 28,
      lightColor: Theme.brand,
      gradientMask: { maskColor: Theme.transparent, maskHeight: 92 },
      systemMaterialEffect: {
        materialType: enabled ? hdsMaterial.MaterialType.ADAPTIVE : hdsMaterial.MaterialType.NONE,
        materialLevel: level,
      },
    };
  }
}
