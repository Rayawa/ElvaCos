import { pageTransition, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { vibration } from '../../common/vibration';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { Asset, CosProject, ASSET_TYPES, ASSET_TYPE_LABELS, ASSET_STATUSES, ASSET_STATUS_LABELS } from '../../model/Entities';
import { SectionHeading, StatusPill, FactRow } from '../../components/Surfaces';

@ComponentV2
export struct AssetDetail {
  @Param state: AppState = new AppState();
  @Param asset: Asset = new Asset();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local animStep: number = 0;
  private enterTimers: number[] = [];
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 0; }
  private projects(): CosProject[] { return this.state.projects.filter((p: CosProject) => this.state.projectAssets(p.id).some((a: Asset) => a.id === this.asset.id)); }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            Text(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.asset.type)]).fontSize(13).fontColor(Theme.accent)
            Text(this.asset.name).fontSize(20).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            StatusPill({ label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.asset.status)] })
          }.width('100%').alignItems(VerticalAlign.Center)
          Column({ space: 12 }) {
            FactRow({ label: '存放位置', value: this.asset.location })
            FactRow({ label: '品牌店铺', value: this.asset.brand })
            FactRow({ label: '尺码', value: this.asset.size })
            FactRow({ label: '购买价格', value: '¥' + (this.asset.priceCents / 100).toFixed(2) })
            if (this.asset.purchaseUrl) { FactRow({ label: '购买链接', value: this.asset.purchaseUrl, copyable: true }) }
            if (this.asset.notes) { FactRow({ label: '备注', value: this.asset.notes }) }
          }.padding(16).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
        Column({ space: Theme.sectionSpacing }) {
          SectionHeading({ title: '复用在这些计划', trailing: this.projects().length + ' 份' })
          ForEach(this.projects(), (p: CosProject) => {
            Button() {
              Row({ space: 8 }) {
                Text(p.name).fontSize(16).fontColor(Theme.accent).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                Text('›').fontColor(Theme.muted).accessibilityLevel('no')
              }.width('100%').padding(16)
            }
            .width('100%').backgroundColor(Theme.tint).constraintSize({ minHeight: 52 })
            .onClick((): void => { vibration.dotVibration(); this.open('project', p.id); })
            .accessibilityText('打开计划 ' + p.name)
          }, (p: CosProject) => p.id)
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
        Blank().height(Theme.contentBottom).width('100%')
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
