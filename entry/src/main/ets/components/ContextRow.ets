import { Theme } from '../ui/Theme';
import { PillTone, StatusPill } from './Surfaces';
/** Read-only context: a short label and its body remain separate UI elements. */

@ComponentV2
export struct ContextRow {
    @Param label: string = '';
    @Param text: string = '';
    @Param prominent: boolean = false;
    @Param bodyId: string = '';
    @Param tone: PillTone = 'brand';
    build() {
        Row({ space: 8 }) {
            if (this.label) {
                StatusPill({ label: this.label, tone: this.tone }).constraintSize({ maxWidth: '45%' })
            }
            Text(this.text).id(this.bodyId).fontSize(this.prominent ? 16 : 14).fontColor(this.prominent ? Theme.ink : Theme.muted)
                .fontWeight(this.prominent ? FontWeight.Medium : FontWeight.Regular)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }.width('100%').alignItems(VerticalAlign.Center)
    }
}
