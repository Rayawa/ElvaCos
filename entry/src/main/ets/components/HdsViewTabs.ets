import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { Theme } from '../ui/Theme';
import { CompatibleTabsStyle, LegacyTabsBarStyle } from '../ui/SystemCapability';
import { SUPPORTS_API_23 } from '../ui/platformCompatibility';
import { HapticService } from '../ui/HapticService';
import { Icons } from '../ui/Icons';
import { contentEnterTransition } from '../ui/motion';
/** Native secondary view navigation. Actions stay in the title menu or within each view. */

@ComponentV2
export struct HdsViewTabs {
    @Param labels: string[] = [];
    @Param icons: Resource[] = [];
    @Param selectedIndex: number = 0;
    @Local activeIndex: number = 0;
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
    aboutToAppear(): void {
        this.activeIndex = this.selectedIndex;
    }

    @Monitor('selectedIndex')
    private selectionChanged(): void {
        this.activeIndex = this.selectedIndex;
    }
    @Builder emptyContent() {
        Blank()
    }

    build() {
        HdsTabs({ controller: this.controller, index: this.activeIndex }) {
            ForEach(this.labels, (label: string, index: number) => {
                TabContent() {
                    // The native bar floats above the immersive content. Routes retain each view's scroll context.
                    if (index === this.activeIndex) {
                        Column() {
                            this.content()
                        }.width('100%').height('100%').transition(contentEnterTransition())
                    }
                }.tabBar(Icons.tabBar(this.icons[index], label, this.componentId + '-' + index))
            }, (label: string) => label)
        }.id(this.componentId).barPosition(BarPosition.End).barHeight(Theme.mainTabsHeight)
            .barWidth(Math.min(this.labels.length * 76, Math.max(0, this.availableWidth - 32)))
            .scrollable(false).barOverlap(true).animationDuration(0)
            .attributeModifier(SUPPORTS_API_23 ? new CompatibleTabsStyle(this.effects, this.materialLevel, 1) : new LegacyTabsBarStyle())
            .onContentWillChange((_current: number, coming: number): boolean => {
                return coming === this.activeIndex || this.canChange(coming);
            })
            .onChange((index: number): void => {
                if (index === this.activeIndex) {
                    return;
                }
                if (this.canChange(index)) {
                    this.activeIndex = index;
                    this.changed(index);
                } else {
                    this.controller.changeIndex(this.activeIndex);
                }
            })
            .onTabBarClick((): void => {
                HapticService.confirm(this.haptic, this.hapticLevel);
            })
            .width('100%').height('100%').backgroundColor(Theme.bg)
            .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    }
}
