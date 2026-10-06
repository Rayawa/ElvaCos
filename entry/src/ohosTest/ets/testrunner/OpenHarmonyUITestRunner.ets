import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';

export default class OpenHarmonyUITestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      await delegator.startAbility({ bundleName: 'top.rayawa.elvacos', abilityName: 'EntryAbility' });
      const suite = await import('../test/UiShell.test');
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), suite.default);
    } catch (error) { delegator.finishTest('UI test requires an unlocked application window', -1, () => {}); }
  }
}
