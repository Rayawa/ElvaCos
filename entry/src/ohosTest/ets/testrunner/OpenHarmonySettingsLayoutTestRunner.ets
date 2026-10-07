import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';

export default class OpenHarmonySettingsLayoutTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      await delegator.startAbility({ bundleName: 'top.rayawa.elvacos', moduleName: 'entry', abilityName: 'SettingsLayoutAbility' });
      const suite = await import('../test/SettingsLayout.test');
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), suite.default);
    } catch (error) { delegator.finishTest('Use scripts/settings-layout-test.sh to install the isolated layout host', -1, () => {}); }
  }
}
