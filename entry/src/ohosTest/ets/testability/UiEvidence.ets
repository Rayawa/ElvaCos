import { Driver, abilityDelegatorRegistry } from '@kit.TestKit';

export async function captureScreenshot(driver: Driver, path: string): Promise<void> {
    const appWindow = await driver.findWindow({ bundleName: 'top.rayawa.elvacos' });
    if (!appWindow || !await appWindow.isFocused()) {
        throw new Error('ElvaCos must be in the foreground before capturing UI evidence');
    }
    await driver.screenCap(path);
    await abilityDelegatorRegistry.getAbilityDelegator().print('UI_SCREENSHOT ' + path + '\n');
}
