import { AppState } from '../model/ApplicationState';
import { InboxRoute } from '../model/CollectedEntry';
import { Theme } from '../common/Theme';
import { EntryCollection } from './EntryCollection';

// The same capture/editor and scroll context serve the inbox, owner pages and owner sheets.
@ComponentV2
export struct EntryCollectionView {
  @Require @Param state: AppState;
  @Require @Param route: InboxRoute;
  @Param componentId: string = 'inbox-scroll';
  @Param topInset: number = 0;
  @Param bottomInset: number = 16;
  @Param horizontalPadding: number = 0;
  @Param showBackToOwner: boolean = false;
  @Param active: boolean = true;
  @Param restoreVersion: number = 0;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event backToOwner: () => void = () => {};
  private scroller: Scroller = new Scroller();
  private measured: boolean = false;
  private restoring: boolean = true;
  private restoreTimer: number = -1;
  aboutToAppear(): void { this.route.reconcile(this.state.entries); this.restoreScroll(); }
  aboutToDisappear(): void { this.cancelRestore(); }
  private cancelRestore(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; } }
  @Monitor('route.restoreVersion', 'state.entries', 'active', 'restoreVersion')
  private contextChanged(): void {
    this.route.reconcile(this.state.entries); this.cancelRestore(); this.restoring = true; this.restoreScroll();
  }
  private restoreScroll(): void {
    if (!this.active || !this.measured) { return; }
    this.cancelRestore(); this.restoring = true;
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1;
      if (!this.active) { return; }
      this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false }); this.restoring = false;
    }, 0);
  }
  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        if (this.topInset > 0) { Blank().height(this.topInset) }
        if (this.showBackToOwner) { Button('返回归属对象').constraintSize({ minHeight: 48 }).onClick((): void => { this.backToOwner(); }).backgroundColor(Theme.tint).fontColor(Theme.accent) }
        EntryCollection({ state: this.state, route: this.route, open: this.open })
        Blank().height(this.bottomInset)
      }.width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).alignItems(HorizontalAlign.Start)
        .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    }.id(this.componentId).width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto)
      .onAreaChange((_, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreScroll(); } })
      .onDidScroll((): void => { if (this.active && this.measured && !this.restoring) { this.route.offset = this.scroller.currentOffset().yOffset; } })
  }
}
