import { pageTransition } from '../../common/motion';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { Asset, CosProject, ASSET_TYPES, ASSET_TYPE_LABELS, ASSET_STATUSES, ASSET_STATUS_LABELS } from '../../model/Entities';
import { SectionHeading, StatusPill } from '../../components/Surfaces';

@ComponentV2
export struct AssetDetail {
  @Param state: AppState = new AppState();
  @Param asset: Asset = new Asset();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  private projects(): CosProject[] { return this.state.projects.filter((p: CosProject) => this.state.projectAssets(p.id).some((a: Asset) => a.id === this.asset.id)); }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.contentTop).width('100%')
        Text(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.asset.type)]).fontSize(13).fontColor(Theme.accent)
        Text(this.asset.name).fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        StatusPill({ label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.asset.status)] })

        Column({ space: 12 }) {
          Text('存放位置  ' + (this.asset.location || '未记录')).fontColor(Theme.ink)
          Text('品牌 / 店铺  ' + (this.asset.brand || '未记录')).fontColor(Theme.muted)
          Text('尺码  ' + (this.asset.size || '未记录')).fontColor(Theme.muted)
          Text('购买价格  ¥' + (this.asset.priceCents / 100).toFixed(2)).fontColor(Theme.ink)
          if (this.asset.purchaseUrl) { Text(this.asset.purchaseUrl).fontSize(13).fontColor(Theme.accent).copyOption(CopyOptions.LocalDevice).accessibilityDescription('长按复制购买链接') }
          if (this.asset.notes) { Text(this.asset.notes).fontColor(Theme.muted) }
        }.padding(20).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).alignItems(HorizontalAlign.Start)
        SectionHeading({ title: '复用在这些计划', subtitle: this.projects().length + ' 份计划 · 装备只保存一份' })
        ForEach(this.projects(), (p: CosProject) => { Button(p.name + ' ›').width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).constraintSize({ minHeight: 52 }).onClick(() => this.open('project', p.id)) }, (p: CosProject) => p.id)
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
