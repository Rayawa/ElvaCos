import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';

export default class OpenHarmonyPerformanceTestRunner implements TestRunner {
    onPrepare(): void {
    }

    async onRun(): Promise<void> {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator();
        const started = Date.now();
        try {
            await delegator.startAbility({ bundleName: 'top.rayawa.elvacos', abilityName: 'EntryAbility' });
            const suite = await import('../test/DevicePerformance.test');
            Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), (): void => suite.default(started));
        } catch (error) {
            delegator.finishTest('Performance test could not start: ' + String(error), -1, () => {});
        }
    }
}
