import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppSettings } from '../model/Entities';
import { getAllSettings, getUsername, getAppPreference, setAppPreference, setVibrationLevel, setLightFieldLevel, setImmersiveMaterialLevel, setHoldCheckEnabled, setButtonPosition, loadPersistedState } from '../common/storage';

// Dashboard's app_storage -> DiskStorage -> AppStorage is the only preference channel.
export class SettingsService {
  async load(context: common.UIAbilityContext): Promise<AppSettings> {
    await loadPersistedState(context);
    const persisted = await getAllSettings();
    const settings = new AppSettings();
    settings.username = await getUsername();
    settings.theme = 'system';
    settings.hand = await getAppPreference('hand', 'left') as string;
    settings.grip = settings.hand === 'auto' && persisted.holdCheckON;
    settings.haptic = persisted.vibrationLevel !== 0;
    settings.hapticLevel = persisted.vibrationLevel === 2 ? 2 : 1;
    settings.lightFieldLevel = persisted.lightFieldLevel;
    settings.materialLevel = persisted.immersiveMaterialLevel;
    settings.effects = settings.materialLevel !== 2;
    AppStorage.setOrCreate('visualEffectsEnabled', settings.effects);
    this.applyTheme(context, settings.theme);
    return settings;
  }
  async save(context: common.UIAbilityContext, settings: AppSettings): Promise<void> {
    settings.theme = 'system';
    settings.effects = settings.materialLevel !== 2;
    settings.grip = settings.hand === 'auto';
    await setVibrationLevel(settings.haptic ? settings.hapticLevel : 0);
    await setLightFieldLevel(settings.lightFieldLevel);
    await setImmersiveMaterialLevel(settings.materialLevel);
    await setHoldCheckEnabled(settings.grip);
    await setButtonPosition(settings.hand === 'right');
    await setAppPreference('theme', settings.theme);
    await setAppPreference('effects', settings.effects);
    await setAppPreference('hand', settings.hand);
    this.applyTheme(context, settings.theme);
  }
  private applyTheme(context: common.UIAbilityContext, theme: string): void {
    context.getApplicationContext().setColorMode(theme === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : theme === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }
}
