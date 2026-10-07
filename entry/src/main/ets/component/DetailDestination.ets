import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { MainEntranceSession, StaggerEntrance } from '../common/motion';

@ComponentV2
export struct DetailDestination {
  @Param titleOptions: HdsNavigationTitleBarOptions = {};
  @Event back: () => void = () => {};
  @Event hidden: () => void = () => {};
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
  build() {
    HdsNavDestination() { this.content(this.entrance) }
      .titleBar(this.titleOptions).titleMode(HdsNavDestinationTitleMode.MINI)
      .hideToolBar(true).backgroundColor(Theme.bg)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .onWillShow((): void => { this.prepareEntrance(); })
      .onShown((): void => { this.showEntrance(); })
      .onHidden((): void => { this.releaseEntrance(); this.hidden(); })
      .onBackPressed((): boolean => { this.back(); return true; })
  }
}
