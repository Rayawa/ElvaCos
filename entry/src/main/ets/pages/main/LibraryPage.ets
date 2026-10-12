import { ContextRow } from '../../component/ContextRow';
import { displayName } from '../../common/format';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS } from '../../common/constants';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { DashboardSearch } from '../../component/DashboardSearch';
import { AppState } from '../../model/ApplicationState';
import { WardrobeRoute, wardrobeAssets, wardrobeLocations } from '../../model/Wardrobe';
import { Theme } from '../../common/Theme';
import { Asset, AssetStatus, AssetType } from '../../model/Entities';
import { EmptyState, SectionHeading, StatusPill } from '../../component/Surfaces';

@ComponentV2
export struct LibraryPage {
  @Require @Param state: AppState;
  @Require @Param route: WardrobeRoute;
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = false;
  @Local animStep: number = 0;
  private enterPlayed: boolean = false;
  private enterTimers: number[] = [];
  private measured: boolean = false;
  private restoring: boolean = true;
  private restoreTimer: number = -1;
  aboutToAppear(): void { if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); this.restoreOffset(); } }
  @Monitor('route.restoreVersion')
  restoreChanged(): void { this.restoreOffset(); }
  private enter(): void {
    if (this.enterPlayed) { return; }
    this.enterPlayed = true;
    if (!this.entranceSession.claim('LibraryPage')) { this.animStep = 2; return; }
    this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void {
    cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 2;
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
  }
  private restoreOffset(): void {
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoring = true;
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false });
      if (this.route.anchorId) { try { this.getUIContext().getFocusController().requestFocus('wardrobe-asset:' + this.route.anchorId); } catch (error) {} }
      this.restoring = false;
    }, 0);
  }
  private assets(): Asset[] { return wardrobeAssets(this.state.assets, this.route); }
  private locations(): string[] {
    const values = wardrobeLocations(this.state.assets);
    if (this.route.locationMode === 'named' && !values.includes(this.route.location)) { values.push(this.route.location); }
    return values;
  }
  private locationLabels(): string[] { return ['全部位置', '未记录位置'].concat(this.locations().map((value: string) => '存放位置：' + value)); }
  private locationIndex(): number { return this.route.locationMode === 'all' ? 0 : this.route.locationMode === 'unrecorded' ? 1 : this.locations().indexOf(this.route.location) + 2; }
  @Builder controls() {
    DashboardSearch({ value: this.route.query, placeholder: '搜索装备 / 存放位置', label: '搜索衣柜', changed: (value: string): void => { this.route.query = value; this.route.changed(); } })
    Flex({ wrap: FlexWrap.Wrap }) {
      Select(['全部类型'].concat(ASSET_TYPE_LABELS).map((label: string): SelectOption => { return { value: label }; }))
        .value(this.route.type ? ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.route.type as AssetType)] : '全部类型').constraintSize({ minHeight: 48 })
        .onSelect((index: number): void => { this.route.type = index ? ASSET_TYPES[index - 1] : ''; this.route.changed(); }).accessibilityText('衣柜装备类型筛选').margin({ right: 12, bottom: 8 })
      Select(['全部状态'].concat(ASSET_STATUS_LABELS).map((label: string): SelectOption => { return { value: label }; }))
        .value(this.route.status ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.route.status as AssetStatus)] : '全部状态').constraintSize({ minHeight: 48 })
        .onSelect((index: number): void => { this.route.status = index ? ASSET_STATUSES[index - 1] : ''; this.route.changed(); }).accessibilityText('衣柜装备状态筛选').margin({ right: 12, bottom: 8 })
      Select(this.locationLabels().map((label: string): SelectOption => { return { value: label }; })).value(this.locationLabels()[this.locationIndex()]).constraintSize({ minHeight: 48 })
        .onSelect((index: number): void => { this.route.locationMode = index === 0 ? 'all' : index === 1 ? 'unrecorded' : 'named'; this.route.location = index > 1 ? this.locations()[index - 2] : ''; this.route.changed(); }).accessibilityText('衣柜存放位置筛选').margin({ bottom: 8 })
    }.width('100%')
    if (this.route.filtered) { Button('清除衣柜筛选').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.clear(); }) }
    if (this.route.feedback) { Text(this.route.feedback).fontSize(14).fontColor(Theme.accent) }
    SectionHeading({ title: '我的衣柜', trailing: this.assets().length + ' 件装备' })
  }
  @Builder assetContent(asset: Asset) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text(displayName(asset.name)).fontSize(19).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1)
        StatusPill({ label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] })
      }.width('100%')
      ContextRow({ label: ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(asset.type)], text: asset.location.trim() || '未记录位置' })
      Text('使用计划 ' + this.state.assetUsage(asset.id).projects.length + ' 份').fontSize(14).fontColor(Theme.muted)
      if (asset.status !== AssetStatus.OWNED && this.state.assetUsage(asset.id).activeProjects.length > 0) { Text('影响 ' + this.state.assetUsage(asset.id).activeProjects.length + ' 份进行中计划').fontSize(14).fontColor(Theme.muted) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
      List({ space: 12, scroller: this.scroller }) {
        ListItem() { Column({ space: 12 }) { Blank().height(this.topInset).width('100%'); this.controls() }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0) }
        ForEach(this.assets(), (asset: Asset) => {
          ListItem() {
            Button() { this.assetContent(asset) }.id('wardrobe-asset:' + asset.id).width('100%').constraintSize({ minHeight: 56 }).padding(16).backgroundColor(Theme.surface).borderRadius(12)
              .onClick((): void => { this.route.anchorId = asset.id; this.open('asset', asset.id); }).accessibilityText('打开装备 ' + asset.name)
          }.opacity(this.animStep >= 2 ? 1 : 0)
        }, (asset: Asset) => asset.id)
        if (!this.assets().length) {
          ListItem() { EmptyState({ title: this.route.filtered ? '没有匹配的装备' : '让每一件装备有归处', message: this.route.filtered ? '名称、类型、状态与位置共同限定当前结果。' : '记录位置和真实状态，再复用到计划。', button: this.route.filtered ? '清除筛选' : '添加装备', action: (): void => { if (this.route.filtered) { this.route.clear(); } else { this.add('asset', ''); } } }) }
        }
        ListItem() { Column() { Blank().height(this.bottomInset).width('100%') }.width('100%') }
      }.id('library-scroll').width('100%').height('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding }).scrollBar(BarState.Off).align(Alignment.Top)
        .onAreaChange((_old: Area, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreOffset(); } })
        .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offset = this.scroller.currentOffset().yOffset; } })
        .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
