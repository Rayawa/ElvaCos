import { Theme } from '../ui/Theme';
import { PillTone } from './Surfaces';

/** 只读紧凑信息胶囊：支持横向条目与上下居中指标小框两种布局。 */
@ComponentV2
export struct DetailTag {
    @Param label: string = '';
    @Param value: string = '-';
    @Param icon: Resource | undefined = undefined;
    @Param tone: PillTone = 'neutral';
    @Param centered: boolean = false;

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

    private valueColor(): Resource {
        if (this.tone === 'neutral') {
            return Theme.ink;
        }
        return this.labelColor();
    }

    build() {
        if (this.centered) {
            Column({ space: 4 }) {
                Text(this.value || '-')
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.valueColor())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Center)
                Row({ space: 4 }) {
                    if (this.icon) {
                        SymbolGlyph(this.icon)
                            .fontSize(12)
                            .fontColor([this.labelColor()])
                            .accessibilityLevel('no')
                    }
                    Text(this.label)
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                }.justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
            }.width('100%')
                .constraintSize({ minHeight: 62 })
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                .borderRadius(Theme.slotRadius)
                .backgroundColor(Theme.tint)
                .border({ width: 0.8, color: Theme.line })
                .accessibilityGroup(true)
                .accessibilityText(`${this.label}，${this.value || '未记录'}`)
        } else {
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
}
