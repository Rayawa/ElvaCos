import { hdsEffect } from '@kit.UIDesignKit';
import { SystemCapability } from '../services/capability/SystemCapability';
import { Theme } from '../common/Theme';
import { curves } from '@kit.ArkUI';
import { pressVisualEffect, pressLightFieldFilter } from '../common/visualEffects';
import { contentEnterTransition } from '../common/motion';

@ComponentV2
export struct InteractiveCard {
  @Param label: string = '';
  @Param hint: string = '双击打开详情';
  @Param hero: boolean = false;
  @Param effects: boolean = true;
  @Param contentPadding: number = 14;
  @Event action: () => void = () => {};
  @BuilderParam content: () => void = this.defaultContent;
  @Local pressed: boolean = false;
  @Builder defaultContent() { Text(this.label) }
  private effect(): VisualEffect | undefined {
    if (!this.effects || !SystemCapability.effects()) { return undefined; }
    const light = pressVisualEffect(this.pressed, this.hero ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.BORDER);
    return light;
  }
  build() {
    Column() { this.content() }
      .width('100%').padding(this.contentPadding).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
      .border({ width: 1, color: Theme.line }).shadow({ radius: 12, color: Theme.shadow, offsetY: 3 })
      .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
      .animation({ duration: 130, curve: curves.springMotion(0.35, 0.9) })
      .visualEffect(this.effect())
      .compositingFilter(pressLightFieldFilter(this.effects && this.pressed))
      .transition(contentEnterTransition())
      .onTouch((event: TouchEvent) => { if (event.type === TouchType.Down) { this.pressed = true; } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressed = false; } })
      .onClick(() => this.action()).focusable(true)
      .accessibilityText(this.label).accessibilityDescription(this.hint).accessibilityLevel('yes')
  }
}
@ComponentV2
export struct SectionHeading {
  @Param title: string = '';
  @Param subtitle: string = '';
  build() {
    Column({ space: 5 }) {
      Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
      if (this.subtitle) { Text(this.subtitle).fontSize(13).fontColor(Theme.muted) }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8, bottom: 8 })
  }
}
@ComponentV2
export struct EmptyState {
  @Param title: string = '';
  @Param message: string = '';
  @Param button: string = '';
  @Event action: () => void = () => {};
  build() {
    Column({ space: 8 }) {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
      Text(this.message).fontSize(13).fontColor(Theme.muted).textAlign(TextAlign.Center)
      if (this.button) { Button(this.button).backgroundColor(Theme.accent).fontColor(Theme.onAccent).fontSize(14).constraintSize({ minHeight: 40 }).onClick(() => this.action()).accessibilityText(this.button) }
    }.width('100%').padding(24).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
  }
}
@ComponentV2
export struct StatusPill {
  @Param label: string = '';
  build() { Text(this.label).fontSize(12).fontWeight(FontWeight.Medium).fontColor(Theme.accent).padding({ left: 10, right: 10, top: 5, bottom: 5 }).backgroundColor(Theme.tint).borderRadius(12) }
}
@ComponentV2
export struct Field {
  @Param label: string = '';
  @Param value: string = '';
  @Param placeholder: string = '';
  @Param multiline: boolean = false;
  @Event change: (value: string) => void = () => {};
  build() {
    Column({ space: 8 }) {
      Text(this.label).fontSize(13).fontColor(Theme.muted)
      if (this.multiline) {
        TextArea({ text: this.value, placeholder: this.placeholder }).height(100).maxLength(2000).backgroundColor(Theme.bg).fontColor(Theme.ink).onChange((value: string) => this.change(value)).accessibilityText(this.label)
      } else {
        TextInput({ text: this.value, placeholder: this.placeholder }).constraintSize({ minHeight: 48 }).maxLength(1000).backgroundColor(Theme.bg).fontColor(Theme.ink).onChange((value: string) => this.change(value)).accessibilityText(this.label)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
