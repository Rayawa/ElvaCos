import { HdsListItemCard, IconSize, PrefixIcon } from '@kit.UIDesignKit';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { LIST_ITEM_PREFIX_MARGIN, LIST_ITEM_SUFFIX_MARGIN } from '../models/constants';

@ComponentV2
export struct SettingsPreferenceRow {
    @Param label: string = '';
    @Param icon: Resource = Icons.help;
    @BuilderParam control: () => void = this.emptyControl;
    @Builder emptyControl() {
    }

    @Builder rowContent() {
        Row({ space: 8 }) {
            Text(this.label)
                .fontSize(16)
                .fontColor(Theme.ink)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            Column() {
                this.control()
            }.alignItems(HorizontalAlign.End)
        }.width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ right: 2 })
    }

    build() {
        HdsListItemCard({
            prefixItem: new PrefixIcon({ iconSize: IconSize.SYSTEM_ICON, iconValue: { image: this.icon } }),
            textItem: { customBuilder: (): void => {
                    this.rowContent();
                }
            },
            cardHeight: 68,
            cardBackgroundColor: Theme.surface,
            cardBorderRadius: 0,
            hoverBorderRadius: 12,
            cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
            cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
            accessibilityOptions: { accessibilityText: this.label },
        })
    }
}
