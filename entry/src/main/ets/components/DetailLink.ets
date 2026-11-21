import { PressFeedback } from '../ui/pressFeedback';
import { vibration } from '../ui/vibration';
import { displayName } from '../utils/format';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';

/** 详情次级导航行：符号徽章、单主标题与统一按压光效。 */
@ComponentV2
export struct DetailLink {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Param title: string = '';
    @Param subtitle: string = '';
    @Param value: string = '';
    @Param icon: Resource | undefined = undefined;
    @Param componentId: string = '';
    @Param interactive: boolean = true;
    @Param destructive: boolean = false;
    @Event action: () => void = () => {};

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
            Row({ space: 12 }) {
                if (this.icon) {
                    Stack({ alignContent: Alignment.Center }) {
                        SymbolGlyph(this.icon)
                            .fontSize(17)
                            .fontColor([this.destructive ? Theme.danger : Theme.accent])
                            .accessibilityLevel('no')
                    }.width(34)
                        .height(34)
                        .borderRadius(Theme.controlRadius)
                        .backgroundColor(this.destructive ? Theme.dangerBg : Theme.tint)
                }
                Column({ space: 2 }) {
                    Text(displayName(this.title))
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.destructive ? Theme.danger : Theme.ink)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.subtitle) {
                        Text(displayName(this.subtitle))
                            .fontSize(12)
                            .fontColor(Theme.muted)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                }.alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                if (this.value) {
                    Text(this.value)
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                }
                SymbolGlyph(Icons.chevronRightSymbol)
                    .fontSize(14)
                    .fontColor([Theme.muted])
                    .accessibilityLevel('no')
            }.width('100%')
                .padding({ top: 12, bottom: 12, left: 6, right: 6 })
        }.id(this.componentId)
            .width('100%')
            .constraintSize({ minHeight: 56 })
            .backgroundColor(Color.Transparent)
            .borderRadius(12)
            .enabled(this.interactive)
            .onClick((): void => {
                vibration.dotVibration();
                this.action();
            })
            .visualEffect(this.feedback.effect('link'))
            .compositingFilter(this.feedback.filter('link'))
            .attributeModifier(this.feedback.control('link'))
            .accessibilityText(this.title + (this.subtitle ? '，' + this.subtitle : '') + (this.value ? '，' + this.value : ''))
    }
}
