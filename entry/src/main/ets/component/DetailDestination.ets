import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { MainEntranceSession, StaggerEntrance } from '../common/motion';

@ComponentV2
export struct DetailDestination {
  @Param titleOptions: HdsNavigationTitleBarOptions = {};
  @Event back: () => void = () => {};
  @Event hidden: () => void = () => {};
  @Event shown: () => void = () => {};
  @BuilderParam content: (entrance: StaggerEntrance) => void = this.emptyContent;
  @Local entrance: StaggerEntrance = new StaggerEntrance();
  @Param entranceSession: MainEntranceSession | undefined = undefined;
  @Param entranceKey: string = '';
  private animateOnShow: boolean = true;
  @Builder emptyContent(entrance: StaggerEntrance) { Blank() }
  aboutToAppear(): void { this.entrance.managed = true; }
  aboutToDisappear(): void { this.releaseEntrance(); }

  private prepareEntrance(): void {
    this.animateOnShow = !this.entranceSession || !this.entranceKey ||
      this.entranceSession.claim(this.entranceKey);
    if (this.animateOnShow) { this.entrance.reset(); }
    else { this.entrance.finish(4); }
  }

  private showEntrance(): void {
    if (this.animateOnShow) { this.entrance.play(this.getUIContext()); }
    else { this.entrance.finish(4); }
  }

  private releaseEntrance(): void {
    if (this.entranceSession && this.entranceKey) { this.entrance.finish(4); }
    else { this.entrance.reset(); }
  }
  // Native chrome floats over the full body. The caller avoids the system status area once.
  private safeTitleOptions(): HdsNavigationTitleBarOptions {
    return { padding: this.titleOptions.padding, style: this.titleOptions.style, content: this.titleOptions.content,
      enableHoverMode: this.titleOptions.enableHoverMode, avoidLayoutSafeArea: this.titleOptions.avoidLayoutSafeArea, enableComponentSafeArea: false };
  }
  build() {
    HdsNavDestination() { this.content(this.entrance) }
      .titleBar(this.safeTitleOptions()).titleMode(HdsNavDestinationTitleMode.MINI)
      .hideTitleBar(false)
      .hideToolBar(true).backgroundColor(Theme.bg)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .onWillShow((): void => { this.prepareEntrance(); })
      .onShown((): void => { this.showEntrance(); this.shown(); })
      .onHidden((): void => { this.releaseEntrance(); this.hidden(); })
      .onBackPressed((): boolean => { this.back(); return true; })
  }
}
