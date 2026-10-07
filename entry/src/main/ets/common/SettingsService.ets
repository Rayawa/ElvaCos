import { APPEARANCE_DARK, APPEARANCE_LIGHT } from './constants';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppSettings } from '../model/Entities';
import { Theme } from './Theme';
import { normalizeThemeColor } from './ThemePalettes';

import {
  getAllSettings,
  getUsername,
  setAppearance,
  setThemeColor,
  setHand,
  setVibrationLevel,
  setLightFieldLevel,
  setImmersiveMaterialLevel,
  loadPersistedState,
} from './storage';

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
    settings.themeColor = persisted.themeColor;
    settings.hand = persisted.hand;
    settings.grip = persisted.hand === 'auto';
    settings.haptic = persisted.vibrationLevel !== 0;
    settings.hapticLevel = persisted.vibrationLevel === 2 ? 2 : 1;
    settings.lightFieldLevel = persisted.lightFieldLevel;
    settings.materialLevel = persisted.immersiveMaterialLevel;
    settings.effects = settings.materialLevel !== 2;
    this.applyAppearance(context, settings.appearance);
    Theme.applyPalette(settings.themeColor);
    return settings;
  }

  async save(context: common.UIAbilityContext, settings: AppSettings, previous: AppSettings): Promise<void> {
    settings.effects = settings.materialLevel !== 2;
    settings.grip = settings.hand === 'auto';
    settings.themeColor = normalizeThemeColor(settings.themeColor);
    if (settings.haptic !== previous.haptic || settings.hapticLevel !== previous.hapticLevel) {
      await setVibrationLevel(settings.haptic ? settings.hapticLevel : 0);
    }
    if (settings.lightFieldLevel !== previous.lightFieldLevel) { await setLightFieldLevel(settings.lightFieldLevel); }
    if (settings.materialLevel !== previous.materialLevel) { await setImmersiveMaterialLevel(settings.materialLevel); }
    if (settings.hand !== previous.hand) { await setHand(settings.hand); }
    if (settings.appearance !== previous.appearance) { await setAppearance(settings.appearance); }
    if (settings.themeColor !== previous.themeColor) { await setThemeColor(settings.themeColor); }
    this.applyAppearance(context, settings.appearance);
    if (settings.themeColor !== Theme.paletteId) { Theme.applyPalette(settings.themeColor); }
  }

  /**
   * 应用外观只控制深浅色模式；各组配色均由 ColorMode 决定走 base 还是 dark。
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
      console.error('[ElvaCos][common/SettingsService][ERROR]', `设置应用外观失败: ${JSON.stringify(error)}`);
    }
  }
}
