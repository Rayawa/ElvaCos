import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';

/**
 * 设置项里的三档选择：滑块 + 档位标签。
 * 与 Dashboard SettingsPanel 的振动/材质滑块保持一致：`$$` 双向绑定，
 * 拖动时滑块连续跟随手指，松手（Click/End）才提交并给出反馈；
 * 档位标签宽度与 Dashboard 的手动左右手控件一致（2 字 40vp，长标签 64vp）。
 */
@ComponentV2
export struct SettingsChoiceSlider {
  @Param index: number = 0;
  @Param labels: string[] = [];
  @Param accessibilityLabel: string = '';
  @Param isEnabled: boolean = true;
  @Event changed: (index: number) => Promise<boolean> = async () => true;
  @Local private current: number = 0;
  @Local private selected: number = 0;
  private dragging: boolean = false;
  private pending: number = 0;
  private revision: number = 0;

  aboutToAppear(): void { this.current = this.index; this.selected = this.index; }
  @Monitor('index')
  indexChanged(): void {
    if (!this.dragging && this.pending === 0) { this.current = this.index; this.selected = this.index; }
  }

  private controlWidth(): number { return 190; }

  private maxIndex(): number { return Math.max(0, this.labels.length - 1); }

  private labelWidth(label: string): number { return label.length > 2 ? 64 : 40; }

  private async choose(position: number): Promise<void> {
    if (!this.isEnabled) { return; }
    this.current = position;
    if (position === this.selected && (this.pending > 0 || position === this.index)) { return; }
    this.selected = position;
    const revision = ++this.revision;
    this.pending++;
    vibration.dotVibration();
    let saved = false;
    try { saved = await this.changed(position); }
    finally {
      this.pending--;
      // 成功时保持本地选择，等父组件输入刷新；不能在下一帧之前回写旧 index。
      if (!saved && revision === this.revision && !this.dragging) { this.current = this.index; this.selected = this.index; }
    }
  }

  build() {
    Column({ space: 1 }) {
      Slider({ value: $$this.current, min: 0, max: this.maxIndex(), step: 1, style: SliderStyle.InSet })
        .width(this.controlWidth())
        .selectedColor(Theme.accent)
        .trackColor(Theme.tint)
        .blockBorderColor(Theme.surface)
        .showSteps(true)
        .showTips(false)
        .enabled(this.isEnabled)
        .onChange((value: number, mode: SliderChangeMode): void => {
          this.dragging = mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving;
          if (mode === SliderChangeMode.Click || mode === SliderChangeMode.End) { this.choose(Math.round(value)); }
        })
        .accessibilityText(`${this.accessibilityLabel}，当前${this.labels[this.selected] || ''}，共 ${this.labels.length} 档`)
      Row() {
        ForEach(this.labels, (label: string, position: number) => {
          Text(label)
            .fontSize(12)
            .fontWeight(position === this.selected ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(position === this.selected ? Theme.accent : Theme.muted)
            .width(this.labelWidth(label))
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .enabled(this.isEnabled)
            .onClick((): void => { this.choose(position); })
            .accessibilityText(label + (position === this.selected ? '，已选择' : ''))
        }, (label: string) => label)
      }
      .width(this.controlWidth())
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width(this.controlWidth())
    .accessibilityGroup(true)
    .accessibilityText(`${this.accessibilityLabel}，当前${this.labels[this.selected] || ''}`)
  }
}
