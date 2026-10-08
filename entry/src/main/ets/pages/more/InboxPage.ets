import { EntryCollection } from '../../component/EntryCollection';
import { AppState } from '../../model/ApplicationState';
import { InboxRoute } from '../../model/CollectedEntry';
import { Theme } from '../../common/Theme';

@ComponentV2
export struct InboxPage {
  @Require @Param state: AppState;
  @Param route: InboxRoute = new InboxRoute();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event backToOwner: () => void = () => {};
  private scroller: Scroller = new Scroller();
  private measured: boolean = false;
  private restoring: boolean = true;
  private restoreTimer: number = -1;
  aboutToAppear(): void { this.route.reconcile(this.state.entries); }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); } }
  @Monitor('route.restoreVersion', 'state.entries')
  private contextChanged(): void { this.route.reconcile(this.state.entries); this.restoreScroll(); }
  private restoreScroll(): void {
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoring = true;
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false }); this.restoring = false;
    }, 0);
  }
  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Blank().height(Theme.detailTop)
        if (this.route.scopeKind !== 'global') { Button('返回归属对象').constraintSize({ minHeight: 48 }).onClick((): void => { this.backToOwner(); }).backgroundColor(Theme.tint).fontColor(Theme.accent) }
        EntryCollection({ state: this.state, route: this.route, open: this.open })
        Blank().height(Theme.contentBottom)
      }.width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.id('inbox-scroll').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto)
      .onAreaChange((_, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreScroll(); } })
      .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offset = this.scroller.currentOffset().yOffset; } })
  }
}
