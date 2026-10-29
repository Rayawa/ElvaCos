import { SUPPORTS_API_23, HDS_MATERIAL_ADAPTIVE, HDS_MATERIAL_NONE } from './platformCompatibility';
import { displayName } from '../utils/format/format';
import { HdsNavigationTitleBarOptions, HdsNavigationMenuItemOptions, HdsTabsFloatingStyle, HdsTabsAttribute, BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from '../ui/theme/Theme';
import { HDS_TITLE_SIZE_SMALL, SUPPORTS_HARMONY_API_23 } from './constants';

export class SystemCapability {

    static effects(): boolean {
        return SUPPORTS_API_23 && canIUse('SystemCapability.UIDesign.HDSComponent.Core');
    }

    static haptic(): boolean {
        return canIUse('SystemCapability.Sensors.MiscDevice');
    }

    static grip(): boolean {
        return canIUse('SystemCapability.MultimodalAwareness.Motion');
    }

    static share(): boolean {
        return canIUse('SystemCapability.Collaboration.SystemShare');
    }
    // Dashboard.ets / AppDetailPage.ets titleBar style, with title, segment, menu and back action injected by the caller.
    // 全局详情的父容器已避让状态栏，默认 false；日程栈与根页扩展了顶部，须传 true。
    // 目的地不要再次扩展 TOP，否则标题与内容对状态栏高度的计算会错位。

    static titleBar(title: ResourceStr, enabled: boolean, level: number = 1, segment?: CustomBuilder, menus: HdsNavigationMenuItemOptions[] = [], avoidSafeArea: boolean = false, backAction?: () => void): HdsNavigationTitleBarOptions {
        menus.forEach((menu: HdsNavigationMenuItemOptions): void => {
            if (menu.content && !menu.content.componentId && typeof menu.content.label === 'string') {
                menu.content.componentId = 'detail-action-' + menu.content.label;
            }
        });
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
                    materialType: enabled ? HDS_MATERIAL_ADAPTIVE : HDS_MATERIAL_NONE,
                    materialLevel: level,
                } : undefined,
            },
            content: { title: { mainTitle: typeof title === 'string' ? displayName(title) : title, mainTitleSize: HDS_TITLE_SIZE_SMALL, mainTitleAccessibilityText: title }, stackBuilder: segment, menu: { value: menus, maxCount: 3 } },
        };
        if (backAction !== undefined && options.content !== undefined) {
            // 与 Dashboard AppDetailPage 一致：返回按钮走调用方动作，保证返回振动与栈操作不被 HDS 默认行为吞掉。
            options.content.backIcon = { action: backAction, componentId: 'title-back' };
        }
        return options;
    }

    static tabs(enabled: boolean, level: number = 1): HdsTabsFloatingStyle | undefined {
        if (!SUPPORTS_API_23) {
            return undefined;
        }
        return {
            barBottomMargin: Theme.mainTabsBottomMargin,
            lightColor: Theme.brand,
            gradientMask: { maskColor: Color.Transparent, maskHeight: 92 },
            systemMaterialEffect: {
                materialType: enabled ? HDS_MATERIAL_ADAPTIVE : HDS_MATERIAL_NONE,
                materialLevel: level,
            },
        };
    }
}
/** Resolve newer native methods only after checking the runtime, as in Dashboard. */

export class CompatibleTabsStyle implements AttributeModifier<HdsTabsAttribute> {
    private enabled: boolean;
    private level: number;
    private cacheCount: number;

    constructor(enabled: boolean, level: number, cacheCount: number = 0) {
        this.enabled = enabled;
        this.level = level;
        this.cacheCount = cacheCount;
    }

    applyNormalAttribute(instance: HdsTabsAttribute): void {
        if (!SUPPORTS_API_23) {
            return;
        }
        if (this.cacheCount > 0) {
            instance.cachedMaxCount(this.cacheCount, TabsCacheMode.CACHE_LATEST_SWITCHED);
        }
        const style = SystemCapability.tabs(this.enabled, this.level);
        if (style) {
            instance.blurStrategy(this.enabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE);
            instance.barFloatingStyle(style);
        }
    }
}
