import { STORAGE_KEY_APPEARANCE, STORAGE_KEY_HAND } from '../common/constants';
import { APPEARANCE_LABELS, APPEARANCE_VALUES, HAND_LABELS, HAND_VALUES, DEFAULT_APPEARANCE, DEFAULT_HAND } from '../common/constants';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';
import { SettingsSelection } from '../model/ApplicationState';
import { SettingsChoiceSlider } from './SettingsChoiceSlider';
import { SettingsPreferenceRow } from './SettingsPreferenceRow';

/** V1 偏好绑定桥接到 V2 业务页面；不在组件中创建业务服务或维护第二份持久化状态。 */
@Component
export struct PreferenceSettings {
  @StorageLink(STORAGE_KEY_APPEARANCE) appearance: string = DEFAULT_APPEARANCE;
  @StorageLink(STORAGE_KEY_HAND) hand: string = DEFAULT_HAND;
  @Prop isEnabled: boolean = true;
  save: (changes: SettingsSelection) => Promise<boolean> = async () => false;

  @Builder appearanceControl() {
    SettingsChoiceSlider({
      index: Math.max(0, APPEARANCE_VALUES.indexOf(this.appearance)),
      labels: APPEARANCE_LABELS,
      accessibilityLabel: '应用外观',
      isEnabled: this.isEnabled,
      changed: (index: number): Promise<boolean> => this.save({ appearance: APPEARANCE_VALUES[index] }),
    })
  }

  @Builder handControl() {
    SettingsChoiceSlider({
      index: Math.max(0, HAND_VALUES.indexOf(this.hand)),
      labels: HAND_LABELS,
      accessibilityLabel: '操作模式',
      isEnabled: this.isEnabled,
      changed: (index: number): Promise<boolean> => this.save({ hand: HAND_VALUES[index] }),
    })
  }

  @Builder divider() {
    Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 16, right: 16 })
  }

  build() {
    Column() {
      SettingsPreferenceRow({ label: '应用外观', icon: Icons.light, control: this.appearanceControl.bind(this) })
      this.divider()
      SettingsPreferenceRow({ label: '操作模式', icon: Icons.user, control: this.handControl.bind(this) })
      this.divider()
    }.width('100%')
  }
}
