import { common } from '@kit.AbilityKit';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { ChartConfigurationObserver } from './ChartConfigurationObserver';

export interface BarChartItem {
    label: string;
    value: number;
    color?: Resource;
}

/** Canvas 柱状图,支持入场动画、点击选择、响应式布局。参考 Dashboard 图表实现。 */
@ComponentV2
export struct BarChart {
    @Param title: string = '';
    @Param items: BarChartItem[] = [];
    @Param unit: string = '';
    @Param showGrid: boolean = true;
    @Param paletteId: string = '';
    @Local selected: number = 0;
    @Local canvasWidth: number = 320;
    @Local canvasHeight: number = 260;
    private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
    private ready: boolean = false;
    private progress: number = 1;
    private animationTimer: number = -1;
    private drawTimer: number = -1;
    private animationToken: number = 0;
    private configuration: ChartConfigurationObserver = new ChartConfigurationObserver();

    aboutToAppear(): void {
        this.configuration.start(this.getUIContext().getHostContext() as common.UIAbilityContext, (): void => {
            this.draw();
        });
    }

    private maximum(): number {
        return Math.max(1, ...this.items.map((item: BarChartItem) => item.value));
    }

    private defaultColor(index: number): Resource {
        const colors: Resource[] = [
            Theme.brand,
            Theme.info,
            Theme.warning,
            Theme.success,
            Theme.purple,
            Theme.muted,
        ];
        return colors[index % colors.length];
    }

    private itemColor(item: BarChartItem, index: number): Resource {
        return item.color || this.defaultColor(index);
    }

    private resolved(resource: Resource): number {
        const host = this.getUIContext().getHostContext() as common.UIAbilityContext;
        try {
            return host.resourceManager.getColorSync(resource.id);
        } catch (error) {
            console.warn('[ElvaCos][BarChart] 颜色读取失败: ' + JSON.stringify(error));
            return 0xFF1E6FCD;
        }
    }

    private valueLabel(value: number): string {
        if (this.unit === '元') {
            return '¥' + value.toFixed(2);
        }
        if (this.unit === '%') {
            return value.toFixed(1) + '%';
        }
        return String(Math.round(value)) + (this.unit || '');
    }

    @Monitor('items')
    private dataChanged(): void {
        this.selected = 0;
        this.animate();
    }

    @Monitor('paletteId')
    private themeChanged(): void {
        this.draw();
    }

    private animate(): void {
        if (this.animationTimer >= 0) {
            clearTimeout(this.animationTimer);
        }
        const token = ++this.animationToken;
        if (!this.ready) {
            return;
        }
        const start = Date.now();
        const tick = (): void => {
            if (token !== this.animationToken) {
                return;
            }
            const elapsed = Math.min(1, (Date.now() - start) / 600);
            this.progress = 1 - Math.pow(1 - elapsed, 3);
            this.draw();
            this.animationTimer = elapsed < 1 ? setTimeout(tick, 16) : -1;
        };
        tick();
    }

    private draw(): void {
        if (!this.ready || this.items.length === 0) {
            return;
        }
        const width = this.canvasWidth;
        const height = this.canvasHeight;
        this.context.clearRect(0, 0, width, height);

        const host = this.getUIContext().getHostContext() as common.UIAbilityContext;
        let gridColor = 0x33334455;
        let textColor = 0xFF666666;
        try {
            gridColor = host.resourceManager.getColorSync(Theme.groupDivider.id);
            textColor = host.resourceManager.getColorSync(Theme.muted.id);
        } catch (error) {
            console.warn('[ElvaCos][BarChart] 主题颜色读取失败: ' + JSON.stringify(error));
        }

        const left = 50;
        const right = 20;
        const top = 20;
        const bottom = 60;
        const drawWidth = Math.max(1, width - left - right);
        const drawHeight = Math.max(1, height - top - bottom);
        const maximum = this.maximum();

        // 绘制网格和 Y 轴刻度
        if (this.showGrid) {
            this.context.strokeStyle = gridColor;
            this.context.lineWidth = 1;
            this.context.setLineDash([4, 4]);
            this.context.font = '11vp sans-serif';
            this.context.fillStyle = textColor;
            for (let row = 0; row <= 4; row++) {
                const y = top + drawHeight * row / 4;
                this.context.beginPath();
                this.context.moveTo(left, y);
                this.context.lineTo(left + drawWidth, y);
                this.context.stroke();
                const value = maximum * (4 - row) / 4;
                this.context.textAlign = 'right';
                this.context.fillText(this.valueLabel(value), left - 6, y + 4);
            }
            this.context.setLineDash([]);
        }

        // 绘制柱状图
        const barCount = this.items.length;
        const groupSpacing = drawWidth * 0.1;
        const availableWidth = drawWidth - groupSpacing * 2;
        const barSpacing = Math.min(12, availableWidth / barCount * 0.2);
        const barWidth = Math.max(8, (availableWidth - barSpacing * (barCount - 1)) / barCount);

        for (let index = 0; index < this.items.length; index++) {
            const item = this.items[index];
            const x = left + groupSpacing + (barWidth + barSpacing) * index;
            const barHeight = drawHeight * (item.value / maximum) * this.progress;
            const y = top + drawHeight - barHeight;
            const color = this.resolved(this.itemColor(item, index));

            // 绘制柱子
            this.context.fillStyle = color;
            this.context.fillRect(x, y, barWidth, barHeight);

            // 选中效果
            if (index === this.selected) {
                this.context.strokeStyle = color;
                this.context.lineWidth = 2;
                this.context.strokeRect(x - 2, y - 2, barWidth + 4, barHeight + 4);
            }

            // 绘制 X 轴标签
            this.context.fillStyle = textColor;
            this.context.font = '10vp sans-serif';
            this.context.textAlign = 'center';
            this.context.save();
            this.context.translate(x + barWidth / 2, height - bottom + 20);
            this.context.rotate(-Math.PI / 6);
            this.context.fillText(item.label, 0, 0);
            this.context.restore();
        }
    }

    private selectAt(x: number): void {
        if (!this.ready || this.items.length === 0) {
            return;
        }
        const left = 50;
        const drawWidth = Math.max(1, this.canvasWidth - left - 20);
        const groupSpacing = drawWidth * 0.1;
        const availableWidth = drawWidth - groupSpacing * 2;
        const barCount = this.items.length;
        const barSpacing = Math.min(12, availableWidth / barCount * 0.2);
        const barWidth = Math.max(8, (availableWidth - barSpacing * (barCount - 1)) / barCount);

        for (let index = 0; index < this.items.length; index++) {
            const barX = left + groupSpacing + (barWidth + barSpacing) * index;
            if (x >= barX && x <= barX + barWidth) {
                if (index !== this.selected) {
                    vibration.dotVibration();
                    this.selected = index;
                    this.draw();
                }
                return;
            }
        }
    }

    aboutToDisappear(): void {
        this.configuration.stop();
        this.ready = false;
        this.animationToken++;
        if (this.animationTimer >= 0) {
            clearTimeout(this.animationTimer);
            this.animationTimer = -1;
        }
        if (this.drawTimer >= 0) {
            clearTimeout(this.drawTimer);
            this.drawTimer = -1;
        }
    }

    build() {
        Column({ space: 12 }) {
            if (this.title) {
                Text(this.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .width('100%')
                    .accessibilityText(this.title)
            }

            if (this.items.length > 0) {
                Canvas(this.context)
                    .width('100%')
                    .height(this.canvasHeight)
                    .borderRadius(Theme.cardRadius)
                    .onReady((): void => {
                        this.ready = true;
                        this.dataChanged();
                    })
                    .onAreaChange((_oldArea: Area, newArea: Area): void => {
                        const width = Number(newArea.width);
                        if (width > 0) {
                            this.canvasWidth = width;
                            if (this.drawTimer >= 0) {
                                clearTimeout(this.drawTimer);
                            }
                            this.drawTimer = setTimeout((): void => {
                                this.drawTimer = -1;
                                this.draw();
                            }, 0);
                        }
                    })
                    .onClick((event: ClickEvent): void => {
                        this.selectAt(event.x);
                    })
                    .accessibilityText(`${this.title}柱状图,${this.items.length} 个项目`)
                    .accessibilityDescription('点击柱子查看详细数值')

                // 当前选中项的详细信息
                if (this.selected >= 0 && this.selected < this.items.length) {
                    Row({ space: 8 }) {
                        Row()
                            .width(8)
                            .height(8)
                            .borderRadius(4)
                            .backgroundColor(this.itemColor(this.items[this.selected], this.selected))
                        Text(this.items[this.selected].label)
                            .fontSize(13)
                            .fontColor(Theme.ink)
                            .layoutWeight(1)
                        Text(this.valueLabel(this.items[this.selected].value))
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.brand)
                    }
                    .width('100%')
                    .padding(10)
                    .borderRadius(Theme.slotRadius)
                    .backgroundColor(Theme.tint)
                    .border({ width: 1, color: Theme.line })
                    .accessibilityText(`${this.items[this.selected].label}，${this.valueLabel(this.items[this.selected].value)}`)
                }
            } else {
                Text(`暂无${this.title}数据`)
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .padding({ top: 12, bottom: 12 })
                    .accessibilityText(`暂无${this.title}数据`)
            }
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.surface)
        .borderRadius(Theme.cardRadius)
        .border({ width: 1, color: Theme.line })
        .alignItems(HorizontalAlign.Start)
        .accessibilityGroup(true)
    }
}
