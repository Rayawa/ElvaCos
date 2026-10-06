import { UIAbility } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';
import { TestContext } from './TestContext';
import testsuite from '../test/List.test';

export default class TestAbility extends UIAbility {
  onCreate(): void {
    TestContext.value = this.context;
    Hypium.hypiumTest(abilityDelegatorRegistry.getAbilityDelegator(), abilityDelegatorRegistry.getArguments(), testsuite);
  }
}
