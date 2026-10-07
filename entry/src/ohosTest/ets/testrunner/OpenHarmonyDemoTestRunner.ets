import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { application } from '@kit.AbilityKit';
import { Hypium } from '@ohos/hypium';
import { TestContext } from '../testability/TestContext';
import demoDataTest from '../test/DemoData.test';

export default class OpenHarmonyDemoTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      TestContext.value = await application.createModuleContext(delegator.getAppContext().getApplicationContext(), 'entry_test');
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), demoDataTest);
    } catch (error) { delegator.finishTest('Demo test context initialization failed', -1, () => {}); }
  }
}
