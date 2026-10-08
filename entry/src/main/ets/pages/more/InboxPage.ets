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
  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Blank().height(Theme.detailTop)
        if (this.route.scopeKind !== 'global') { Button('返回归属对象').onClick((): void => { this.backToOwner(); }).backgroundColor(Theme.tint).fontColor(Theme.accent) }
        EntryCollection({ state: this.state, scopeKind: this.route.scopeKind, scopeId: this.route.scopeId, initialKind: this.route.kind, untriagedOnly: this.route.untriagedOnly, open: this.open })
        Blank().height(Theme.contentBottom)
      }.width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto)
  }
}
