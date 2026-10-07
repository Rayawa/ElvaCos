import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';

export default class OpenHarmonyThemeRestoreTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      await delegator.startAbility({ bundleName: 'top.rayawa.elvacos', moduleName: 'entry', abilityName: 'SettingsLayoutAbility' });
      const suite = await import('../test/ThemeSwitch.test');
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), (): void => suite.default(true));
    } catch (error) { delegator.finishTest('Use scripts/theme-test.sh to install the isolated theme host', -1, () => {}); }
  }
}
