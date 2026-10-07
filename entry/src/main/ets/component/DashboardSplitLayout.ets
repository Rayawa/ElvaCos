import { Theme } from '../common/Theme';

/** Dashboard HomePage / MyPage 共用的固定概览与独立滚动分栏。 */
@ComponentV2
export struct DashboardSplitLayout {
  @Param scroller: Scroller = new Scroller();
  @Param overviewTop: number = Theme.wideOverviewTop;
  @Param scrollTop: number = Theme.wideScrollTop;
  @Param bottomInset: number = Theme.homeContentBottom;
  @Param scrollSpacing: number = Theme.sectionSpacing;
  @Param layoutId: string = '';
  @Param overviewId: string = '';
  @Param scrollId: string = '';
  @Param overviewLabel: string = '';
  @Param scrollLabel: string = '';
  @BuilderParam overview: () => void = this.empty;
  @BuilderParam content: () => void = this.empty;
  @Builder empty() {}

  build() {
    Row({ space: 16 }) {
      Column() {
        Blank().height(this.overviewTop).width('100%')
        Column() { this.overview() }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      }.id(this.overviewId).layoutWeight(4).height('100%')
        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        .accessibilityGroup(true).accessibilityText(this.overviewLabel)
      Divider().vertical(true).height('100%').color(Theme.divider)
        .accessibilityLevel('no')
      Scroll(this.scroller) {
        Column({ space: this.scrollSpacing }) {
          Blank().height(this.scrollTop).width('100%')
          this.content()
          Blank().height(this.bottomInset).width('100%')
        }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding })
      }.id(this.scrollId).layoutWeight(6).height('100%').scrollBar(BarState.Off)
        .align(Alignment.Top).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .accessibilityText(this.scrollLabel)
    }.id(this.layoutId).width('100%').height('100%')
      .constraintSize({ maxWidth: Theme.contentMaxWidth })
      .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
      .alignItems(VerticalAlign.Top)
  }
}
