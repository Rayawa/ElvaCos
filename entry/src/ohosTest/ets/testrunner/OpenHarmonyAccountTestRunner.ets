import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';

export default class OpenHarmonyAccountTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      await delegator.startAbility({ bundleName: 'top.rayawa.elvacos', abilityName: 'EntryAbility' });
      const suite = await import('../test/AccountIntegration.test');
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), suite.default);
    } catch (error) {
      delegator.finishTest('Account integration requires an unlocked application window', -1, () => {});
    }
  }
}
