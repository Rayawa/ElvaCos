#!/usr/bin/env python3
"""Reuse the isolated UI host; load only unique test Preferences, never personal.db."""
from pathlib import Path
import subprocess
import uuid

source = Path(__file__).resolve().parent.parent
clone = Path(subprocess.check_output(['python3', str(source / 'scripts/prepare_settings_layout.py')], text=True).strip())
main = clone / 'entry/src/main/ets'
name = 'theme_validation_' + uuid.uuid4().hex
constants = main / 'common/constants.ets'
text = constants.read_text()
for old in ['app_storage', 'profile', 'settings', 'myAppSettings']:
    text = text.replace("= '" + old + "';", "= '" + name + '_' + old + "';")
constants.write_text(text)
# storage has one legacy Elva Preferences lookup in addition to its named constants.
storage = main / 'common/storage.ets'
storage.write_text(storage.read_text().replace("getDiskStorageInstance('settings', ctx)", "getDiskStorageInstance('" + name + "_settings', ctx)"))
ability = main / 'testability/SettingsLayoutAbility.ets'
ability.write_text("""import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { getApplicationState } from '../common/appState';
import { STORAGE_FILE_NAME } from '../common/constants';
export default class SettingsLayoutAbility extends UIAbility {
  async onWindowStageCreate(stage: window.WindowStage): Promise<void> {
    this.context.getApplicationContext().setFontSizeScale(1);
    // Simulate an existing user with a saved light appearance and no themeColor key.
    const prefs = await preferences.getPreferences(this.context, STORAGE_FILE_NAME);
    if (!(await prefs.has('theme_validation_seeded'))) {
      await prefs.put('appearance', 'sky');
      await prefs.put('ux_preferences_v2', true);
      await prefs.put('theme_validation_seeded', true);
      await prefs.flush();
    }
    await getApplicationState().loadPreferences(this.context);
    stage.loadContent('testability/pages/SettingsLayout');
  }
  onDestroy(): void { this.context.getApplicationContext().setFontSizeScale(1); }
}
""")
page = main / 'testability/pages/SettingsLayout.ets'
page.write_text("""import { getApplicationState } from '../../common/appState';
import { AppState } from '../../model/ApplicationState';
import { PreferenceSettings } from '../../component/PreferenceSettings';
import { Theme } from '../../common/Theme';
import { common } from '@kit.AbilityKit';
@Entry
@ComponentV2
struct SettingsLayout {
  @Local state: AppState = getApplicationState();
  @Local narrow: boolean = false;
  private setFontScale(scale: number): void {
    (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext().setFontSizeScale(scale);
  }
  build() {
    WithTheme({ theme: Theme.nativeTheme }) {
      Column({ space: 12 }) {
        Text('主题验证').fontSize(24).fontColor(Theme.ink)
        Text(this.state.settings.themeColor + ':' + this.state.settings.appearance).id('theme-selection').fontSize(12).maxFontScale(1).fontColor(Theme.muted)
        Row({ space: 8 }) {
          Button('窄屏').id('layout-width-narrow').fontSize(12).maxFontScale(1).onClick((): void => { this.narrow = true; })
          Button('大字体').id('layout-font-large').fontSize(12).maxFontScale(1).onClick((): void => this.setFontScale(2))
          Button('默认字').id('layout-font-default').fontSize(12).maxFontScale(1).onClick((): void => this.setFontScale(1))
        }
        Scroll() {
          Column({ space: 16 }) {
            PreferenceSettings({ isEnabled: !this.state.settingsBusy, save: (changes) => this.state.updateSettings(changes) })
            Column({ space: 12 }) {
              Text('热爱的轨迹').fontSize(18).fontColor(Theme.ink)
              Text('正文、次级文字和卡片层次').fontSize(14).fontColor(Theme.muted)
              Text('准备中').fontSize(14).fontColor(Theme.accent).padding(8).backgroundColor(Theme.tint).borderRadius(8)
              Button('继续准备').fontColor(Theme.onAccent).backgroundColor(Theme.brand)
              Text('原生控件').fontSize(12).fontColor(Theme.muted)
              Slider({ value: 50, min: 0, max: 100 })
            }.padding(16).width('100%').backgroundColor(Theme.surface).border({ width: 1, color: Theme.line }).borderRadius(16)
          }.id('settings-layout-canvas').width(this.narrow ? 320 : '100%')
        }.id('settings-scroll').layoutWeight(1).width('100%')
      }.width('100%').height('100%').padding(16).backgroundColor(Theme.bg)
    }
  }
}
""")
print(clone)
