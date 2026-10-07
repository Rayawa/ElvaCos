import { Driver, ON, abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { AccountService } from '../../../main/ets/services/account/AccountService';

/** Explicit opt-in integration suite; never included in the regular regression runner. */
export default function accountIntegrationTest(): void {
  describe('HuaweiAccountIntegration', () => {
    it('configuredApplicationCanAuthenticateWithRegisteredSignature', 0, async () => {
      const driver = Driver.create();
      await driver.delayMs(1200);
      const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      expect(AccountService.configurationMessage(ability.context)).assertEqual('');
      const client = ability.context.currentHapModuleInfo.metadata.find((entry) => entry.name === 'client_id');
      expect(client?.value).assertEqual('6917618412076034516');
      // Invoke the production entry module through its normal settings action.
      const bundle = 'top.rayawa.elvacos';
      const tap = async (text: string): Promise<void> => {
        let components = await driver.findComponents(ON.text(text).inWindow(bundle));
        if (!components || components.length === 0) { components = await driver.findComponents(ON.id('root-action-' + text).inWindow(bundle)); }
        if (!components || components.length === 0) { throw new Error('Missing login UI: ' + text); }
        await components[components.length - 1].click(); await driver.delayMs(400);
      };
      await tap('我的'); await tap('设置');
      const signedIn = await driver.findComponent(ON.text('退出').inWindow(bundle));
      if (!signedIn) { await tap('登录'); }
      for (let attempt = 0; attempt < 60; attempt++) {
        if (await driver.findComponent(ON.text('退出').inWindow(bundle))) {
          console.info('[ElvaCos][AccountIntegration] Production login succeeded; no identity or token logged.');
          await driver.pressBack(); return;
        }
        const configurationErrors = [
          '华为账号配置无效（1001502003）：请核对应用 Client ID 与签名 Profile',
          '华为账号配置无效（1001500001）：请核对当前包名与签名指纹',
        ];
        for (const text of configurationErrors) {
          if (await driver.findComponent(ON.text(text))) { await driver.pressBack(); throw new Error(text); }
        }
        await driver.delayMs(500);
      }
      throw new Error('Production login did not complete; check Account Kit error or the system authorization screen.');
    });
  });
}
