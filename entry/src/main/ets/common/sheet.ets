import { Theme } from './Theme';

/**
 * 全应用弹出层统一约定：
 * - 一律使用 bindSheet 底部弹出；
 * - 内容自己提供右上角关闭按钮，因此关闭系统自带的关闭按钮；
 * - 返回键/侧滑关闭时同样走 onDisappear，保证调用方状态复位。
 */
export function appSheetOptions(onDisappear: () => void, height: SheetSize = SheetSize.LARGE): SheetOptions {
  return {
    height: height,
    dragBar: true,
    showClose: false,
    preferType: SheetType.BOTTOM,
    maskColor: Theme.scrim,
    blurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
    onDisappear: onDisappear,
  };
}
