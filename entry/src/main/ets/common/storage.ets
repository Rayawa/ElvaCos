// 统一存储入口：全 app 唯一的偏好数据通道
// - 磁盘：单一 preferences 文件 app_storage（引擎仍是 DiskStorage）
// - 兼容：首次访问时一次性迁移旧文件（profile / settings / myAppSettings），用户名等旧数据全部保留
// - 内存：持久化 key 的 setter 同步写入 AppStorage，@StorageLink 消费方无需再手动双写
// - 瞬态 key（winWidth、pageUrl、nativeRefreshTick 等）不属于本模块，只活在 AppStorage 里
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { migrateElvaPreferences, migrateUxPreferences } from './SettingsMigration';
import getDiskStorageInstance, { DiskStorageInstance } from './DiskStorage';
import {
    APP_VERSION,
    DEFAULT_APPEARANCE,
    DEFAULT_BUTTON_RIGHT,
    DEFAULT_HAND,
    DEFAULT_HOLD_CHECK_ENABLED,
    DEFAULT_IMMERSIVE_MATERIAL_LEVEL,
    DEFAULT_LIGHT_FIELD_LEVEL,
    DEFAULT_VIBRATION_LEVEL,
    LEGACY_APP_SETTINGS_FILE_NAME,
    LEGACY_PROFILE_FILE_NAME,
    LEGACY_SETTINGS_FILE_NAME,
    STORAGE_FILE_NAME,
    STORAGE_KEY_ACCOUNT_NAME,
    STORAGE_KEY_ACCOUNT_OPEN_ID,
    STORAGE_KEY_ACCOUNT_SIGNED_AT,
    STORAGE_KEY_ACCOUNT_UNION_ID,
    STORAGE_KEY_APPEARANCE,
    STORAGE_KEY_BUTTON_RIGHT,
    STORAGE_KEY_FIRST_LAUNCH,
    STORAGE_KEY_HAND,
    STORAGE_KEY_HOLD_CHECK,
    STORAGE_KEY_IMMERSIVE_MATERIAL_LEVEL,
    STORAGE_KEY_LIGHT_FIELD_LEVEL,
    STORAGE_KEY_LEGACY_MIGRATED,
    STORAGE_KEY_NOTICE_VERSION,
    STORAGE_KEY_SEARCH_HISTORY,
    STORAGE_KEY_USERNAME,
    STORAGE_KEY_VIBRATION_LEVEL,
} from './constants';

// ===== 偏好 key（唯一事实来源，同时是对应的 AppStorage key 名）=====
const STORE_NAME = STORAGE_FILE_NAME;
const KEY_MIGRATED = STORAGE_KEY_LEGACY_MIGRATED;
const KEY_USERNAME = STORAGE_KEY_USERNAME;
const KEY_FIRST_LAUNCH = STORAGE_KEY_FIRST_LAUNCH;
const KEY_NOTICE_VERSION = STORAGE_KEY_NOTICE_VERSION;
const KEY_VIBRATION_LEVEL = STORAGE_KEY_VIBRATION_LEVEL;
const KEY_LIGHT_FIELD_LEVEL = STORAGE_KEY_LIGHT_FIELD_LEVEL;
const LEGACY_KEY_VIBRATION_ENABLED = 'vibrationON';
const KEY_HOLD_CHECK = STORAGE_KEY_HOLD_CHECK;
const KEY_BUTTON_RIGHT = STORAGE_KEY_BUTTON_RIGHT;
const KEY_IMMERSIVE_MATERIAL_LEVEL = STORAGE_KEY_IMMERSIVE_MATERIAL_LEVEL;
const KEY_SEARCH_HISTORY = STORAGE_KEY_SEARCH_HISTORY;
const KEY_APPEARANCE = STORAGE_KEY_APPEARANCE;
const KEY_HAND = STORAGE_KEY_HAND;
const KEY_ACCOUNT_OPEN_ID = STORAGE_KEY_ACCOUNT_OPEN_ID;
const KEY_ACCOUNT_UNION_ID = STORAGE_KEY_ACCOUNT_UNION_ID;
const KEY_ACCOUNT_NAME = STORAGE_KEY_ACCOUNT_NAME;
const KEY_ACCOUNT_SIGNED_AT = STORAGE_KEY_ACCOUNT_SIGNED_AT;

export interface AppSettings {
    vibrationLevel: number;
    lightFieldLevel: number;
    holdCheckON: boolean;
    buttonPositionRIGHT: boolean;
    immersiveMaterialLevel: number;
    appearance: string;
    hand: string;
}

/** 华为账号登录态：只保存本机可离线使用的最小信息，不保存任何令牌。 */
export interface StoredAccount {
    openId: string;
    unionId: string;
    name: string;
    signedAt: number;
}

// 所有持久化 key 的默认值；@StorageLink 装饰器的初始值必须与此保持一致
const DEFAULT_SETTINGS: AppSettings = {
    vibrationLevel: DEFAULT_VIBRATION_LEVEL,
    lightFieldLevel: DEFAULT_LIGHT_FIELD_LEVEL,
    holdCheckON: DEFAULT_HOLD_CHECK_ENABLED,
    buttonPositionRIGHT: DEFAULT_BUTTON_RIGHT,
    immersiveMaterialLevel: DEFAULT_IMMERSIVE_MATERIAL_LEVEL,
    appearance: DEFAULT_APPEARANCE,
    hand: DEFAULT_HAND
};

// ===== 单例与一次性迁移 =====
let store: DiskStorageInstance | undefined = undefined;
let readyPromise: Promise<void> | undefined = undefined;

function getStore(ctx?: common.Context): DiskStorageInstance {
    if (!store) {
        const instance = getDiskStorageInstance(STORE_NAME, ctx);
        if (!instance) {
            throw new Error('storage: create app_storage instance failed');
        }
        store = instance;
    }
    return store;
}

// 所有公开读写都经过这里：旧数据迁移必然先于首次访问完成
async function ensureReady(ctx?: common.Context): Promise<DiskStorageInstance> {
    if (readyPromise) {
        await readyPromise;
        return getStore(ctx);
    }
    try {
        const migrate = preparePreferences(ctx);
        readyPromise = migrate;
        await migrate;
    } catch (error) {
        // 初始化/迁移失败不缓存 readyPromise：后续携带 context 的调用仍可重试
        readyPromise = undefined;
        throw error as Error;
    }
    return getStore(ctx);
}

async function preparePreferences(ctx?: common.Context): Promise<void> {
    await migrateLegacyData(ctx);
    await migrateUxPreferences(getStore(ctx));
}

async function migrateLegacyData(ctx?: common.Context): Promise<void> {
    // 无 context 且实例尚未创建时，DiskStorage 构造在此抛出明确错误（由 ensureReady 处理）
    const target = getStore(ctx);
    if (await target.has(KEY_MIGRATED)) {
        return;
    }
    const copied: string[] = [];
    // 旧 profile 文件：用户名（唯一必须保住的旧数据）
    if (await copyLegacyKey(target, LEGACY_PROFILE_FILE_NAME, KEY_USERNAME, ctx) ||
        await copyLegacyKey(target, LEGACY_PROFILE_FILE_NAME, 'userName', ctx, KEY_USERNAME)) {
        copied.push(KEY_USERNAME);
    }
    // 旧 settings 文件：设置开关（新旧 key 同名）
    const settingKeys: string[] = [LEGACY_KEY_VIBRATION_ENABLED, KEY_HOLD_CHECK, KEY_BUTTON_RIGHT];
    for (const key of settingKeys) {
        if (await copyLegacyKey(target, LEGACY_SETTINGS_FILE_NAME, key, ctx)) {
            copied.push(key);
        }
    }
    // 旧 myAppSettings 文件：首启标志
    if (await copyLegacyKey(target, LEGACY_APP_SETTINGS_FILE_NAME, KEY_FIRST_LAUNCH, ctx)) {
        copied.push(KEY_FIRST_LAUNCH);
    }
    const legacy = getDiskStorageInstance('settings', ctx);
    if (legacy) { await migrateElvaPreferences(target, legacy); }
    await target.set(KEY_MIGRATED, true);
    console.info('[Dashboard][common/storage][INFO]', `[storage] 旧数据迁移完成: ${copied.length > 0 ? copied.join(', ') : '全新安装，无需迁移'}`);
}

async function copyLegacyKey(target: DiskStorageInstance, legacyFile: string, key: string, ctx?: common.Context, targetKey: string = key): Promise<boolean> {
    try {
        const legacy = getDiskStorageInstance(legacyFile, ctx);
        if (legacy && await legacy.has(key)) {
            const value = await legacy.get(key, '');
            await target.set(targetKey, value);
            return true;
        }
    } catch (error) {
        console.warn('[Dashboard][common/storage][WARN]', `[storage] 跳过旧文件 ${legacyFile} 的 ${key}: ${JSON.stringify(error)}`);
    }
    return false;
}

// ===== 初始化（幂等；也可以完全不调用，首次读写会自动初始化并迁移）=====
export function initializeSettings(ctx?: common.Context): void {
    ensureReady(ctx).catch(() => {
    });
}

// 兼容旧 profile.ets 的初始化入口
export function initialize(ctx?: common.Context): void {
    ensureReady(ctx).catch(() => {
    });
}

// ===== 首启标志（原 myAppSettings 文件 / isFirstLaunch）=====
export async function getFirstLaunch(): Promise<boolean> {
    const s = await ensureReady();
    const firstLaunch = (await s.get(KEY_FIRST_LAUNCH, true)) as boolean;
    const acceptedVersion = (await s.get(KEY_NOTICE_VERSION, '')) as string;
    return firstLaunch || acceptedVersion !== APP_VERSION;
}

export async function setFirstLaunch(first: boolean): Promise<void> {
    const s = await ensureReady();
    await s.set(KEY_FIRST_LAUNCH, first);
    await s.set(KEY_NOTICE_VERSION, first ? '' : APP_VERSION);
}

// ===== 用户名（原 profile 文件 / username）=====
export function getDeviceName(): string {
    try {
        const productModel = deviceInfo.productModel?.trim() ?? '';
        if (productModel.length > 0 && productModel !== '?' && productModel.toLowerCase() !== 'unknown') {
            return productModel;
        }
        const productModelAlias = deviceInfo.productModelAlias?.trim() ?? '';
        if (productModelAlias.length > 0 && productModelAlias !== '?' &&
            productModelAlias.toLowerCase() !== 'unknown') {
            return productModelAlias;
        }
        return "我的设备";
    } catch (error) {
        console.error('[Dashboard][common/storage][ERROR]', "Failed to get device name:", error);
        return "我的设备";
    }
}

export async function getUsername(): Promise<string> {
    const s = await ensureReady();
    const username = ((await s.get(KEY_USERNAME, getDeviceName())) as string)?.trim() ?? '';
    if (username.length > 0 && username !== '?' && username.toLowerCase() !== 'unknown') {
        return username;
    }
    const deviceName = getDeviceName();
    await s.set(KEY_USERNAME, deviceName);
    return deviceName;
}

export async function setUsername(username?: string): Promise<void> {
    const s = await ensureReady();
    if (username === undefined) {
        await s.remove(KEY_USERNAME);
        AppStorage.setOrCreate(KEY_USERNAME, getDeviceName());
        return;
    }
    await s.set(KEY_USERNAME, username);
    AppStorage.setOrCreate(KEY_USERNAME, username);
}

export async function clearUsername(): Promise<void> {
    await setUsername(undefined);
}

export async function hasUsername(): Promise<boolean> {
    const username = await getUsername();
    return username !== getDeviceName() && username.trim().length > 0;
}

// ===== 设置项（原 settings 文件）=====
export async function getVibrationLevel(): Promise<number> {
    const s = await ensureReady();
    if (await s.has(KEY_VIBRATION_LEVEL)) {
        const level = (await s.get(KEY_VIBRATION_LEVEL, DEFAULT_SETTINGS.vibrationLevel)) as number;
        return level === 0 || level === 1 || level === 2 ? level : DEFAULT_SETTINGS.vibrationLevel;
    }
    // 兼容旧版布尔开关：已有用户沿用旧选择；全新安装没有旧值时使用新的默认值（灵动）。
    const hasLegacySwitch = await s.has(LEGACY_KEY_VIBRATION_ENABLED);
    const legacyEnabled = (await s.get(LEGACY_KEY_VIBRATION_ENABLED, false)) as boolean;
    const migratedLevel = hasLegacySwitch ? (legacyEnabled ? 2 : 0) : DEFAULT_SETTINGS.vibrationLevel;
    await s.set(KEY_VIBRATION_LEVEL, migratedLevel);
    return migratedLevel;
}

export async function setVibrationLevel(level: number): Promise<void> {
    const normalized = level === 0 || level === 1 || level === 2 ?
        level : DEFAULT_SETTINGS.vibrationLevel;
    const s = await ensureReady();
    await s.set(KEY_VIBRATION_LEVEL, normalized);
    AppStorage.setOrCreate(KEY_VIBRATION_LEVEL, normalized);
}

function normalizeLightFieldLevel(level: number): number {
    const normalized = level === 0 || level === 1 || level === 2 ?
        level : DEFAULT_SETTINGS.lightFieldLevel;
    // 高亮档依赖 API 24 的 HDR 合成滤镜；低版本即使读到旧数据也安全回落到明亮。
    return normalized === 2 && deviceInfo.sdkApiVersion < 24 ? DEFAULT_SETTINGS.lightFieldLevel : normalized;
}

export async function getLightFieldLevel(): Promise<number> {
    const s = await ensureReady();
    const stored = (await s.get(KEY_LIGHT_FIELD_LEVEL, DEFAULT_SETTINGS.lightFieldLevel)) as number;
    const normalized = normalizeLightFieldLevel(stored);
    if (normalized !== stored) {
        await s.set(KEY_LIGHT_FIELD_LEVEL, normalized);
    }
    return normalized;
}

export async function setLightFieldLevel(level: number): Promise<void> {
    const normalized = normalizeLightFieldLevel(level);
    const s = await ensureReady();
    await s.set(KEY_LIGHT_FIELD_LEVEL, normalized);
    AppStorage.setOrCreate(KEY_LIGHT_FIELD_LEVEL, normalized);
}

export async function getHoldCheckEnabled(): Promise<boolean> {
    const s = await ensureReady();
    return (await s.get(KEY_HOLD_CHECK, DEFAULT_SETTINGS.holdCheckON)) as boolean;
}

export async function setHoldCheckEnabled(enabled: boolean): Promise<void> {
    const s = await ensureReady();
    await s.set(KEY_HOLD_CHECK, enabled);
    AppStorage.setOrCreate(KEY_HOLD_CHECK, enabled);
}

// false = 左, true = 右
export async function getButtonPosition(): Promise<boolean> {
    const s = await ensureReady();
    return (await s.get(KEY_BUTTON_RIGHT, DEFAULT_SETTINGS.buttonPositionRIGHT)) as boolean;
}

export async function setButtonPosition(isRight: boolean): Promise<void> {
    const s = await ensureReady();
    await s.set(KEY_BUTTON_RIGHT, isRight);
    AppStorage.setOrCreate(KEY_BUTTON_RIGHT, isRight);
}

export async function getImmersiveMaterialLevel(): Promise<number> {
    const s = await ensureReady();
    const level = (await s.get(KEY_IMMERSIVE_MATERIAL_LEVEL,
        DEFAULT_SETTINGS.immersiveMaterialLevel)) as number;
    return level === 0 || level === 1 || level === 2 ? level : DEFAULT_SETTINGS.immersiveMaterialLevel;
}

export async function setImmersiveMaterialLevel(level: number): Promise<void> {
    const normalized = level === 0 || level === 1 || level === 2 ?
        level : DEFAULT_SETTINGS.immersiveMaterialLevel;
    const s = await ensureReady();
    await s.set(KEY_IMMERSIVE_MATERIAL_LEVEL, normalized);
    await s.set('effects', normalized !== 2);
    AppStorage.setOrCreate(KEY_IMMERSIVE_MATERIAL_LEVEL, normalized);
    AppStorage.setOrCreate('visualEffectsEnabled', normalized !== 2);
}

// ===== 应用外观（天蓝 / 雾蓝 / 跟随系统）=====
export async function getAppearance(): Promise<string> {
    const s = await ensureReady();
    const stored = (await s.get(KEY_APPEARANCE, DEFAULT_APPEARANCE)) as string;
    return stored === 'sky' || stored === 'mist' ? stored : DEFAULT_APPEARANCE;
}

export async function setAppearance(mode: string): Promise<void> {
    const normalized = mode === 'sky' || mode === 'mist' ? mode : DEFAULT_APPEARANCE;
    const s = await ensureReady();
    await s.set(KEY_APPEARANCE, normalized);
    AppStorage.setOrCreate(KEY_APPEARANCE, normalized);
}

// ===== 单手操作（left / auto / right）=====
export async function getHand(): Promise<string> {
    const s = await ensureReady();
    const stored = (await s.get(KEY_HAND, DEFAULT_HAND)) as string;
    return stored === 'left' || stored === 'auto' || stored === 'right' ? stored : DEFAULT_HAND;
}

export async function setHand(hand: string): Promise<void> {
    const normalized = hand === 'auto' || hand === 'right' ? hand : DEFAULT_HAND;
    const s = await ensureReady();
    await s.set(KEY_HAND, normalized);
    AppStorage.setOrCreate(KEY_HAND, normalized);
    await s.set(KEY_HOLD_CHECK, normalized === 'auto');
    AppStorage.setOrCreate(KEY_HOLD_CHECK, normalized === 'auto');
    await s.set(KEY_BUTTON_RIGHT, normalized === 'right');
    AppStorage.setOrCreate(KEY_BUTTON_RIGHT, normalized === 'right');
}

// ===== 华为账号登录态 =====
export async function getStoredAccount(): Promise<StoredAccount> {
    const s = await ensureReady();
    return {
        openId: (await s.get(KEY_ACCOUNT_OPEN_ID, '')) as string,
        unionId: (await s.get(KEY_ACCOUNT_UNION_ID, '')) as string,
        name: (await s.get(KEY_ACCOUNT_NAME, '')) as string,
        signedAt: (await s.get(KEY_ACCOUNT_SIGNED_AT, 0)) as number
    };
}

export async function setStoredAccount(account: StoredAccount): Promise<void> {
    const s = await ensureReady();
    await s.set(KEY_ACCOUNT_OPEN_ID, account.openId);
    await s.set(KEY_ACCOUNT_UNION_ID, account.unionId);
    await s.set(KEY_ACCOUNT_NAME, account.name);
    await s.set(KEY_ACCOUNT_SIGNED_AT, account.signedAt);
    AppStorage.setOrCreate(KEY_ACCOUNT_OPEN_ID, account.openId);
    AppStorage.setOrCreate(KEY_ACCOUNT_NAME, account.name);
}

export async function clearStoredAccount(): Promise<void> {
    const s = await ensureReady();
    await s.remove(KEY_ACCOUNT_OPEN_ID);
    await s.remove(KEY_ACCOUNT_UNION_ID);
    await s.remove(KEY_ACCOUNT_NAME);
    await s.remove(KEY_ACCOUNT_SIGNED_AT);
    AppStorage.setOrCreate(KEY_ACCOUNT_OPEN_ID, '');
    AppStorage.setOrCreate(KEY_ACCOUNT_NAME, '');
}

export async function getAllSettings(): Promise<AppSettings> {
    // 首次读取可能落到 Preferences；各 key 相互独立，可并行等待以缩短启动水合时间。
    const vibrationLevelPromise = getVibrationLevel();
    const lightFieldLevelPromise = getLightFieldLevel();
    const holdCheckPromise = getHoldCheckEnabled();
    const buttonPositionPromise = getButtonPosition();
    const immersiveMaterialPromise = getImmersiveMaterialLevel();
    const appearancePromise = getAppearance();
    const handPromise = getHand();
    return {
        vibrationLevel: await vibrationLevelPromise,
        lightFieldLevel: await lightFieldLevelPromise,
        holdCheckON: await holdCheckPromise,
        buttonPositionRIGHT: await buttonPositionPromise,
        immersiveMaterialLevel: await immersiveMaterialPromise,
        appearance: await appearancePromise,
        hand: await handPromise,
    };
}

export async function updateSettings(settings: Partial<AppSettings>): Promise<void> {
    if (settings.vibrationLevel !== undefined) {
        await setVibrationLevel(settings.vibrationLevel);
    }
    if (settings.lightFieldLevel !== undefined) {
        await setLightFieldLevel(settings.lightFieldLevel);
    }
    if (settings.holdCheckON !== undefined) {
        await setHoldCheckEnabled(settings.holdCheckON);
    }
    if (settings.buttonPositionRIGHT !== undefined) {
        await setButtonPosition(settings.buttonPositionRIGHT);
    }
    if (settings.immersiveMaterialLevel !== undefined) {
        await setImmersiveMaterialLevel(settings.immersiveMaterialLevel);
    }
    if (settings.appearance !== undefined) {
        await setAppearance(settings.appearance);
    }
    if (settings.hand !== undefined) {
        await setHand(settings.hand);
    }
}

// ===== 搜索历史 =====
// Preferences 只接受基础值类型，因此以 JSON 字符串保存；读取时同时做结构和数量约束。
export async function getSearchHistory(): Promise<string[]> {
    const s = await ensureReady();
    const raw = (await s.get(KEY_SEARCH_HISTORY, '[]')) as string;
    try {
        const parsed = JSON.parse(raw) as string[];
        return parsed.filter((item: string) => typeof item === 'string' && item.trim().length > 0).slice(0, 10);
    } catch (error) {
        console.warn('[Dashboard][common/storage][WARN]', `搜索历史损坏，已忽略: ${JSON.stringify(error)}`);
        return [];
    }
}

export async function setSearchHistory(history: string[]): Promise<void> {
    const normalized: string[] = [];
    for (const item of history) {
        const value = item.trim();
        if (value.length > 0 && normalized.indexOf(value) < 0) {
            normalized.push(value);
        }
    }
    const s = await ensureReady();
    await s.set(KEY_SEARCH_HISTORY, JSON.stringify(normalized.slice(0, 10)));
}

export async function clearSearchHistory(): Promise<void> {
    const s = await ensureReady();
    await s.remove(KEY_SEARCH_HISTORY);
}

// 恢复出厂设置（只重置设置项，不动用户名和首启标志）
export async function resetAllSettings(): Promise<void> {
    await updateSettings(DEFAULT_SETTINGS);
}

// ===== AppStorage 水合（EntryAbility 启动时调用一次，UI 绑定前填入磁盘真值）=====
export async function loadPersistedState(ctx?: common.Context): Promise<void> {
    try {
        await ensureReady(ctx);
        const settingsPromise = getAllSettings();
        const usernamePromise = getUsername();
        const settings = await settingsPromise;
        const username = await usernamePromise;
        AppStorage.setOrCreate(KEY_VIBRATION_LEVEL, settings.vibrationLevel);
        AppStorage.setOrCreate(KEY_LIGHT_FIELD_LEVEL, settings.lightFieldLevel);
        AppStorage.setOrCreate(KEY_HOLD_CHECK, settings.holdCheckON);
        AppStorage.setOrCreate(KEY_BUTTON_RIGHT, settings.buttonPositionRIGHT);
        AppStorage.setOrCreate(KEY_IMMERSIVE_MATERIAL_LEVEL, settings.immersiveMaterialLevel);
        AppStorage.setOrCreate('visualEffectsEnabled', settings.immersiveMaterialLevel !== 2);
        AppStorage.setOrCreate(KEY_USERNAME, username);
        AppStorage.setOrCreate(KEY_APPEARANCE, settings.appearance);
        AppStorage.setOrCreate(KEY_HAND, settings.hand);
    } catch (error) {
        console.error('[Dashboard][common/storage][ERROR]', `[storage] AppStorage 水合失败: ${JSON.stringify(error)}`);
    }
}

// Business-specific preferences use the same disk/cache/runtime channel.
export async function getAppPreference(key: string, fallback: string | boolean): Promise<string | boolean> {
    const s = await ensureReady();
    return await s.get(key, fallback) as string | boolean;
}
export async function setAppPreference(key: string, value: string | boolean): Promise<void> {
    const s = await ensureReady();
    await s.set(key, value);
    AppStorage.setOrCreate(key === 'effects' ? 'visualEffectsEnabled' : key, value);
}
