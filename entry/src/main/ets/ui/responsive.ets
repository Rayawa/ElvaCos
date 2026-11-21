// 与 dashboard 共用 600vp / 840vp 断点，依据窗口或实际内容宽度响应，不能按设备类型锁定布局。
export const RESPONSIVE_BREAKPOINT_MEDIUM: string = '600vp';
export const RESPONSIVE_BREAKPOINT_LARGE: string = '840vp';
export const RESPONSIVE_MEDIUM_WIDTH: number = 600;
export const RESPONSIVE_LARGE_WIDTH: number = 840;

export function photoColumnCount(width: number): number {
    return width >= RESPONSIVE_LARGE_WIDTH ? 4 : width >= RESPONSIVE_MEDIUM_WIDTH ? 3 : 2;
}

export function cardColumnCount(width: number): number {
    return width >= RESPONSIVE_MEDIUM_WIDTH ? 2 : 1;
}
