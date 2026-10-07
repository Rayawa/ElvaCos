import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS } from '../../common/constants';
import { PressFeedback } from '../../common/pressFeedback';
import { MainEntranceSession } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { DashboardSearch } from '../../component/DashboardSearch';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { Asset, PhotoAsset, CosProject } from '../../model/Entities';
import { InteractiveCard, EmptyState, SectionHeading, StatusPill } from '../../component/Surfaces';
import { PhotoGrid } from '../../component/PhotoGrid';
import { vibration } from '../../common/vibration';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';

@ComponentV2
export struct LibraryPage {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Require @Param state: AppState;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param photos: boolean = false;
  @Event selection: (value: boolean) => void = () => {};
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = false;
  @Local query: string = '';
  @Local projectId: string = '';
  @Local animStep: number = 0;
  private enterPlayed: boolean = false;
  private enterTimers: number[] = [];
  aboutToAppear(): void { if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); } }
  private enter(): void {
    if (this.enterPlayed) { return; }
    this.enterPlayed = true;
    if (!this.entranceSession.claim('LibraryPage')) { this.animStep = 2; return; }
    this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 2; }
  private assets(): Asset[] { return this.state.assets.filter((a: Asset) => (a.name + a.location).includes(this.query)); }
  @Builder assetContent(a: Asset) {
    Row({ space: 14 }) {
      Text(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(a.type)])
        .fontSize(13)
        .fontColor(Theme.accent)
        .width(52)
        .height(56)
        .backgroundColor(Theme.tint)
        .textAlign(TextAlign.Center)
        .borderRadius(16)
        .visualEffect(this.feedback.effect('asset-type:' + a.id))
        .compositingFilter(this.feedback.filter('asset-type:' + a.id))
        .attributeModifier(this.feedback.control('asset-type:' + a.id))
      Column({ space: 7 }) { Text(a.name)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.ink); Text(a.location || '未记录存放位置')
        .fontSize(12)
        .fontColor(Theme.muted); StatusPill({ label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(a.status)] }) }.layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      Text('¥' + (a.priceCents / 100).toFixed(2)).fontSize(14).fontColor(Theme.muted)
    }.width('100%')
  }
  @Builder photoFilter() {
    Select(new Array<SelectOption>({ value: '全部计划' })
      .concat(this.state.projects.map((p: CosProject): SelectOption => { return { value: p.name }; })))
      .value(this.state.projects.find((p: CosProject) => p.id === this.projectId)?.name || '全部计划')
      .onSelect((i: number) => { vibration.dotVibration(); this.projectId = i === 0 ? '' : this.state.projects[i - 1].id; })
      .accessibilityText('照片所属计划筛选')
      .visualEffect(this.feedback.effect('select-1'))
      .compositingFilter(this.feedback.filter('select-1'))
      .attributeModifier(this.feedback.control('select-1'))
  }
  build() {
    Column({ space: 12 }) {
      if (this.photos) {
        PhotoGrid({
          entranceStep: this.animStep,
          scroller: this.scroller,
          state: this.state,
          photos: this.state.photos.filter((p: PhotoAsset) => !this.projectId || p.projectId === this.projectId),
          open: this.open,
          topInset: this.topInset,
          bottomInset: this.bottomInset,
          sidePadding: Theme.pagePadding,
          header: (): void => { this.photoFilter(); }
        }).layoutWeight(1)
      } else {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Column({ space: 12 }) {
              Blank().height(this.topInset).width('100%')
              DashboardSearch({
                value: this.query,
                placeholder: '搜索装备 / 存放位置',
                label: '搜索衣柜',
                changed: (v: string): void => { this.query = v; }
              })
              SectionHeading({ title: '我的衣柜', trailing: `${this.assets().length} 件装备` })
            }.
          width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
            Column({ space: 12 }) {
              ForEach(this.assets(), (a: Asset) => { InteractiveCard({
                  label: a.name,
                  effects: this.state.settings.effects,
                  action: () => this.open('asset', a.id),
                  content: (): void => this.assetContent(a)
                }) }, (a: Asset) => a.id)
              if (this.assets().length === 0) { EmptyState({
                  title: this.query ? '没有找到装备' : '让每一件装备有归处',
                  message: this.query ? '换个名称或存放位置试试。' : '记录存放位置、状态和价格，再关联到计划。'
                }) }
            }.
          width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
            Blank().height(this.bottomInset).width('100%')
          }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth })
        }.id('library-scroll').layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%')
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
