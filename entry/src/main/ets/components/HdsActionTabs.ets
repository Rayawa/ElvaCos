import { HdsTabs, HdsTabsController, BlurStrategy } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';
import { SystemCapability } from '../services/capability/SystemCapability';

// HdsTabs owns the floating action bar; action clicks never replace the detail content.
@ComponentV2
export struct HdsActionTabs {
  @Param items: ToolbarItem[] = [];
  @Param effects: boolean = true;
  @Param materialLevel: number = 1;
  @Param availableWidth: number = 360;
  @Param busy: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;
  private controller: HdsTabsController = new HdsTabsController();
  @Builder emptyContent() { Blank() }
  private icon(item: ToolbarItem): ResourceStr | TabBarSymbol {
    return item.symbolIcon ? { normal: item.symbolIcon, selected: item.symbolIcon } : item.icon || Icons.add;
  }
  build() {
    HdsTabs({ controller: this.controller, index: 0 }) {
      ForEach(this.items, (item: ToolbarItem, index: number) => {
        TabContent() {
          if (index === 0) { this.content() }
        }.tabBar(new BottomTabBarStyle(this.icon(item), item.value)
          .id('detail-action-' + item.value)
          .labelStyle({ selectedColor: Theme.ink, unselectedColor: Theme.ink })
          .iconStyle({ selectedColor: Theme.ink, unselectedColor: Theme.ink }))
      }, (item: ToolbarItem) => String(item.value))
    }.id('detail-action-tabs').barPosition(BarPosition.End)
      .barWidth(Math.min(Math.max(168, this.items.length * 72), this.availableWidth - 32))
      .scrollable(false).vertical(false).barOverlap(true)
      .blurStrategy(this.effects ? BlurStrategy.ENABLE : BlurStrategy.DISABLE)
      .barFloatingStyle(SystemCapability.tabs(this.effects, this.materialLevel))
      .onContentWillChange((): boolean => false)
      .onTabBarClick((index: number): void => {
        if (!this.busy) { this.items[index]?.action?.(); }
      })
      .width('100%').height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Theme.bg).accessibilityText('当前页面操作栏')
  }
}
