import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';

export default class OpenHarmonyFidelityUITestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      await delegator.startAbility({ bundleName: 'top.rayawa.elvacos', abilityName: 'EntryAbility' });
      const suite = await import('../test/FidelityLayout.test');
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), suite.default);
    } catch (error) { delegator.finishTest('Fidelity layout test requires an unlocked application window', -1, () => {}); }
  }
}
