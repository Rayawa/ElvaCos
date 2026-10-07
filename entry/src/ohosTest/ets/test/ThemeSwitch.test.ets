import { Component, Driver, ON } from '@kit.TestKit';
import { describe, beforeAll, it, expect } from '@ohos/hypium';

export default function themeSwitchTest(restore: boolean): void {
  describe('ThemeSwitch', () => {
    const bundle = 'top.rayawa.elvacos';
    let driver: Driver;
    const required = async (id: string): Promise<Component> => {
      const component = await driver.waitForComponent(ON.id(id).inWindow(bundle), 5000);
      if (!component) { throw new Error('Missing theme control: ' + id); }
      return component;
    };
    const select = async (id: string, appearance: string): Promise<void> => {
      for (let attempt = 0; attempt < 20; attempt++) {
        if (await (await required('theme-selection')).getText() === id + ':' + appearance) { return; }
        await driver.delayMs(100);
      }
      throw new Error('Theme selection did not persist: ' + id + ':' + appearance);
    };
    const reveal = async (id: string): Promise<void> => {
      const scroll = await required('settings-scroll');
      await scroll.scrollToTop(600); await driver.delayMs(250);
      for (let attempt = 0; attempt < 12; attempt++) {
        if (await driver.findComponent(ON.id(id).inWindow(bundle))) { return; }
        const bounds = await scroll.getBounds();
        const x = Math.round(bounds.left + (bounds.right - bounds.left) * .15);
        await driver.swipe(x, Math.round(bounds.bottom - 60), x, Math.round(bounds.top + 60), 600);
        await driver.delayMs(200);
      }
      throw new Error('Theme row unreachable: ' + id);
    };
    const appearance = async (label: string): Promise<void> => {
      const scroll = await required('settings-scroll');
      await scroll.scrollToTop(600); await driver.delayMs(250);
      for (let attempt = 0; attempt < 12; attempt++) {
        const component = await driver.findComponent(ON.text(label).inWindow(bundle));
        if (component) { await component.click(); await driver.delayMs(500); return; }
        const bounds = await scroll.getBounds();
        const x = Math.round(bounds.left + (bounds.right - bounds.left) * .15);
        await driver.swipe(x, Math.round(bounds.bottom - 60), x, Math.round(bounds.top + 60), 600);
        await driver.delayMs(200);
      }
      throw new Error('Appearance control unreachable: ' + label);
    };
    beforeAll(async () => {
      driver = Driver.create();
      await required('theme-selection');
      await (await driver.findWindow({ bundleName: bundle })).focus();
    });
    if (restore) {
      it('coldLaunchRestoresColorAndAppearanceFromIsolatedPreferences', 0, async () => {
        await select('red', 'mist');
        await reveal('theme-color-red');
        expect(await (await required('theme-color-red')).isSelected()).assertTrue();
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-theme-restored.png');
      });
    } else {
      it('existingAppearanceWithoutColorKeyKeepsBlueAndLight', 0, async () => {
        await select('blue', 'sky');
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-theme-start.png');
        await reveal('theme-color-blue');
        expect(await (await required('theme-color-blue')).isSelected()).assertTrue();
      });
      it('allTenPalettesSwitchImmediatelyAndRetainIndependentAppearance', 0, async () => {
        for (const mode of ['sky', 'mist']) {
          await appearance(mode === 'sky' ? '浅色' : '深色');
          for (const color of ['green', 'pink', 'orange', 'red', 'blue']) {
            await reveal('theme-color-' + color);
            await (await required('theme-color-' + color)).click();
            await select(color, mode);
            await driver.delayMs(300);
            expect(await (await required('theme-color-' + color)).isSelected()).assertTrue();
            await driver.screenCap('/data/storage/el2/base/cache/elvacos-theme-' + color + '-' + mode + '.png');
          }
        }
        await appearance('跟随系统'); await select('blue', 'system');
        await reveal('theme-color-red'); await (await required('theme-color-red')).click();
        await select('red', 'system');
      });
      it('fiveChoicesFitNarrowLargeFontAndSaveFinalDarkSelection', 0, async () => {
        await (await required('layout-width-narrow')).click();
        await (await required('layout-font-large')).click();
        await driver.delayMs(700);
        await reveal('theme-color-blue');
        let previousRight = 0;
        const canvas = await (await required('settings-layout-canvas')).getBounds();
        for (const color of ['blue', 'green', 'pink', 'orange', 'red']) {
          const bounds = await (await required('theme-color-' + color)).getBounds();
          expect(bounds.left >= previousRight && bounds.right <= canvas.right).assertTrue();
          previousRight = bounds.right;
        }
        await driver.screenCap('/data/storage/el2/base/cache/elvacos-theme-narrow-large.png');
        await appearance('深色'); await select('red', 'mist');
        await (await required('layout-font-default')).click();
      });
    }
  });
}
