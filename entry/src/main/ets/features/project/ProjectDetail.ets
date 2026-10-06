import { pageTransition } from '../../common/motion';
import { confirm } from '../../common/Confirm';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { Asset, AssetStatus, ChecklistItem, CosProject, CosEvent, PROJECT_LABELS, PROJECT_STATUSES, ASSET_STATUSES, ASSET_STATUS_LABELS } from '../../model/Entities';
import { ProjectRoute } from '../../model/ProjectRoute';
import { SectionHeading, StatusPill, EmptyState } from '../../components/Surfaces';
import { checklistProgress, projectProgress, planDate } from '../../model/Rules';

@ComponentV2
export struct ProjectDetail {
  @Param state: AppState = new AppState();
  @Param project: CosProject = new CosProject();
  @Param route: ProjectRoute = new ProjectRoute('');
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  private items(): ChecklistItem[] { return this.state.checklist.filter((c: ChecklistItem) => c.projectId === this.project.id).sort((a: ChecklistItem, b: ChecklistItem) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id)); }
  private equipment(): Asset[] { return this.state.projectAssets(this.project.id).sort((a: Asset, b: Asset) => Number(a.status === AssetStatus.OWNED) - Number(b.status === AssetStatus.OWNED) || a.name.localeCompare(b.name)); }
  private linked(asset: Asset): boolean { return this.state.projectAssets(this.project.id).some((a: Asset) => a.id === asset.id); }
  private location(item: ChecklistItem): string { return this.state.assets.find((a: Asset) => a.id === item.assetId)?.location || (item.assetId ? '存放位置待补充' : '随身物品'); }
  private async unlink(asset: Asset): Promise<void> {
    if (await confirm(this.getUIContext(), '解除装备关联？', '本计划中对应的打包项也会移除，衣柜中的装备会保留。', '解除关联')) { await this.state.unlinkAsset(this.project.id, asset.id); }
  }
  @Builder linkSheet() {
    Column({ space: 14 }) {
      SectionHeading({ title: '从衣柜添加', subtitle: '已有装备可以在多个计划复用' })
      List({ space: 8 }) {
        ForEach(this.state.assets, (asset: Asset) => {
          ListItem() {
            Button() {
              Row() {
                Column({ space: 5 }) { Text(asset.name).fontColor(Theme.ink); Text(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] + ' · ' + (asset.location || '位置待补充')).fontSize(12).fontColor(Theme.muted) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(this.linked(asset) ? '已添加' : '＋ 添加').fontColor(Theme.accent)
              }.padding(16).width('100%')
            }.width('100%').backgroundColor(Theme.bg).enabled(!this.state.busy && !this.linked(asset)).onClick(() => this.state.linkAsset(this.project.id, asset)).accessibilityText('关联 ' + asset.name)
          }
        }, (asset: Asset) => asset.id)
      }.layoutWeight(1).width('100%')
      Button('＋ 新装备').width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick(() => { this.route.linking = false; this.edit('asset', '', this.project.id); })
      Button('完成').width('100%').backgroundColor(Theme.accent).fontColor(Theme.onAccent).onClick(() => { this.route.linking = false; })
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder checkButton(item: ChecklistItem) {
    Button(item.done ? '✓ 已装包' : '装包').constraintSize({ minWidth: 88, minHeight: this.route.outing ? 64 : 48 }).backgroundColor(item.done ? Theme.tint : Theme.accent).fontColor(item.done ? Theme.accent : Theme.onAccent).enabled(!this.state.busy)
      .onClick(() => this.state.toggleChecklist(item)).accessibilityText(item.label + (item.done ? '，已装包，点击取消' : '，点击确认装包'))
  }
  @Builder preparation() {
    StatusPill({ label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] })
    if (planDate(this.project, this.state.events)) { Text('计划日期  ' + planDate(this.project, this.state.events)).fontSize(14).fontColor(Theme.muted) }
    if (this.project.eventId) { Button('漫展 · ' + (this.state.events.find((e: CosEvent) => e.id === this.project.eventId)?.name || '')).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => this.open('event', this.project.eventId)) }
    Column({ space: 12 }) {
      Row() { Text('装备可用率').fontSize(16).fontColor(Theme.ink).layoutWeight(1); Text(this.state.progress(this.project.id) + '%').fontSize(28).fontColor(Theme.accent) }.width('100%')
      Progress({ value: this.state.progress(this.project.id), total: 100, type: ProgressType.Linear }).width('100%').color(Theme.accent).backgroundColor(Theme.tint)
      Text(`${projectProgress(this.project.id, this.state.links, this.state.assets).ready} / ${this.state.projectAssets(this.project.id).length} 件装备可用 · 打包确认单独记录`).fontSize(12).fontColor(Theme.muted)
      Text(this.state.projectAssets(this.project.id).length === 0 ? '下一步：添加本次需要的装备。' : this.state.progress(this.project.id) < 100 ? '下一步：检查下方未到货、维修或借出的装备。' : '装备已可用，出发前切换「打包」逐件确认。').fontSize(14).fontColor(Theme.accent)
    }.alignItems(HorizontalAlign.Start).padding(20).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    SectionHeading({ title: '本次装备' })
    ForEach(this.equipment(), (asset: Asset) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) { Text(asset.name).fontSize(16).fontColor(Theme.ink); Text(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] + ' · ' + (asset.location || '存放位置待补充')).fontSize(12).fontColor(Theme.muted) }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick(() => this.open('asset', asset.id))
        Button('移除').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick(() => this.unlink(asset)).accessibilityText('解除 ' + asset.name + ' 的计划关联')
      }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(18)
    }, (asset: Asset) => asset.id)
    if (this.state.projectAssets(this.project.id).length === 0) { EmptyState({ title: '这次需要带什么？', message: '添加新装备，或从衣柜复用。添加后会自动进入打包清单。', button: '＋ 添加装备', action: () => this.edit('asset', '', this.project.id) }) }
    if (this.project.notes) { SectionHeading({ title: '备注' }); Text(this.project.notes).fontSize(14).fontColor(Theme.muted) }
    Text(`预计预算 ¥${(this.project.budgetCents / 100).toFixed(2)} · 装备记录金额 ¥${(this.state.projectAssets(this.project.id).reduce((sum: number, a: Asset) => sum + a.priceCents, 0) / 100).toFixed(2)}`).fontSize(12).fontColor(Theme.muted)
  }
  @Builder packing() {
    SectionHeading({ title: '打包清单', subtitle: `${this.items().filter((c: ChecklistItem) => c.done).length} / ${this.items().length} 项已装包 · 未完成优先` })
    if (this.route.outing) { Text('出门模式 · ' + (this.state.hand() === 'left' ? '左手操作' : this.state.hand() === 'right' ? '右手操作' : '智感握持')).fontColor(Theme.accent).fontSize(14) }
    Progress({ value: checklistProgress(this.items()), total: 100, type: ProgressType.Linear }).color(Theme.accent).backgroundColor(Theme.tint).width('100%')
    if (this.items().length === 0) { EmptyState({ title: '清单还空着', message: '添加装备会自动生成打包项，也可以添加手机、门票等随身物品。', button: '添加常用物品', action: () => this.state.generateChecklist(this.project.id) }) }
    ForEach(this.items(), (item: ChecklistItem) => {
      Row({ space: 12 }) {
        if (this.state.hand() === 'left') { this.checkButton(item) }
        Column({ space: 6 }) {
          Text(item.label).fontSize(this.route.outing ? 20 : 16).fontColor(item.done ? Theme.muted : Theme.ink).decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          Text(this.location(item)).fontSize(12).fontColor(Theme.muted)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (!this.route.outing) { Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick(() => this.remove('checklist', item.id)).accessibilityText('删除清单项 ' + item.label) }
        if (this.state.hand() !== 'left') { this.checkButton(item) }
      }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(20)
    }, (item: ChecklistItem) => item.id)
  }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.contentTop).width('100%')
        Text(this.project.name).fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        if (this.route.section === 1) { this.packing() } else { this.preparation() }
      }.alignItems(HorizontalAlign.Start).padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom }).width('100%')
    }.id(this.route.section === 1 ? 'project-packing' : 'project-preparation').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
      .bindSheet(this.route.linking, this.linkSheet(), { height: SheetSize.LARGE, showClose: true, onDisappear: () => { this.route.linking = false; } })
      .onDisAppear(() => this.state.suspend())
  }
}
