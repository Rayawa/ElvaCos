import { KeyCode } from '@kit.InputKit';

export enum AppShortcut {
    NONE = -1,
    HOME = 0,
    PLANS = 1,
    SCHEDULE = 2,
    WARDROBE = 3,
    ALBUM = 4,
    BACK = 5,
    SEARCH = 6,
    SETTINGS = 7,
    CREATE = 8,
}

// 只处理明确的组合键；普通输入、Tab、Enter、空格及系统组合键交还原生组件。
export function resolveAppShortcut(code: number, ctrl: boolean, alt: boolean, shift: boolean, meta: boolean): AppShortcut {
    if (alt || shift || meta) {
        return AppShortcut.NONE;
    }
    if (!ctrl) {
        return code === KeyCode.KEYCODE_ESCAPE ? AppShortcut.BACK : AppShortcut.NONE;
    }
    if (code >= KeyCode.KEYCODE_1 && code <= KeyCode.KEYCODE_5) {
        return code - KeyCode.KEYCODE_1;
    }
    switch (code) {
        case KeyCode.KEYCODE_F:
            return AppShortcut.SEARCH;
        case KeyCode.KEYCODE_COMMA:
            return AppShortcut.SETTINGS;
        case KeyCode.KEYCODE_N:
            return AppShortcut.CREATE;
        default:
            return AppShortcut.NONE;
    }
}
