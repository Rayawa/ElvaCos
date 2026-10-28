import { Driver, ON } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { getApplicationState } from '../../../main/ets/state/appState';
/** Explicit opt-in boundary check; the deferred account feature never opens authentication. */

export default function accountIntegrationTest(): void {

    describe('DeferredAccountBoundary', () => {
        it('localSettingsRemainReachableWithoutAuthenticationActions', 0, async () => {
            const driver = Driver.create();
            const bundle = 'top.rayawa.elvacos';
            await driver.waitForComponent(ON.id('main-tabs').inWindow(bundle), 5000);
            await (await driver.findWindow({ bundleName: bundle })).focus();
            const homes = await driver.findComponents(ON.text('首页').inWindow(bundle));
            await homes[homes.length - 1].click();
            await driver.delayMs(350);
            const signedIn = getApplicationState().account.signedIn;
            await (await driver.findComponent(ON.id('root-action-设置').inWindow(bundle))).click();
            await driver.delayMs(600);
            expect(!!(await driver.findComponent(ON.id('settings-scroll').inWindow(bundle)))).assertTrue();
            expect((await driver.findComponents(ON.text('华为账号').inWindow(bundle))).length).assertEqual(0);
            expect((await driver.findComponents(ON.text('登录').inWindow(bundle))).length).assertEqual(0);
            expect((await driver.findComponents(ON.text('退出').inWindow(bundle))).length).assertEqual(0);
            expect(getApplicationState().account.signedIn).assertEqual(signedIn);
            await driver.pressBack();
            await driver.delayMs(400);
            expect(!!(await driver.findComponent(ON.id('main-tabs').inWindow(bundle)))).assertTrue();
        });
    });
}
