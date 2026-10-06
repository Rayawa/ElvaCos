import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppSettings } from '../model/Entities';
import { APPEARANCE_DARK, APPEARANCE_LIGHT } from '../common/Theme';
import { getAllSettings, getUsername, getStoredAccount, setAppearance, setHand, setVibrationLevel, setLightFieldLevel, setImmersiveMaterialLevel, setHoldCheckEnabled, setButtonPosition, setAppPreference, loadPersistedState } from '../common/storage';

// Dashboard's app_storage -> DiskStorage -> AppStorage is the only preference channel.
export class SettingsService {
  async load(context: common.UIAbilityContext): Promise<AppSettings> {
    await loadPersistedState(context);
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

  async save(context: common.UIAbilityContext, settings: AppSettings): Promise<void> {
    settings.effects = settings.materialLevel !== 2;
    settings.grip = settings.hand === 'auto';
    await setVibrationLevel(settings.haptic ? settings.hapticLevel : 0);
    await setLightFieldLevel(settings.lightFieldLevel);
    await setImmersiveMaterialLevel(settings.materialLevel);
    await setHand(settings.hand);
    await setButtonPosition(settings.hand === 'right');
    await setAppearance(settings.appearance);
    await setAppPreference('effects', settings.effects);
    this.applyAppearance(context, settings.appearance);
  }

  /**
   * 应用外观即深浅色模式：天蓝 → 浅色，雾蓝 → 深色，跟随系统 → 交给系统。
   * 颜色资源仍是 Dashboard 的同名资源，只由 ColorMode 决定走 base 还是 dark。
   */
  private applyAppearance(context: common.UIAbilityContext, appearance: string): void {
    const mode = appearance === APPEARANCE_LIGHT ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      : appearance === APPEARANCE_DARK ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    try {
      context.getApplicationContext().setColorMode(mode);
    } catch (error) {
      console.error('[ElvaCos][services/SettingsService][ERROR]', `设置应用外观失败: ${JSON.stringify(error)}`);
    }
  }
}
