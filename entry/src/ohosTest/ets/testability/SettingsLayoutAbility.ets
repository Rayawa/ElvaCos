import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

// Test-only UI host. Do not load EntryAbility or open the application's database.
export default class SettingsLayoutAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    this.context.getApplicationContext().setFontSizeScale(1);
    stage.loadContent('testability/pages/SettingsLayout');
  }
  onDestroy(): void { this.context.getApplicationContext().setFontSizeScale(1); }
}
