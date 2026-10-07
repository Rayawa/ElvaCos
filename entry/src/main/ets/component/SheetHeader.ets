import { PressFeedback } from '../common/pressFeedback';
import { Theme } from '../common/Theme';
import { HapticService } from '../common/HapticService';

/** 弹出层统一头部：左侧标题 + 右上角关闭按钮（所有 Sheet 都必须使用）。 */
@ComponentV2
export struct SheetHeader {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param title: string = '';
  @Param hint: string = '';
  @Param haptic: boolean = true;
  @Param hapticLevel: number = 1;
  @Event close: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.ink)
          .accessibilityText(this.title)
        if (this.hint) {
          Text(this.hint).fontSize(12).fontColor(Theme.muted).accessibilityText(this.hint)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(18)
          .fontColor([Theme.muted])
      }
      .width(36)
      .height(36)
      .id('sheet-close')
      .borderRadius(18)
      .backgroundColor(Theme.tint)
      .onClick((): void => {
        HapticService.confirm(this.haptic, this.hapticLevel);
        this.close();
      })
      .accessibilityText('关闭')
      .accessibilityLevel('yes').visualEffect(this.feedback.effect('stack-1', true)).compositingFilter(this.feedback.filter('stack-1', true)).attributeModifier(this.feedback.control('stack-1', true))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
