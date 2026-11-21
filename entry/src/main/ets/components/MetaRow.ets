import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';

/** 图标与文字紧凑元信息行：替代列表中的 • / ✓ / → 文字符号拼接。 */
@ComponentV2
export struct MetaRow {
    @Param icon: Resource = Icons.event;
    @Param text: string = '';
    @Param color: ResourceColor = Theme.muted;
    @Param iconSize: number = 13;
    @Param fontSize: number = 12;
    @Param maxLines: number = 1;
    @Param fill: boolean = false;

    build() {
        Row({ space: 5 }) {
            SymbolGlyph(this.icon)
                .fontSize(this.iconSize)
                .fontColor([this.color])
                .accessibilityLevel('no')
            Text(this.text)
                .fontSize(this.fontSize)
                .fontColor(this.color)
                .maxLines(this.maxLines)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .flexShrink(1)
        }.width(this.fill ? '100%' : undefined)
            .alignItems(VerticalAlign.Center)
    }
}
