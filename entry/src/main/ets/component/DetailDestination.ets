import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { StaggerEntrance } from '../common/motion';

@ComponentV2
export struct DetailDestination {
  @Param titleOptions: HdsNavigationTitleBarOptions = {};
  @Event back: () => void = () => {};
  @Event hidden: () => void = () => {};
  @BuilderParam content: (entrance: StaggerEntrance) => void = this.emptyContent;
  @Local entrance: StaggerEntrance = new StaggerEntrance();
  @Builder emptyContent(entrance: StaggerEntrance) { Blank() }
  aboutToAppear(): void { this.entrance.managed = true; }
  aboutToDisappear(): void { this.entrance.reset(); }
  build() {
    HdsNavDestination() { this.content(this.entrance) }
      .titleBar(this.titleOptions).titleMode(HdsNavDestinationTitleMode.MINI)
      .hideToolBar(true).backgroundColor(Theme.bg)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .onWillShow((): void => { this.entrance.reset(); })
      .onShown((): void => { this.entrance.play(this.getUIContext()); })
      .onHidden((): void => { this.entrance.reset(); this.hidden(); })
      .onBackPressed((): boolean => { this.back(); return true; })
  }
}
