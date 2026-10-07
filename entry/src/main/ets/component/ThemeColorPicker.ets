import { DEFAULT_THEME_COLOR } from '../common/constants';
import { THEME_PALETTES, ThemePalette } from '../common/ThemePalettes';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';

/** 五个配色入口，与深浅色模式独立；保存成功后由 StorageLink 回传选中状态。 */
@ComponentV2
export struct ThemeColorPicker {
  @Param paletteId: string = DEFAULT_THEME_COLOR;
  @Param isEnabled: boolean = true;
  @Event changed: (id: string) => Promise<boolean> = async () => false;
  @Local saving: boolean = false;

  private async choose(id: string): Promise<void> {
    if (!this.isEnabled || this.saving || id === this.paletteId) { return; }
    this.saving = true;
    vibration.dotVibration();
    try { await this.changed(id); }
    finally { this.saving = false; }
  }

  build() {
    Row() {
      ForEach(THEME_PALETTES, (palette: ThemePalette) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 4 }) {
            Stack() {
              Column().width(22).height(22).backgroundColor(palette.brand).borderRadius(11)
              if (palette.id === this.paletteId) {
                SymbolGlyph($r('sys.symbol.checkmark')).fontSize(14).fontColor([palette.onAccent])
              }
            }.width(26).height(26)
              .border({ width: palette.id === this.paletteId ? 1 : 0, color: Theme.muted, radius: 13 })
            Text(palette.label).fontSize(12).fontColor(Theme.muted).maxLines(1)
          }
        }.width(34).constraintSize({ minHeight: 52 }).padding(0)
          .backgroundColor(Theme.transparent).borderRadius(12)
          .enabled(this.isEnabled && !this.saving)
          .id('theme-color-' + palette.id)
          .onClick((): void => { this.choose(palette.id); })
          .accessibilityText(palette.label + '色主题')
          .accessibilitySelected(palette.id === this.paletteId)
      }, (palette: ThemePalette) => palette.id)
    }.width(190).justifyContent(FlexAlign.SpaceBetween).accessibilityGroup(false)
  }
}
