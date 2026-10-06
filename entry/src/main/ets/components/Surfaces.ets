import { hdsEffect } from '@kit.UIDesignKit';
import { SystemCapability } from '../services/capability/SystemCapability';
import { Theme } from '../common/Theme';
import { curves } from '@kit.ArkUI';
import { vibration } from '../common/vibration';
import { pressVisualEffect, pressLightFieldFilter } from '../common/visualEffects';
import { contentEnterTransition } from '../common/motion';

/** 可点击卡片：统一按压缩放、点光源、HDR 按压增强与短振动。 */
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
      .onClick((): void => { vibration.dotVibration(); this.action(); }).focusable(true)
      .accessibilityText(this.label).accessibilityDescription(this.hint).accessibilityLevel('yes')
  }
}

/** 紧凑分组标题：只用一行小字，避免大标题 + 小标题的两级堆叠。 */
@ComponentV2
export struct SectionHeading {
  @Param title: string = '';
  @Param trailing: string = '';
  build() {
    Row({ space: 8 }) {
      Text(this.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.muted).layoutWeight(1)
      if (this.trailing) { Text(this.trailing).fontSize(12).fontColor(Theme.muted) }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 6, bottom: 2 })
    .accessibilityGroup(true)
  }
}

@ComponentV2
export struct EmptyState {
  @Param title: string = '';
  @Param message: string = '';
  @Param button: string = '';
  @Event action: () => void = () => {};
  build() {
    Column({ space: 10 }) {
      Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink).textAlign(TextAlign.Center)
      Text(this.message).fontSize(13).fontColor(Theme.muted).textAlign(TextAlign.Center)
      if (this.button) { Button(this.button).backgroundColor(Theme.accent).fontColor(Theme.onAccent).fontSize(14).constraintSize({ minHeight: 40 }).onClick((): void => { vibration.dotVibration(); this.action(); }).accessibilityText(this.button) }
    }.width('100%').padding(20).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
  }
}

@ComponentV2
export struct StatusPill {
  @Param label: string = '';
  build() { Text(this.label).fontSize(12).fontWeight(FontWeight.Medium).fontColor(Theme.accent).padding({ left: 10, right: 10, top: 5, bottom: 5 }).backgroundColor(Theme.tint).borderRadius(12) }
}

/** 详情页事实行：左标签右取值，替代大段标题 + 说明文字。 */
@ComponentV2
export struct FactRow {
  @Param label: string = '';
  @Param value: string = '';
  @Param copyable: boolean = false;
  build() {
    Row({ space: 12 }) {
      Text(this.label).fontSize(13).fontColor(Theme.muted).width(76)
      if (this.copyable) {
        Text(this.value || '未记录').fontSize(14).fontColor(Theme.ink).layoutWeight(1).copyOption(CopyOptions.LocalDevice).accessibilityDescription('长按复制' + this.label)
      } else {
        Text(this.value || '未记录').fontSize(14).fontColor(Theme.ink).layoutWeight(1)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
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
