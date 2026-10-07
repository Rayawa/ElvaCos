import { PressFeedback } from '../common/pressFeedback';
import { Theme } from '../common/Theme';

// Dashboard/AppsPage commonHeader search surface; inline editing keeps the native keyboard.
@ComponentV2
export struct DashboardSearch {
  @Param value: string = '';
  @Param placeholder: string = '';
  @Param label: string = '搜索';
  @Event changed: (value: string) => void = () => {};
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  build() {
    Search({ value: this.value, placeholder: this.placeholder })
      .width('100%').height(48).defaultFocus(false)
      .backgroundColor(Theme.tint).border({ width: 1, color: Theme.line })
      .attributeModifier(this.feedback.control('search'))
      .onChange((value: string): void => { this.changed(value); })
      .accessibilityText(this.label)
  }
}
