import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS, PROJECT_STATUSES, PROJECT_LABELS } from '../../common/constants';
import { StaggerEntrance, pageTransition } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { confirm } from '../../common/Confirm';
import { AppState } from '../../model/ApplicationState';
import { AssetRoute } from '../../model/AssetRoute';
import { assetUsesSegments } from '../../model/Wardrobe';
import { Theme } from '../../common/Theme';
import { Asset, AssetStatus, CosProject } from '../../model/Entities';
import { SectionHeading, StatusPill, FactRow, EmptyState } from '../../component/Surfaces';
import { SheetHeader } from '../../component/SheetHeader';
import { DashboardSearch } from '../../component/DashboardSearch';

@ComponentV2
export struct AssetDetail {
  @Require @Param state: AppState;
  @Require @Param route: AssetRoute;
  @Require @Param asset: Asset;
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  @Local actionError: string = '';
  private scroller: Scroller = new Scroller();
  private measured: boolean = false;
  private restoring: boolean = true;
  private restoreTimer: number = -1;
  private displayedSection: number = 0;
  private segmented(): boolean { return this.route.section === 1 || assetUsesSegments(this.asset, this.state.assetUsage(this.asset.id)); }
  aboutToAppear(): void { this.displayedSection = this.route.section; if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); } if (!this.entrance.managed) { this.entrance.reset(); } }
  @Monitor('route.section', 'route.restoreVersion')
  viewChanged(): void { this.displayedSection = this.route.section; this.restoreOffset(); }
  private restoreOffset(): void {
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); } this.restoring = true;
    this.restoreTimer = setTimeout((): void => { this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false }); this.restoring = false; }, 0);
  }
  private projectsToChoose(): CosProject[] {
    const query = this.route.projectQuery.trim().toLocaleLowerCase();
    return this.state.projects.filter((project: CosProject) => !query || (project.name + ' ' + this.state.characterName(project.characterId)).toLocaleLowerCase().includes(query));
  }
  private linked(id: string): boolean { return this.state.assetUsage(this.asset.id).projects.some((project: CosProject) => project.id === id); }
  private async join(project: CosProject): Promise<void> {
    this.actionError = '';
    if (await this.state.linkAsset(project.id, this.asset)) { this.route.linking = false; this.route.section = 1; }
    else { this.actionError = this.state.error || '关联未保存，请重试'; }
  }
  private async unlink(project: CosProject): Promise<void> {
    const usage = this.state.assetUsage(this.asset.id);
    const ids = usage.checklist.filter((item) => item.projectId === project.id).map((item) => item.id);
    if (!(await confirm(this.getUIContext(), '解除「' + this.asset.name + '」的关联？', usage.unlinkMessage(project), '解除关联'))) { return; }
    this.actionError = '';
    if (!(await this.state.unlinkAsset(project.id, this.asset.id, ids))) { this.actionError = this.state.error || '关联未解除，请重试'; }
  }
  @Builder heading() {
    Text(this.asset.name).fontSize(22).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
    Row({ space: 10 }) {
      Text(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.asset.type)]).fontSize(14).fontColor(Theme.muted)
      StatusPill({ label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.asset.status)] })
    }
    if (this.asset.status !== AssetStatus.OWNED) {
      Text('当前不可用 · 影响 ' + this.state.assetUsage(this.asset.id).activeProjects.length + ' 份进行中计划，全部使用计划 ' + this.state.assetUsage(this.asset.id).projects.length + ' 份').fontSize(14).fontColor(Theme.accent)
    }
    if (this.route.from === 'project' || this.route.from === 'day') { Text(this.state.projects.some((project: CosProject) => project.id === this.route.projectId) ? '来自 ' + this.state.projectName(this.route.projectId) + (this.route.from === 'day' ? ' · 今天模式' : '') : '来源计划已不存在，返回最近有效页面').fontSize(14).fontColor(Theme.muted) }
    if (this.actionError || this.state.error) { Text(this.actionError || this.state.error).fontSize(14).fontColor(Theme.danger) }
  }
  @Builder facts() {
    FactRow({ label: '存放位置', value: this.asset.location.trim() || '未记录位置' })
    if (!this.asset.location.trim()) { Button('补充存放位置').constraintSize({ minHeight: 48 }).enabled(!this.state.busy && !this.state.staleScopes.length).onClick((): void => { this.edit('asset', this.asset.id, ''); }) }
    if (this.asset.brand) { FactRow({ label: '品牌店铺', value: this.asset.brand }) }
    if (this.asset.size) { FactRow({ label: '尺码', value: this.asset.size }) }
    FactRow({ label: '资料价格', value: '¥' + (this.asset.priceCents / 100).toFixed(2) + '（未计入花费）' })
    if (this.asset.purchaseUrl) { FactRow({ label: '购买链接', value: this.asset.purchaseUrl, copyable: true }) }
    if (this.asset.notes) { FactRow({ label: '备注', value: this.asset.notes }) }
    Button('收录 · ' + this.state.assetUsage(this.asset.id).entryIds.length + ' 条').constraintSize({ minHeight: 48 }).width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { this.open('inbox', 'asset|' + this.asset.id); })
  }
  @Builder uses() {
    SectionHeading({ title: '使用计划', trailing: this.state.assetUsage(this.asset.id).projects.length + ' 份' })
    Text('装备资料与状态由衣柜统一维护；加入计划同时建立对应打包项。').fontSize(14).fontColor(Theme.muted)
    Button('加入计划').constraintSize({ minHeight: 48 }).width('100%').enabled(!this.state.busy && !this.state.staleScopes.length)
      .onClick((): void => { this.actionError = ''; this.route.projectQuery = ''; this.route.linking = true; })
    ForEach(this.state.assetUsage(this.asset.id).projects, (project: CosProject) => {
      Column({ space: 8 }) {
        Button('打开计划 · ' + project.name).constraintSize({ minHeight: 48 }).width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { this.open('project', project.id); })
        Text(PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)] + ' · ' + (this.state.readiness(project.id).date || '日期待定')).fontSize(14).fontColor(Theme.muted)
        Button('解除本计划关联').constraintSize({ minHeight: 48 }).width('100%').enabled(!this.state.busy && !this.state.staleScopes.length).onClick((): void => { void this.unlink(project); }).accessibilityText('解除 ' + project.name + ' 的装备关联')
      }.width('100%').alignItems(HorizontalAlign.Start)
    }, (project: CosProject) => project.id)
    if (!this.state.assetUsage(this.asset.id).projects.length) { Text('尚未被计划使用，衣柜记录仍保留。').fontSize(14).fontColor(Theme.muted) }
  }
  @Builder planSheet() {
    Column({ space: 14 }) {
      SheetHeader({ title: '选择计划加入装备', hint: this.asset.name + ' · ' + ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.asset.status)], close: (): void => { if (!this.state.busy) { this.route.linking = false; } } })
      if (this.asset.status !== AssetStatus.OWNED) { Text('加入后仍保留当前不可用状态，相关计划会显示装备问题。').fontSize(14).fontColor(Theme.accent) }
      DashboardSearch({ value: this.route.projectQuery, label: '查找要加入的计划', placeholder: '搜索计划 / 角色', changed: (value: string): void => { this.route.projectQuery = value; } })
      if (this.actionError || this.state.error) { Text(this.actionError || this.state.error).fontSize(14).fontColor(Theme.danger) }
      List({ space: 10 }) {
        ForEach(this.projectsToChoose(), (project: CosProject) => {
          ListItem() {
            Button(project.name + ' · ' + (this.linked(project.id) ? '已加入' : PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)]))
              .constraintSize({ minHeight: 48 }).width('100%').enabled(!this.state.busy && !this.state.staleScopes.length && !this.linked(project.id)).onClick((): void => { void this.join(project); }).accessibilityText('将装备加入计划 ' + project.name)
          }
        }, (project: CosProject) => project.id)
        if (!this.projectsToChoose().length) {
          ListItem() { EmptyState({ title: this.route.projectQuery.trim() ? '没有匹配的计划' : '先建立一份计划', message: '装备保持在衣柜，计划建立后可在此选择加入。', button: this.route.projectQuery.trim() ? '清除搜索' : '新建计划', action: (): void => { if (this.route.projectQuery.trim()) { this.route.projectQuery = ''; } else { this.route.linking = false; this.edit('project', '', ''); } } }) }
        }
      }.layoutWeight(1).width('100%')
    }.padding(24).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  private sheetOptions(): SheetOptions {
    const options = appSheetOptions((): void => { this.route.linking = false; }, this.sheetEntrance, this.getUIContext());
    options.onWillDismiss = (action: DismissSheetAction): void => { if (!this.state.busy) { action.dismiss(); } }; return options;
  }
  build() {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(this.segmented() ? Theme.detailTop : Theme.detailTop).width('100%')
        this.heading()
        if (this.route.section === 0 || !this.segmented()) { this.facts() }
        if (this.route.section === 1 || !this.segmented()) { this.uses() }
        Blank().height(Theme.contentBottom).width('100%')
      }.constraintSize({ maxWidth: Theme.contentMaxWidth }).width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding }).alignItems(HorizontalAlign.Start)
    }.id('asset-detail-scroll').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
      .onAreaChange((_old: Area, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreOffset(); } })
      .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offsets[this.displayedSection] = this.scroller.currentOffset().yOffset; } })
      .bindSheet(this.route.linking, this.planSheet(), this.sheetOptions())
  }
}
