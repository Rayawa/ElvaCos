import { PressFeedback } from '../common/pressFeedback';
import { Theme } from '../common/Theme';

// Dashboard/AppsPage commonHeader search surface; inline editing keeps the native keyboard.
@ComponentV2
export struct DashboardSearch {
  @Param value: string = '';
  @Param placeholder: string = '';
  @Param label: string = '搜索';
  @Param componentId: string = 'dashboard-search';
  @Event changed: (value: string) => void = () => {};
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  build() {
    Search({ value: this.value, placeholder: this.placeholder })
      .id(this.componentId)
      .width('100%').height(48).defaultFocus(false)
      .backgroundColor(Theme.tint).border({ width: 1, color: Theme.line })
      .visualEffect(this.feedback.effect('search'))
      .compositingFilter(this.feedback.filter('search'))
      .attributeModifier(this.feedback.control('search'))
      .onChange((value: string): void => { this.changed(value); })
      .accessibilityText(this.label)
  }
}
