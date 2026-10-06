import { curves } from '@kit.ArkUI';
import { Theme } from '../common/Theme';

// Dashboard/AppsPage commonHeader search surface; inline editing keeps the native keyboard.
@ComponentV2
export struct DashboardSearch {
  @Param value: string = '';
  @Param placeholder: string = '';
  @Param label: string = '搜索';
  @Event changed: (value: string) => void = () => {};
  @Local pressed: boolean = false;
  build() {
    Search({ value: this.value, placeholder: this.placeholder })
      .width('100%').height(48).defaultFocus(false)
      .backgroundColor(Theme.tint).border({ width: 1, color: Theme.line })
      .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
      .animation({ duration: 130, curve: curves.springMotion(0.35, 0.9) })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.pressed = true; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressed = false; }
      })
      .onChange((value: string): void => { this.changed(value); })
      .accessibilityText(this.label)
  }
}
