import { Icons } from '../ui/Icons';
import { Theme } from '../ui/Theme';
import { InteractiveCard } from './Surfaces';

/** 待办入口复用统一卡片反馈；任务状态与路由仍由页面负责。 */
@ComponentV2
export struct TaskLinkCard {
    @Param title: string = '';
    @Param detail: string = '';
    @Param label: string = '';
    @Param hint: string = '';
    @Param effects: boolean = true;
    @Event action: () => void = () => {};

    @Builder body() {
        Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.pending)
                    .fontSize(18)
                    .fontColor([Theme.accent])
                    .accessibilityLevel('no')
            }.width(32)
                .height(32)
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.tint)
            Column({ space: 3 }) {
                Text(this.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.detail) {
                    Text(this.detail)
                        .fontSize(12)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(14)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }

    build() {
        InteractiveCard({
            label: this.label || this.title,
            hint: this.hint,
            effects: this.effects,
            action: (): void => {
                this.action();
            },
            content: (): void => {
                this.body();
            },
        })
    }
}
