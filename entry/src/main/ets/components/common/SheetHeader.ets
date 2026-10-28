import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { Theme } from '../../ui/theme/Theme';
/** 弹出层统一头部：左侧标题 + 右上角关闭按钮（所有 Sheet 都必须使用）。 */

@ComponentV2
export struct SheetHeader {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Param title: string = '';
    @Param hint: string = '';
    @Param haptic: boolean = true;
    @Param hapticLevel: number = 1;
    @Param closeSize: number = 48;
    @Event close: () => void = () => {};

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Row({ space: 12 }) {
            Text(this.title)
                .fontSize(19)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ink)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .accessibilityText(this.title)
                .accessibilityDescription(this.hint)
            Stack() {
                SymbolGlyph($r('sys.symbol.xmark'))
                    .fontSize(18)
                    .fontColor([Theme.muted])
            }.width(this.closeSize)
                .height(this.closeSize)
                .id('sheet-close')
                .borderRadius(this.closeSize / 2)
                .backgroundColor(Theme.tint)
                .onClick((): void => {
                    this.close();
                })
                .accessibilityText('关闭')
                .focusable(true)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityLevel('yes')
                .visualEffect(this.feedback.effect('stack-1', true))
                .compositingFilter(this.feedback.filter('stack-1', true))
                .attributeModifier(this.feedback.control('stack-1', true))
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }
}
