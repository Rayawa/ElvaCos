import { Theme } from '../common/Theme';

@ComponentV2
export struct SettingsHandControl {
  @Param hand: string = 'left';
  @Param isEnabled: boolean = true;
  @Event changed: (hand: string) => void = () => {};
  private index(): number { return this.hand === 'right' ? 2 : this.hand === 'auto' ? 1 : 0; }
  private choose(index: number): void {
    if (this.isEnabled && index !== this.index()) { this.changed(['left', 'auto', 'right'][index]); }
  }
  build() {
    Column({ space: 1 }) {
      Slider({ value: this.hand === 'right' ? 2 : this.hand === 'auto' ? 1 : 0, min: 0, max: 2, step: 1, style: SliderStyle.InSet })
        .width(190).selectedColor(Theme.accent).trackColor(Theme.tint).blockBorderColor(Theme.surface)
        .showSteps(true).showTips(false).enabled(this.isEnabled)
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.Click || mode === SliderChangeMode.End) { this.choose(Math.round(value)); }
        }).accessibilityText('单手操作，左手、智感握持、右手三档')
      Row() {
        ForEach(['左手', '智感握持', '右手'], (label: string, index: number) => {
          Text(label).fontSize(12).fontWeight(this.index() === index ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.index() === index ? Theme.accent : Theme.muted).width(index === 1 ? 64 : 40).textAlign(TextAlign.Center)
            .enabled(this.isEnabled).onClick((): void => { this.choose(index); })
            .accessibilityText(label + (this.index() === index ? '，已选择' : ''))
        }, (label: string) => label)
      }.width(190).justifyContent(FlexAlign.SpaceBetween)
    }.width(190)
  }
}
