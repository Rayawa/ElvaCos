import { displayName } from '../common/format';
import { StatusPill } from './Surfaces';
import { Theme } from '../common/Theme';

/** A task stays a task: native checkbox, readable label, and one optional contextual action. */
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
    Row({ space: 4 }) {
      Checkbox().select(this.done).width(24).height(24).margin({ left: 8, right: 10 })
        .enabled(this.interactive).onChange((): void => { this.toggle(); })
        .accessibilityText((this.done ? '取消完成 ' : '确认完成 ') + this.title)
      Button() {
        Column({ space: 5 }) {
          Text(displayName(this.title)).fontSize(17).fontColor(this.done ? Theme.muted : Theme.ink)
            .decoration({ type: this.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          if (this.subtitle || this.statusLabel) {
            Row({ space: 8 }) {
              if (this.subtitle) { Text(this.subtitle).fontSize(13).fontColor(Theme.muted).maxLines(2).layoutWeight(1) }
              if (this.statusLabel) { StatusPill({ label: this.statusLabel }) }
            }.width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 14, bottom: 14 })
      }.type(ButtonType.Normal).layoutWeight(1).constraintSize({ minHeight: 64 }).backgroundColor(Color.Transparent)
        .enabled(this.interactive).onClick((): void => { this.toggle(); }).accessibilityText(this.title + (this.done ? '，已完成' : '，待完成'))
      if (this.secondaryLabel) {
        Button(this.secondaryLabel).type(ButtonType.Normal).fontSize(14).fontColor(Theme.accent)
          .constraintSize({ minHeight: 64, minWidth: 48 }).backgroundColor(Color.Transparent)
          .onClick((): void => { this.secondary(); }).accessibilityText(this.secondaryLabel + '，' + this.title)
      }
    }.width('100%').constraintSize({ minHeight: 64 })
  }
}
