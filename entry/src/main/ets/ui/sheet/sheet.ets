import { UIContext } from '@kit.ArkUI';
import { StaggerEntrance } from '../animation/motion';
import { Theme } from '../theme/Theme';
import { HapticService } from '../feedback/HapticService';
import { STORAGE_KEY_VIBRATION_LEVEL } from '../../config/constants';
interface SheetBackHandler {
    id: number;
    close: () => void | Promise<void>;
}
let nextSheetId: number = 0;
const sheetIds: WeakMap<StaggerEntrance, number> = new WeakMap<StaggerEntrance, number>();
const visibleSheets: SheetBackHandler[] = [];
let inlineOwner: string = '';
let inlineBack: (() => Promise<void>) | undefined = undefined;
let closing: boolean = false;
/** Embedded editors reuse their owner's native sheet instead of mounting a third one. */

export function registerInlineSheetBack(owner: string, back: () => Promise<void>): void {
    inlineOwner = owner;
    inlineBack = back;
}

export function releaseInlineSheetBack(owner: string): void {
    if (inlineOwner !== owner) {
        return;
    }
    inlineOwner = '';
    inlineBack = undefined;
}

export async function closeSheet(close: () => void | Promise<void>): Promise<void> {
    if (closing) {
        return;
    }
    closing = true;
    try {
        if (inlineBack) {
            await inlineBack();
        } else {
            await close();
        }
    } finally {
        closing = false;
    }
}

export function handleSheetBack(): boolean {
    if (inlineBack) { void closeSheet((): void => {}); return true; }
    const sheet = visibleSheets[visibleSheets.length - 1];
    if (!sheet) {
        return false;
    }
    void closeSheet(sheet.close);
    return true;
}

export async function dismissSheet(action: DismissSheetAction, allowed: () => Promise<boolean> = async () => true): Promise<void> {
    await closeSheet(async (): Promise<void> => {
        if (await allowed()) {
            action.dismiss();
        }
    });
}
/** One open/close lifecycle for buttons, native gestures and system back. */

export function appSheetOptions(onDisappear: () => void, entrance: StaggerEntrance, context: UIContext, height: SheetSize = SheetSize.LARGE, beforeClose: () => Promise<boolean> = async () => true, requestClose?: () => void): SheetOptions {
    let id = sheetIds.get(entrance);
    if (id === undefined) { id = ++nextSheetId; sheetIds.set(entrance, id); }
    const sheetId: number = id;
    return {
        height: height,
        dragBar: true,
        showClose: false,
        preferType: SheetType.BOTTOM,
        maskColor: Theme.scrim,
        blurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
        onWillAppear: (): void => {
            entrance.reset();
        },
        onAppear: (): void => {
            const existing = visibleSheets.findIndex((sheet: SheetBackHandler) => sheet.id === sheetId);
            if (existing >= 0) { visibleSheets.splice(existing, 1); }
            visibleSheets.push({ id: sheetId, close: async (): Promise<void> => {
                    if (await beforeClose()) {
                        (requestClose || onDisappear)();
                    }
                }
            });
            void HapticService.confirm((AppStorage.get<number>(STORAGE_KEY_VIBRATION_LEVEL) || 0) > 0);
            entrance.play(context, 3);
        },
        onWillDismiss: (action: DismissSheetAction): void => {
            void dismissSheet(action, beforeClose);
        },
        onWillDisappear: (): void => {
            entrance.finish(3);
        },
        onDisappear: (): void => {
            const index = visibleSheets.findIndex((sheet: SheetBackHandler) => sheet.id === sheetId);
            if (index >= 0) {
                visibleSheets.splice(index, 1);
            }
            entrance.reset();
            onDisappear();
            HapticService.back((AppStorage.get<number>(STORAGE_KEY_VIBRATION_LEVEL) || 0) > 0);
        },
    };
}
