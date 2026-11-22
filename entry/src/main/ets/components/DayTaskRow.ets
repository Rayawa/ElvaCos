import { displayName } from '../utils/format';
import { StatusPill } from './Surfaces';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';

/** 任务行：原生勾选框、可读标题、语义状态与可选次级入口。 */
@ComponentV2
export struct DayTaskRow {
    @Param title: string = '';
    @Param subtitle: string = '';
    @Param statusLabel: string = '';
    @Param done: boolean = false;
    @Param interactive: boolean = true;
    @Param secondaryLabel: string = '';
    @Event toggle: () => void = () => {};
    @Event secondary: () => void = () => {};

    build() {
        Row({ space: 6 }) {
            Checkbox()
                .select(this.done)
                .shape(CheckBoxShape.CIRCLE)
                .selectedColor(Theme.brand)
                .width(24)
                .height(24)
                .margin({ left: 6, right: 8 })
                .enabled(this.interactive)
                .onChange((): void => {
                    vibration.dotVibration();
                    this.toggle();
                })
                .accessibilityText((this.done ? '取消完成 ' : '确认完成 ') + this.title)
            Button({ type: ButtonType.Normal, stateEffect: false }) {
                Column({ space: 4 }) {
                    Text(displayName(this.title))
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.done ? Theme.muted : Theme.ink)
                        .decoration({ type: this.done ? TextDecorationType.LineThrough : TextDecorationType.None })
                    if (this.subtitle || this.statusLabel) {
                        Row({ space: 8 }) {
                            if (this.subtitle) {
                                Text(this.subtitle)
                                    .fontSize(12)
                                    .fontColor(Theme.muted)
                                    .maxLines(2)
                                    .layoutWeight(1)
                            }
                            if (this.statusLabel) {
                                StatusPill({
                                    label: this.statusLabel,
                                    tone: this.done ? 'success' : 'brand',
                                    compact: true,
                                })
                            }
                        }.width('100%')
                    }
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
                    .padding({ top: 12, bottom: 12 })
            }.layoutWeight(1)
                .constraintSize({ minHeight: 58 })
                .backgroundColor(Color.Transparent)
                .borderRadius(Theme.slotRadius)
                .enabled(this.interactive)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.toggle();
                })
                .accessibilityText(this.title + (this.done ? '，已完成' : '，待完成'))
            if (this.secondaryLabel) {
                Button(this.secondaryLabel, { type: ButtonType.Normal, stateEffect: false })
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.accent)
                    .padding({ left: 10, right: 10 })
                    .borderRadius(12)
                    .constraintSize({ minHeight: 38, minWidth: 48 })
                    .backgroundColor(Theme.tint)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.secondary();
                    })
                    .accessibilityText(this.secondaryLabel + '，' + this.title)
            }
        }.width('100%')
            .constraintSize({ minHeight: 58 })
    }
}
