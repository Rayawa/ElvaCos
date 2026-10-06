import { HdsListItemCard, IconSize, PrefixIcon } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';
import { vibration } from '../common/vibration';
import { LIST_ITEM_PREFIX_MARGIN, LIST_ITEM_SUFFIX_MARGIN } from '../common/constants';

/** 设置项里的「标签 + 当前值（+ 可选动作）」一行，与 SettingsPanel 的卡片同一行高与边距。 */
@ComponentV2
export struct SettingsValueRow {
  @Param label: string = '';
  @Param value: string = '';
  @Param hint: string = '';
  @Param icon: Resource = Icons.user;
  @Param actionLabel: string = '';
  @Param isEnabled: boolean = true;
  @Event action: () => void = () => {};

  @Builder rowContent() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(this.label).fontSize(16).fontColor(this.isEnabled ? Theme.ink : Theme.muted).maxLines(1)
        if (this.hint) { Text(this.hint).fontSize(12).fontColor(Theme.muted).maxLines(2) }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.value) {
        Text(this.value).fontSize(14).fontColor(Theme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.actionLabel) {
        Button(this.actionLabel)
          .fontSize(14)
          .fontColor(Theme.accent)
          .backgroundColor(Theme.tint)
          .constraintSize({ minHeight: 36 })
          .padding({ left: 16, right: 16 })
          .enabled(this.isEnabled)
          .onClick((): void => { vibration.dotVibration(); this.action(); })
          .accessibilityText(this.actionLabel + '，' + this.label)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ right: 2 })
  }

  build() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({ iconSize: IconSize.SYSTEM_ICON, iconValue: { image: this.icon } }),
      textItem: { customBuilder: (): void => { this.rowContent(); } },
      onClick: this.actionLabel ? undefined : (): void => { if (this.isEnabled) { vibration.dotVibration(); this.action(); } },
      cardHeight: this.hint ? 72 : 60,
      cardBackgroundColor: Theme.surface,
      cardBorderRadius: 0,
      hoverBorderRadius: 12,
      cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
      cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
      accessibilityOptions: { accessibilityText: this.label + (this.value ? '，' + this.value : '') },
    }).enabled(this.isEnabled).id('settings-value-' + this.label)
  }
}
