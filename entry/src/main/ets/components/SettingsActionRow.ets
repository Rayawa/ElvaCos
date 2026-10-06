import { TextModifier } from '@kit.ArkUI';
import { HdsListItemCard, IconSize, PrefixIcon, SuffixCustomBuilder } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';

// Dashboard/MyPage MoreRow, with business label/icon/action passed as V2 inputs.
@ComponentV2
export struct SettingsActionRow {
  @Param label: string = '';
  @Param icon: Resource = $r('sys.media.ohos_ic_public_more');
  @Param isEnabled: boolean = true;
  @Param danger: boolean = false;
  @Event action: () => void = () => {};
  @Builder rightSuffix() {
    Image($r('sys.media.chevron_right_titlebar')).width(20).height(20).objectFit(ImageFit.Contain).fillColor(Theme.muted).accessibilityText('进入')
  }
  build() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({ iconSize: IconSize.SYSTEM_ICON, iconValue: { image: this.icon } }),
      textItem: { primaryText: { text: this.label, modifier: new TextModifier().fontSize(16).fontColor(this.danger ? Theme.danger : Theme.ink) } },
      suffixItem: new SuffixCustomBuilder(() => { this.rightSuffix(); }),
      onClick: () => { if (this.isEnabled) { vibration.dotVibration(); this.action(); } },
      cardHeight: 54,
      cardBackgroundColor: Theme.surface,
      cardBorderRadius: 0,
      hoverBorderRadius: 12,
      cardPrefixMargin: 8,
      cardSuffixMargin: 8,
      accessibilityOptions: { accessibilityText: this.label },
    }).enabled(this.isEnabled).id('settings-action-' + this.label)
  }
}
