import { common, EnvironmentCallback } from '@kit.AbilityKit';

/** Canvas 已绘制的像素不会像 Resource 属性一样自动换色，环境变化后主动重绘。API 9 起可用。 */
export class ChartConfigurationObserver {
  private application: common.ApplicationContext | undefined;
  private callbackId: number = -1;
  private drawTimer: number = -1;
  start(host: common.UIAbilityContext, draw: () => void): void {
    if (this.callbackId >= 0) { return; }
    const callback: EnvironmentCallback = {
      onConfigurationUpdated: (): void => {
        if (this.drawTimer >= 0) { clearTimeout(this.drawTimer); }
        this.drawTimer = setTimeout((): void => { this.drawTimer = -1; draw(); }, 0);
      },
      onMemoryLevel: (): void => {},
    };
    try {
      this.application = host.getApplicationContext();
      this.callbackId = this.application.on('environment', callback);
    } catch (error) { console.warn('[ElvaCos][ChartConfigurationObserver] ' + JSON.stringify(error)); }
  }
  stop(): void {
    if (this.drawTimer >= 0) { clearTimeout(this.drawTimer); this.drawTimer = -1; }
    if (this.application && this.callbackId >= 0) {
      this.application.off('environment', this.callbackId).catch((): void => {});
    }
    this.callbackId = -1; this.application = undefined;
  }
}
