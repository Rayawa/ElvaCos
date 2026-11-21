import { common, EnvironmentCallback } from '@kit.AbilityKit';
/** Canvas 已绘制的像素不会像 Resource 属性一样自动换色，环境变化后主动重绘。API 9 起可用。 */

export class ChartConfigurationObserver {
    private host?: common.UIAbilityContext;
    private application: common.ApplicationContext | undefined;
    private callbackId: number = -1;
    private drawTimer: number = -1;
    private revision: number = 0;
    private colors: Map<number, number> = new Map<number, number>();

    color(resource: Resource, fallback: number = 0xFF1E6FCD): number {
        const cached = this.colors.get(resource.id);
        if (cached !== undefined || !this.host) {
            return cached ?? fallback;
        }
        try {
            const color = this.host.resourceManager.getColorSync(resource.id);
            this.colors.set(resource.id, color);
            return color;
        } catch (error) {
            console.warn('[ElvaCos][ChartConfigurationObserver] 颜色读取失败: ' + JSON.stringify(error));
            this.colors.set(resource.id, fallback);
            return fallback;
        }
    }

    clearColors(): void {
        this.colors.clear();
    }

    start(host: common.UIAbilityContext, draw: () => void): void {
        if (this.callbackId >= 0) {
            return;
        }
        this.host = host;
        const revision = ++this.revision;
        const callback: EnvironmentCallback = {
            onConfigurationUpdated: (): void => {
                if (revision !== this.revision) {
                    return;
                }
                this.clearColors();
                if (this.drawTimer >= 0) {
                    clearTimeout(this.drawTimer);
                }
                this.drawTimer = setTimeout((): void => {
                    this.drawTimer = -1;
                    draw();
                }, 0);
            },
            onMemoryLevel: (): void => {
            },
        };
        try {
            this.application = host.getApplicationContext();
            this.callbackId = this.application.on('environment', callback);
        } catch (error) {
            console.warn('[ElvaCos][ChartConfigurationObserver] ' + JSON.stringify(error));
        }
    }

    stop(): void {
        this.revision++;
        this.clearColors();
        this.host = undefined;
        if (this.drawTimer >= 0) {
            clearTimeout(this.drawTimer);
            this.drawTimer = -1;
        }
        if (this.application && this.callbackId >= 0) {
            this.application.off('environment', this.callbackId).catch((): void => {
            });
        }
        this.callbackId = -1;
        this.application = undefined;
    }
}
