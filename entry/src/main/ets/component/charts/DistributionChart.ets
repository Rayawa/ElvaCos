import { common } from '@kit.AbilityKit';
import { Theme } from '../../common/Theme';
import { PressFeedback } from '../../common/pressFeedback';
import { vibration } from '../../common/vibration';
import { PhotoDistributionItem } from '../../model/Statistics';
import { ChartConfigurationObserver } from './ChartConfigurationObserver';

/** 沿用 Dashboard DistributionPanel 的 Canvas 扇区、资源色、入场动画与图例选中反馈。 */
@ComponentV2
export struct DistributionChart {
  @Param title: string = '';
  @Param items: PhotoDistributionItem[] = [];
  @Param paletteId: string = '';
  @Local selected: number = 0;
  @Local canvasSize: number = 200;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  private ready: boolean = false;
  private progress: number = 1;
  private animationTimer: number = -1;
  private drawTimer: number = -1;
  private animationToken: number = 0;
  private configuration: ChartConfigurationObserver = new ChartConfigurationObserver();
  aboutToAppear(): void {
    this.configuration.start(this.getUIContext().getHostContext() as common.UIAbilityContext, (): void => { this.draw(); });
  }

  private total(): number { return this.items.reduce((sum: number, item: PhotoDistributionItem): number => sum + item.value, 0); }
  private color(index: number): Resource {
    const colors: Resource[] = [Theme.brand, $r('app.color.v3_accent_cyan'), $r('app.color.v3_accent_orange'),
      $r('app.color.v3_accent_green'), $r('app.color.v3_accent_purple'), Theme.muted];
    return colors[index % colors.length];
  }
  private resolved(resource: Resource): number {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try { return host.resourceManager.getColorSync(resource.id); }
    catch (error) { console.warn('[ElvaCos][DistributionChart] 颜色读取失败: ' + JSON.stringify(error)); return 0xFF1E6FCD; }
  }
  private summary(): string {
    const item = this.items[this.selected];
    return item ? item.label + ' · ' + item.value + ' 张 · ' + (this.total() > 0 ? item.value * 100 / this.total() : 0).toFixed(1) + '%' : '暂无照片';
  }
  @Monitor('items')
  private dataChanged(): void { this.selected = Math.max(0, this.items.findIndex((item: PhotoDistributionItem): boolean => item.value > 0)); this.animate(); }
  @Monitor('paletteId')
  private themeChanged(): void { this.draw(); }
  private animate(): void {
    if (this.animationTimer >= 0) { clearTimeout(this.animationTimer); }
    const token = ++this.animationToken;
    if (!this.ready) { return; }
    const start = Date.now();
    const tick = (): void => {
      if (token !== this.animationToken) { return; }
      const elapsed = Math.min(1, (Date.now() - start) / 700);
      this.progress = 1 - Math.pow(1 - elapsed, 3);
      this.draw();
      this.animationTimer = elapsed < 1 ? setTimeout(tick, 16) : -1;
    };
    tick();
  }
  private draw(): void {
    if (!this.ready) { return; }
    const center = this.canvasSize / 2;
    const radius = center - 12;
    const total = this.total();
    this.context.clearRect(0, 0, this.canvasSize, this.canvasSize);
    if (total === 0) { return; }
    let start = -Math.PI / 2;
    for (let index = 0; index < this.items.length; index++) {
      const sweep = this.items[index].value / total * Math.PI * 2 * this.progress;
      if (sweep > 0) {
        this.context.beginPath(); this.context.moveTo(center, center);
        this.context.arc(center, center, radius, start, start + sweep); this.context.closePath();
        this.context.fillStyle = this.resolved(this.color(index)); this.context.fill();
        this.context.strokeStyle = this.resolved(Theme.surface); this.context.lineWidth = 2; this.context.stroke();
        if (index === this.selected) {
          this.context.beginPath(); this.context.arc(center, center, radius + 4, start, start + sweep);
          this.context.strokeStyle = this.resolved(this.color(index)); this.context.lineWidth = 4; this.context.stroke();
        }
      }
      start += sweep;
    }
    this.context.beginPath(); this.context.arc(center, center, radius * 0.62, 0, Math.PI * 2);
    this.context.fillStyle = this.resolved(Theme.surface); this.context.fill();
    this.context.fillStyle = this.resolved(Theme.ink); this.context.textAlign = 'center';
    this.context.font = '26vp sans-serif'; this.context.fillText(String(total), center, center + 2);
    this.context.fillStyle = this.resolved(Theme.muted); this.context.font = '12vp sans-serif';
    this.context.fillText('照片记录', center, center + 23);
  }
  private choose(index: number): void { vibration.dotVibration(); this.selected = index; this.draw(); }
  private chooseAt(x: number, y: number): void {
    const dx = x - this.canvasSize / 2; const dy = y - this.canvasSize / 2;
    const distance = Math.sqrt(dx * dx + dy * dy); const radius = this.canvasSize / 2 - 12;
    if (this.progress < 1 || this.total() === 0 || distance < radius * 0.62 || distance > radius + 6) { return; }
    const angle = (Math.atan2(dy, dx) + Math.PI / 2 + Math.PI * 2) % (Math.PI * 2);
    let end = 0;
    for (let index = 0; index < this.items.length; index++) {
      end += this.items[index].value / this.total() * Math.PI * 2;
      if (angle < end) { this.choose(index); return; }
    }
  }
  aboutToDisappear(): void {
    this.configuration.stop();
    this.ready = false; this.animationToken++;
    if (this.animationTimer >= 0) { clearTimeout(this.animationTimer); this.animationTimer = -1; }
    if (this.drawTimer >= 0) { clearTimeout(this.drawTimer); this.drawTimer = -1; }
  }
  build() {
    Column({ space: 12 }) {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.ink).width('100%')
      if (this.total() > 0) {
        Canvas(this.context).width(this.canvasSize).height(this.canvasSize).borderRadius(Theme.cardRadius)
          .onReady((): void => { this.ready = true; this.dataChanged(); })
          .onAreaChange((): void => {
            if (this.drawTimer >= 0) { clearTimeout(this.drawTimer); }
            this.drawTimer = setTimeout((): void => { this.drawTimer = -1; this.draw(); }, 0);
          })
          .onClick((event: ClickEvent): void => { this.chooseAt(event.x, event.y); })
          .visualEffect(this.feedback.effect('distribution-canvas', true))
          .compositingFilter(this.feedback.filter('distribution-canvas', true))
          .attributeModifier(this.feedback.control('distribution-canvas', true))
          .accessibilityText(this.title + '环形图，' + this.summary())
          .accessibilityDescription('点击扇区或下方图例查看数量与占比')
        Text(this.summary()).fontSize(13).fontColor(Theme.muted).width('100%')
        GridRow({ columns: 2, gutter: { x: 8, y: 8 } }) {
          ForEach(this.items, (item: PhotoDistributionItem, index: number) => {
            GridCol() {
              Row({ space: 6 }) {
                Row().width(8).height(8).borderRadius(4).backgroundColor(this.color(index))
                Text(item.label).fontSize(12).fontColor(Theme.ink).layoutWeight(1)
                Text(item.value + ' 张').fontSize(12).fontColor(Theme.muted)
              }.width('100%').padding(10).borderRadius(10).backgroundColor(Theme.tint)
                .border({ width: 1, color: index === this.selected ? this.color(index) : Theme.line })
                .onClick((): void => { this.choose(index); }).focusable(true)
                .visualEffect(this.feedback.effect('legend:' + item.label))
                .compositingFilter(this.feedback.filter('legend:' + item.label))
                .attributeModifier(this.feedback.control('legend:' + item.label))
                .accessibilityRole(AccessibilityRoleType.BUTTON).accessibilitySelected(index === this.selected)
                .accessibilityText(item.label + '，' + item.value + ' 张')
            }
          }, (item: PhotoDistributionItem): string => item.label)
        }.width('100%')
      } else {
        Text('导入照片后可查看各处理阶段的数量与占比。').fontSize(13).fontColor(Theme.muted).padding({ top: 12, bottom: 12 })
      }
    }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
      .border({ width: 1, color: Theme.line }).alignItems(HorizontalAlign.Center)
  }
}
