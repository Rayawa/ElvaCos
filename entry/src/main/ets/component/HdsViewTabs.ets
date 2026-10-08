import { HdsTabs, HdsTabsController, BlurStrategy } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { SystemCapability } from '../common/SystemCapability';
import { HapticService } from '../common/HapticService';

/** Native secondary view navigation. Actions stay in the title menu or within each view. */
@ComponentV2
export struct HdsViewTabs {
  @Param labels: string[] = [];
  @Param icons: Resource[] = [];
  @Param selectedIndex: number = 0;
  @Param componentId: string = 'detail-view-tabs';
  @Param effects: boolean = true;
  @Param materialLevel: number = 1;
  @Param availableWidth: number = 360;
  @Param haptic: boolean = true;
  @Param hapticLevel: number = 1;
  @Event canChange: (index: number) => boolean = () => true;
  @Event changed: (index: number) => void = () => {};
  @BuilderParam content: () => void = this.emptyContent;
  private controller: HdsTabsController = new HdsTabsController();
  @Builder emptyContent() { Blank() }
  build() {
    HdsTabs({ controller: this.controller, index: this.selectedIndex }) {
      ForEach(this.labels, (label: string, index: number) => {
        TabContent() {
          // One editor/scroll container at a time; the route owns each view's return context.
          if (index === this.selectedIndex) { this.content() }
        }.tabBar(new BottomTabBarStyle(this.icons[index], label)
          .id(this.componentId + '-' + index)
          .labelStyle({ selectedColor: Theme.accent, unselectedColor: Theme.muted })
          .iconStyle({ selectedColor: Theme.accent, unselectedColor: Theme.muted }))
      }, (label: string) => label)
    }.id(this.componentId).barPosition(BarPosition.End).barHeight(Theme.mainTabsHeight)
      .barWidth(Math.min(this.labels.length * 76, Math.max(0, this.availableWidth - 32)))
      .scrollable(false).barOverlap(true).animationDuration(0)
      .blurStrategy(this.effects ? BlurStrategy.ENABLE : BlurStrategy.DISABLE)
      .barFloatingStyle(SystemCapability.tabs(this.effects, this.materialLevel))
      .onContentWillChange((_current: number, coming: number): boolean => { return coming === this.selectedIndex || this.canChange(coming); })
      .onChange((index: number): void => {
        if (index === this.selectedIndex) { return; }
        if (this.canChange(index)) { this.changed(index); }
        else { this.controller.changeIndex(this.selectedIndex); }
      })
      .onTabBarClick((): void => { HapticService.confirm(this.haptic, this.hapticLevel); })
      .width('100%').height('100%').backgroundColor(Theme.bg)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
