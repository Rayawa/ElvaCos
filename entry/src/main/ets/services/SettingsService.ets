import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppSettings } from '../model/Entities';
import { APPEARANCE_DARK, APPEARANCE_LIGHT } from '../common/Theme';
import { getAllSettings, getUsername, getStoredAccount, setAppearance, setHand, setVibrationLevel, setLightFieldLevel, setImmersiveMaterialLevel, loadPersistedState } from '../common/storage';

// Dashboard's app_storage -> DiskStorage -> AppStorage is the only preference channel.
export class SettingsService {
  private appliedAppearance: string = '';
  async load(context: common.UIAbilityContext, hydrate: boolean = true): Promise<AppSettings> {
    // 仅启动时水合 AppStorage；保存后的刷新不能覆盖另一条滑块正在拖动的本地值。
    if (hydrate) { await loadPersistedState(context); }
    const persisted = await getAllSettings();
    const settings = new AppSettings();
    settings.username = await getUsername();
    settings.appearance = persisted.appearance;
    settings.hand = persisted.hand;
    settings.grip = persisted.hand === 'auto';
    settings.haptic = persisted.vibrationLevel !== 0;
    settings.hapticLevel = persisted.vibrationLevel === 2 ? 2 : 1;
    settings.lightFieldLevel = persisted.lightFieldLevel;
    settings.materialLevel = persisted.immersiveMaterialLevel;
    settings.effects = settings.materialLevel !== 2;
    AppStorage.setOrCreate('visualEffectsEnabled', settings.effects);
    const account = await getStoredAccount();
    AppStorage.setOrCreate('accountDisplayName', account.name);
    this.applyAppearance(context, settings.appearance);
    return settings;
  }

  async save(context: common.UIAbilityContext, settings: AppSettings, previous: AppSettings): Promise<void> {
    settings.effects = settings.materialLevel !== 2;
    settings.grip = settings.hand === 'auto';
    if (settings.haptic !== previous.haptic || settings.hapticLevel !== previous.hapticLevel) {
      await setVibrationLevel(settings.haptic ? settings.hapticLevel : 0);
    }
    if (settings.lightFieldLevel !== previous.lightFieldLevel) { await setLightFieldLevel(settings.lightFieldLevel); }
    if (settings.materialLevel !== previous.materialLevel) { await setImmersiveMaterialLevel(settings.materialLevel); }
    if (settings.hand !== previous.hand) { await setHand(settings.hand); }
    if (settings.appearance !== previous.appearance) { await setAppearance(settings.appearance); }
    this.applyAppearance(context, settings.appearance);
  }

  /**
   * 应用外观即深浅色模式：天蓝 → 浅色，雾蓝 → 深色，跟随系统 → 交给系统。
   * 颜色资源仍是 Dashboard 的同名资源，只由 ColorMode 决定走 base 还是 dark。
   */
  private applyAppearance(context: common.UIAbilityContext, appearance: string): void {
    if (appearance === this.appliedAppearance) { return; }
    const mode = appearance === APPEARANCE_LIGHT ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      : appearance === APPEARANCE_DARK ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    try {
      context.getApplicationContext().setColorMode(mode);
      this.appliedAppearance = appearance;
    } catch (error) {
      console.error('[ElvaCos][services/SettingsService][ERROR]', `设置应用外观失败: ${JSON.stringify(error)}`);
    }
  }
}
