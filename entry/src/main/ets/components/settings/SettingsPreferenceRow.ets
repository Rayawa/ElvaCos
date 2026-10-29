import { HdsListItemCard, IconSize, PrefixIcon } from '@kit.UIDesignKit';
import { Theme } from '../../ui/theme/Theme';
import { Icons } from '../../ui/icons/Icons';
import { LIST_ITEM_PREFIX_MARGIN, LIST_ITEM_SUFFIX_MARGIN } from '../../config/constants';

@ComponentV2
export struct SettingsPreferenceRow {
    @Param label: string = '';
    @Param icon: Resource = Icons.help;
    @Local contentWidth: number = 0;
    @Local contentHeight: number = 44;
    @BuilderParam control: () => void = this.emptyControl;
    @Builder emptyControl() {
    }

    @Builder rowContent() {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            Text(this.label).fontSize(16).fontColor(Theme.ink).maxLines(2)
                .width(this.contentWidth > 0 && this.contentWidth < 330 ? '100%' : 80)
            Column() {
                this.control()
            }.width(this.contentWidth > 0 && this.contentWidth < 330 ? '100%' : 190)
                .alignItems(HorizontalAlign.Start)
                .margin({ top: this.contentWidth > 0 && this.contentWidth < 330 ? 4 : 0 })
        }.width('100%').padding({ right: 2 }).onAreaChange((_, area: Area): void => {
            this.contentWidth = Number(area.width);
            this.contentHeight = Number(area.height);
        })
    }

    build() {
        HdsListItemCard({
            prefixItem: new PrefixIcon({ iconSize: IconSize.SYSTEM_ICON, iconValue: { image: this.icon } }),
            textItem: { customBuilder: (): void => {
                    this.rowContent();
                }
            },
            cardHeight: Math.max(68, this.contentHeight + 24),
            cardBackgroundColor: Theme.surface,
            cardBorderRadius: 0,
            hoverBorderRadius: 12,
            cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
            cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
            accessibilityOptions: { accessibilityText: this.label },
        })
    }
}
