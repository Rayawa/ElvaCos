import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { application } from '@kit.AbilityKit';
import { Hypium } from '@ohos/hypium';
import { TestContext } from '../testability/TestContext';
import testsuite from '../test/List.test';

// Persistence/media tests need a real module Context, but no foreground UI.
// Keep the user's screen state untouched while exercising our own sandbox.
export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      const context = await application.createModuleContext(delegator.getAppContext().getApplicationContext(), 'entry_test');
      TestContext.value = context;
      Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), testsuite);
    } catch (error) { delegator.finishTest('Native test context initialization failed', -1, () => {}); }
  }
}
