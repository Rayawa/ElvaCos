import { Theme } from '../ui/Theme';
import { PillTone } from './Surfaces';

/** 只读紧凑信息胶囊：用于 2 列网格展示实体的简短字段。 */
@ComponentV2
export struct DetailTag {
    @Param label: string = '';
    @Param value: string = '-';
    @Param icon: Resource | undefined = undefined;
    @Param tone: PillTone = 'neutral';

    private labelColor(): Resource {
        if (this.tone === 'success') {
            return Theme.success;
        }
        if (this.tone === 'warning') {
            return Theme.warning;
        }
        if (this.tone === 'danger') {
            return Theme.danger;
        }
        if (this.tone === 'brand') {
            return Theme.accent;
        }
        return Theme.muted;
    }

    build() {
        Row({ space: 6 }) {
            if (this.icon) {
                SymbolGlyph(this.icon)
                    .fontSize(13)
                    .fontColor([this.labelColor()])
                    .accessibilityLevel('no')
            }
            Text(this.label)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.labelColor())
                .flexShrink(0)
            Scroll() {
                Row() {
                    Text(this.value || '-')
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.ink)
                        .maxLines(1)
                        .textAlign(TextAlign.Start)
                }.constraintSize({ minWidth: '100%' })
                    .justifyContent(FlexAlign.Start)
            }.layoutWeight(1)
                .height(20)
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.None)
        }.alignItems(VerticalAlign.Center)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .width('100%')
            .height(36)
            .borderRadius(Theme.slotRadius)
            .backgroundColor(Theme.tint)
            .border({ width: 0.8, color: Theme.line })
            .accessibilityGroup(true)
            .accessibilityText(`${this.label}，${this.value || '未记录'}`)
    }
}
