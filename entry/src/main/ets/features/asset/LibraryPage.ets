import { DashboardSearch } from '../../components/DashboardSearch';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { Asset, PhotoAsset, ASSET_TYPES, ASSET_TYPE_LABELS, ASSET_STATUSES, ASSET_STATUS_LABELS, CosProject } from '../../model/Entities';
import { InteractiveCard, EmptyState, SectionHeading, StatusPill } from '../../components/Surfaces';
import { PhotoGrid } from '../photo/PhotoGrid';

@ComponentV2
export struct LibraryPage {
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param state: AppState = new AppState();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param photos: boolean = false;
  @Event selection: (value: boolean) => void = () => {};
  @Local query: string = '';
  @Local projectId: string = '';
  @Builder assetContent(a: Asset) {
    Row({ space: 14 }) {
      Text(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(a.type)]).fontSize(13).fontColor(Theme.accent).width(52).height(56).backgroundColor(Theme.tint).textAlign(TextAlign.Center).borderRadius(16)
      Column({ space: 7 }) { Text(a.name).fontSize(19).fontWeight(FontWeight.Medium).fontColor(Theme.ink); Text(a.location || '未记录存放位置').fontSize(12).fontColor(Theme.muted); StatusPill({ label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(a.status)] }) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('¥' + (a.priceCents / 100).toFixed(2)).fontSize(14).fontColor(Theme.muted)
    }.width('100%')
  }
  @Builder photoFilter() {
    Select(new Array<SelectOption>({ value: '全部计划' }).concat(this.state.projects.map((p: CosProject): SelectOption => { return { value: p.name }; }))).value(this.state.projects.find((p: CosProject) => p.id === this.projectId)?.name || '全部计划').onSelect((i: number) => { this.projectId = i === 0 ? '' : this.state.projects[i - 1].id; }).accessibilityText('照片所属计划筛选')
  }
  build() {
    Column({ space: 12 }) {
      if (this.photos) {
        PhotoGrid({ scroller: this.scroller, state: this.state, photos: this.state.photos.filter((p: PhotoAsset) => !this.projectId || p.projectId === this.projectId), open: this.open, topInset: this.topInset, bottomInset: this.bottomInset, sidePadding: Theme.pagePadding, header: (): void => { this.photoFilter(); } }).layoutWeight(1)
      } else {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
          Blank().height(this.topInset).width('100%')
        DashboardSearch({ value: this.query, placeholder: '搜索装备 / 存放位置', label: '搜索衣柜', changed: (v: string): void => { this.query = v; } })
            SectionHeading({ title: '我的衣柜', subtitle: '服装、假发与道具，可以在多份计划复用' })
            ForEach(this.state.assets.filter((a: Asset) => (a.name + a.location).includes(this.query)), (a: Asset) => { InteractiveCard({ label: a.name, effects: this.state.settings.effects, action: () => this.open('asset', a.id), content: (): void => this.assetContent(a) }) }, (a: Asset) => a.id)
            if (this.state.assets.filter((a: Asset) => (a.name + a.location).includes(this.query)).length === 0) { EmptyState({ title: this.query ? '没有找到装备' : '让每一件装备有归处', message: this.query ? '换个名称或存放位置试试。' : '记录存放位置、状态和价格，再关联到计划。' }) }
          }.padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: this.bottomInset }).width('100%')
        }.id('library-scroll').layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%')
  }
}
