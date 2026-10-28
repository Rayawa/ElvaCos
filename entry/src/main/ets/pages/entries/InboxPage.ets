import { EntryCollectionView } from '../../components/entries/EntryCollectionView';
import { AppState } from '../../state/ApplicationState';
import { InboxRoute } from '../../models/CollectedEntry';
import { Theme } from '../../ui/theme/Theme';

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
