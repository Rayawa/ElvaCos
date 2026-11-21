import { STORAGE_KEY_APPEARANCE, STORAGE_KEY_THEME_COLOR, DEFAULT_THEME_COLOR, APPEARANCE_LABELS, APPEARANCE_VALUES, DEFAULT_APPEARANCE } from '../models/constants';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { SettingsSelection } from '../viewmodels/ApplicationState';
import { SettingsChoiceSlider } from '../components/SettingsChoiceSlider';
import { SettingsPreferenceRow } from '../components/SettingsPreferenceRow';
import { ThemeColorPicker } from '../components/ThemeColorPicker';
/** V1 偏好绑定桥接到 V2 业务页面；不在组件中创建业务服务或维护第二份持久化状态。 */

@Component
export struct PreferenceSettings {
    @StorageLink(STORAGE_KEY_APPEARANCE) appearance: string = DEFAULT_APPEARANCE;
    @StorageLink(STORAGE_KEY_THEME_COLOR) themeColor: string = DEFAULT_THEME_COLOR;
    @Prop isEnabled: boolean = true;
    save: (changes: SettingsSelection) => Promise<boolean> = async () => false;
    @LocalBuilder themeControl() {
        ThemeColorPicker({
            paletteId: this.themeColor,
            isEnabled: this.isEnabled,
            changed: (id: string): Promise<boolean> => this.save({ themeColor: id }),
        })
    }

    @LocalBuilder appearanceControl() {
        SettingsChoiceSlider({
            index: Math.max(0, APPEARANCE_VALUES.indexOf(this.appearance)),
            labels: APPEARANCE_LABELS,
            accessibilityLabel: '应用外观',
            isEnabled: this.isEnabled,
            changed: (index: number): Promise<boolean> => this.save({ appearance: APPEARANCE_VALUES[index] }),
        })
    }

    @Builder divider() {
        Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 16, right: 16 })
    }

    build() {
        Column() {
            SettingsPreferenceRow({ label: '主题配色', icon: Icons.theme, control: this.themeControl })
            this.divider()
            SettingsPreferenceRow({ label: '应用外观', icon: Icons.light, control: this.appearanceControl })
        }.width('100%')
    }
}
