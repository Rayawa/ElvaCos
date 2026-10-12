import { EntryCollectionView } from '../../component/EntryCollectionView';
import { AppState } from '../../model/ApplicationState';
import { InboxRoute } from '../../model/CollectedEntry';
import { Theme } from '../../common/Theme';

@ComponentV2
export struct InboxPage {
  @Require @Param state: AppState;
  @Param route: InboxRoute = new InboxRoute();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event backToOwner: () => void = () => {};
  build() {
    EntryCollectionView({ state: this.state, route: this.route, topInset: Theme.detailTop, bottomInset: Theme.detailBottom,
      horizontalPadding: Theme.pagePadding, showBackToOwner: this.route.scopeKind !== 'global', open: this.open, backToOwner: this.backToOwner })
  }
}
