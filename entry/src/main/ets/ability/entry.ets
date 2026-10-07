import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { getApplicationState, setReminderTarget } from '../common/appState';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.openReminder(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private openReminder(want: Want): void {
    const id = want.parameters?.eventId;
    if (typeof id === 'string') { setReminderTarget(id); }
  }
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void { this.openReminder(want); }
  onDestroy(): void {
    getApplicationState().dispose();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  private mainWindow: window.Window | undefined;

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    try {
      this.mainWindow = windowStage.getMainWindowSync();
      await this.mainWindow.setWindowLayoutFullScreen(false);

    } catch (error) { hilog.warn(DOMAIN, 'WindowInsets', 'Window setup failed: %{public}s', String(error)); }

    try { await getApplicationState().loadPreferences(this.context); }
    catch (error) { getApplicationState().reportError('设置加载失败，请重试加载本地数据'); }

    windowStage.loadContent('pages/Dashboard', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    // 深浅色由「应用外观」决定：SettingsService 会在加载偏好后设置 ColorMode，
    // 这里不再强制 NOT_SET，避免把用户选择的浅色/深色覆盖回跟随系统。
  }

  onWindowStageDestroy(): void {

    this.mainWindow = undefined;
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    getApplicationState().suspend();
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
