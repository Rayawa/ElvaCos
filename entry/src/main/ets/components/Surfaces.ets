import { PressFeedback } from '../ui/pressFeedback';
import { SystemCapability } from '../ui/SystemCapability';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { curves } from '@kit.ArkUI';
import { vibration } from '../ui/vibration';
import { pressVisualEffect, pressLightFieldFilter } from '../ui/visualEffects';

export type PillTone = 'brand' | 'success' | 'warning' | 'danger' | 'neutral';

/** 可点击卡片：统一圆角、描边阴影、按压缩放、点光源、HDR 按压增强与短振动。 */
@ComponentV2
export struct InteractiveCard {
    @Param label: string = '';
    @Param hint: string = '双击打开详情';
    @Param effects: boolean = true;
    @Param contentPadding: number = 14;
    @Param elevated: boolean = false;
    @Param hero: boolean = false;
    @Param cardRadius: number = 0;
    @Param hasMenu: boolean = false;
    @Event action: () => void = () => {};
    @BuilderParam content: () => void = this.defaultContent;
    @BuilderParam contextMenu: () => void = this.emptyContextMenu;
    @Local pressed: boolean = false;
    @Local menuShown: boolean = false;
    private longPressTriggered: boolean = false;

    @Builder defaultContent() {
        Text(this.label)
    }

    @Builder emptyContextMenu() {
    }

    private effect(): VisualEffect | undefined {
        if (!this.effects || !SystemCapability.effects()) {
            return undefined;
        }
        return pressVisualEffect(this.pressed, true, this.hero ? 7 : 6, 110);
    }

    private resolvedRadius(): number {
        if (this.cardRadius > 0) {
            return this.cardRadius;
        }
        return this.hero ? Theme.heroRadius : Theme.cardRadius;
    }

    build() {
        Column() {
            this.content()
        }.width('100%')
            .padding(this.contentPadding)
            .backgroundColor(Theme.surface)
            .border({ width: this.hero ? 1 : 0.8, color: this.hero ? Theme.divider : Theme.line, radius: this.resolvedRadius() })
            .borderRadius(this.resolvedRadius())
            .shadow(this.hero || this.elevated ?
                { radius: 14, color: Theme.shadow, offsetX: 0, offsetY: 4 } :
                { radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
            .animation({ duration: 130, curve: curves.springMotion(0.35, 0.9) })
            .visualEffect(this.effect())
            .compositingFilter(pressLightFieldFilter(this.effects && this.pressed))
            .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                    this.pressed = true;
                    this.longPressTriggered = false;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressed = false;
                }
            })
            .gesture(
                LongPressGesture({ duration: 350 })
                    .onAction((): void => {
                        if (!this.hasMenu) {
                            return;
                        }
                        this.longPressTriggered = true;
                        this.pressed = false;
                        vibration.lightVibration();
                        this.menuShown = true;
                    })
            )
            .onClick((): void => {
                if (this.longPressTriggered) {
                    this.longPressTriggered = false;
                    return;
                }
                vibration.dotVibration();
                this.action();
            })
            .bindContextMenu(this.menuShown, this.contextMenu, {
                preview: MenuPreviewMode.IMAGE,
                aboutToDisappear: (): void => {
                    this.menuShown = false;
                },
                onDisappear: (): void => {
                    this.menuShown = false;
                },
            })
            .focusable(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(this.label)
            .accessibilityDescription(this.hint)
            .accessibilityLevel('yes')
    }
}

/** 单一分区标题：通过字重与可选图标建立层级，不堆叠副标题。 */
@ComponentV2
export struct SectionHeading {
    @Param title: string = '';
    @Param trailing: string = '';
    @Param icon: Resource | undefined = undefined;

    build() {
        Row({ space: 8 }) {
            if (this.icon) {
                SymbolGlyph(this.icon)
                    .fontSize(17)
                    .fontColor([Theme.accent])
                    .accessibilityLevel('no')
            }
            Text(this.title)
                .fontSize(Theme.sectionTitleSize)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .layoutWeight(1)
            if (this.trailing) {
                Text(this.trailing)
                    .fontSize(12)
                    .fontColor(Theme.muted)
            }
        }.width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ top: 8, bottom: 4 })
            .accessibilityGroup(true)
            .accessibilityText(this.title + (this.trailing ? '，' + this.trailing : ''))
    }
}

/** 空状态卡片：图标徽章居中，仅交互按钮保留按压点光源。 */
@ComponentV2
export struct EmptyState {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Param title: string = '';
    @Param message: string = '';
    @Param button: string = '';
    @Param icon: Resource = Icons.library;
    @Event action: () => void = () => {};

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Column({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(this.icon)
                    .fontSize(22)
                    .fontColor([Theme.accent])
                    .accessibilityLevel('no')
            }.width(48)
                .height(48)
                .borderRadius(Theme.pillRadius)
                .backgroundColor(Theme.tint)
            Text(this.title)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ink)
                .textAlign(TextAlign.Center)
            Text(this.message)
                .fontSize(13)
                .fontColor(Theme.muted)
                .textAlign(TextAlign.Center)
            if (this.button) {
                Button(this.button, { stateEffect: false })
                    .backgroundColor(Theme.brand)
                    .fontColor(Theme.onAccent)
                    .fontSize(14)
                    .borderRadius(Theme.pillRadius)
                    .padding({ left: 20, right: 20 })
                    .constraintSize({ minHeight: 40 })
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.action();
                    })
                    .accessibilityText(this.button)
                    .visualEffect(this.feedback.effect('button-2', false))
                    .compositingFilter(this.feedback.filter('button-2', false))
                    .attributeModifier(this.feedback.control('button-2', false))
            }
        }.width('100%')
            .padding(22)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
    }
}

/** 只读语义状态胶囊：纯色彩区分状态，不挂载按压光场。 */
@ComponentV2
export struct StatusPill {
    @Param label: string = '';
    @Param tone: PillTone = 'brand';
    @Param compact: boolean = false;

    private pillTextColor(): Resource {
        if (this.tone === 'success') {
            return Theme.success;
        }
        if (this.tone === 'warning') {
            return Theme.warning;
        }
        if (this.tone === 'danger') {
            return Theme.danger;
        }
        if (this.tone === 'neutral') {
            return Theme.muted;
        }
        return Theme.accent;
    }

    private backgroundTone(): Resource {
        if (this.tone === 'success') {
            return Theme.successBg;
        }
        if (this.tone === 'warning') {
            return Theme.warningBg;
        }
        if (this.tone === 'danger') {
            return Theme.dangerBg;
        }
        return Theme.tint;
    }

    build() {
        Text(this.label)
            .fontSize(this.compact ? 11 : 12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.pillTextColor())
            .maxLines(1)
            .padding(this.compact ?
                { left: 8, right: 8, top: 3, bottom: 3 } :
                { left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.backgroundTone())
            .borderRadius(Theme.pillRadius)
    }
}

/** 详情页事实行：左标签右取值，替代大段标题 + 说明文字。 */
@ComponentV2
export struct FactRow {
    @Param label: string = '';
    @Param value: string = '';
    @Param copyable: boolean = false;

    build() {
        Row({ space: 12 }) {
            Text(this.label)
                .fontSize(13)
                .fontColor(Theme.muted)
                .width(76)
            if (this.copyable) {
                Text(this.value || '未记录')
                    .fontSize(14)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                    .copyOption(CopyOptions.LocalDevice)
                    .accessibilityDescription('长按复制' + this.label)
            } else {
                Text(this.value || '未记录')
                    .fontSize(14)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
            }
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }
}

@ComponentV2
export struct Field {
    @Param multilineLimit: number = 2000;
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Param label: string = '';
    @Param componentId: string = '';
    @Param error: string = '';
    @Event focused: () => void = () => {};
    @Event area: (value: Area) => void = () => {};
    @Param value: string = '';
    @Param placeholder: string = '';
    @Param multiline: boolean = false;
    @Event change: (value: string) => void = () => {};

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Column({ space: 8 }) {
            Text(this.label)
                .fontSize(13)
                .fontColor(Theme.muted)
            if (this.multiline) {
                TextArea({ text: this.value, placeholder: this.placeholder })
                    .height(104)
                    .maxLength(this.multilineLimit)
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .backgroundColor(Theme.tint)
                    .borderRadius(12)
                    .border({ width: 1, color: this.error ? Theme.danger : Theme.line })
                    .fontColor(Theme.ink)
                    .id(this.componentId)
                    .onFocus((): void => {
                        this.focused();
                    })
                    .onChange((value: string) => this.change(value))
                    .accessibilityText(this.label)
                    .visualEffect(this.feedback.effect('textarea-3'))
                    .compositingFilter(this.feedback.filter('textarea-3'))
                    .attributeModifier(this.feedback.control('textarea-3'))
            } else {
                TextInput({ text: this.value, placeholder: this.placeholder })
                    .constraintSize({ minHeight: 48 })
                    .maxLength(1000)
                    .padding({ left: 12, right: 12 })
                    .backgroundColor(Theme.tint)
                    .borderRadius(12)
                    .border({ width: 1, color: this.error ? Theme.danger : Theme.line })
                    .fontColor(Theme.ink)
                    .id(this.componentId)
                    .onFocus((): void => {
                        this.focused();
                    })
                    .onChange((value: string) => this.change(value))
                    .accessibilityText(this.label)
                    .visualEffect(this.feedback.effect('textinput-4'))
                    .compositingFilter(this.feedback.filter('textinput-4'))
                    .attributeModifier(this.feedback.control('textinput-4'))
            }
            if (this.error) {
                Text(this.error)
                    .fontSize(13)
                    .fontColor(Theme.danger)
                    .accessibilityText(this.label + '，' + this.error)
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
            .onAreaChange((_, value: Area): void => {
                this.area(value);
            })
    }
}
