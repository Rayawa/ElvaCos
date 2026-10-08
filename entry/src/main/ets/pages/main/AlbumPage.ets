import { PhotoImportStatus } from '../../component/PhotoImportStatus';
import { AppState } from '../../model/ApplicationState';
import { AlbumRoute } from '../../model/AlbumRoute';
import { AlbumPlan } from '../../model/AlbumSummary';
import { PhotoViewerRoute, selectPhotoCollection } from '../../model/PhotoCollection';
import { PHOTO_STAGE_LABELS, PHOTO_FILTER_LABELS } from '../../model/PhotoStages';
import { CosProject, PhotoAsset } from '../../model/Entities';
import { StaggerEntrance, MainEntranceSession } from '../../common/motion';
import { DistributionChart } from '../../component/charts/DistributionChart';
import { PhotoDistributionItem } from '../../model/Statistics';
import { Theme } from '../../common/Theme';
import { PhotoGrid } from '../../component/PhotoGrid';
import { ManagedImage } from '../../component/ManagedImage';
import { InteractiveCard, EmptyState } from '../../component/Surfaces';

@ComponentV2
export struct AlbumPage {
  @Require @Param state: AppState;
  @Require @Param route: AlbumRoute;
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = true;
  @Param topInset: number = Theme.detailTopWithSegment;
  @Param bottomInset: number = Theme.contentBottom;
  @Event view: (route: PhotoViewerRoute) => void = () => {};
  @Event importPhotos: (planId: string) => void = () => {};
  @Param scroller: Scroller = new Scroller();
  @Local distributionOpen: boolean = false;
  private entered: boolean = false;
  private restoreTimer: number = -1;
  private restoring: boolean = false;
  private measured: boolean = false;
  aboutToAppear(): void { this.route.reconcile(this.state.projects, this.state.photos); this.restoreOffset(); if (this.active) { this.enter(); } }
  private enter(): void {
    if (this.entrance.managed || this.entered) { return; } this.entered = true;
    if (this.entranceSession.claim('AlbumPage')) { this.entrance.play(this.getUIContext()); } else { this.entrance.finish(4); }
  }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); this.route.restoreVersion++; this.route.collection.restoreVersion++; } }
  @Monitor('state.projects', 'state.photos')
  dataChanged(): void { this.route.reconcile(this.state.projects, this.state.photos); }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; } if (!this.entrance.managed) { this.entrance.finish(4); } }
  @Monitor('route.mode', 'route.byPlan.planId')
  modeChanged(): void { this.measured = false; this.restoreOffset(); }
  @Monitor('route.restoreVersion')
  contextChanged(): void { this.restoreOffset(); }
  private restoreOffset(): void {
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    if (this.route.mode !== 'byPlan' || this.route.byPlan.planId) { return; }
    this.restoring = true;
    if (!this.measured) { return; }
    this.restoreTimer = setTimeout((): void => { this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.groupOffset, animation: false }); this.restoring = false; }, 0);
  }
  private groups(): AlbumPlan[] {
    const collection = this.route.byPlan;
    if (collection.planId && !this.state.projects.some((project: CosProject) => project.id === collection.planId)) { return []; }
    if (collection.filter === 0 && !collection.portfolio) { return this.state.albumSummary.plans; }
    const plans = new Set<string>(selectPhotoCollection(this.state.photos, collection).map((photo: PhotoAsset) => photo.projectId));
    return this.state.albumSummary.plans.filter((plan: AlbumPlan) => plans.has(plan.id));
  }
  private distribution(): PhotoDistributionItem[] {
    const planId = this.route.collection.planId;
    const counts = planId ? this.state.readiness(planId).photos.byStage : this.state.albumSummary.counts;
    return PHOTO_STAGE_LABELS.map((label: string, index: number): PhotoDistributionItem => ({ label: label, value: counts[index] }));
  }
  @Builder planFilter() {
    Select(new Array<SelectOption>({ value: '全部场次 / 计划' }).concat(this.state.projects.map((project: CosProject): SelectOption => { return { value: project.name }; })))
      .value(this.route.collection.planId ? this.state.projectName(this.route.collection.planId) : '全部场次 / 计划').id('album-plan-filter').constraintSize({ minHeight: 48 })
      .enabled(!this.state.busy && !this.route.collection.submitting)
      .onSelect((index: number): void => { this.route.collection.setPlan(index ? this.state.projects[index - 1].id : ''); })
      .accessibilityText('相册计划范围')
  }
  @Builder scope() {
    Column({ space: 12 }) {
      this.planFilter()
      Text(this.route.mode === 'queue' ? '跨计划待选 / 待修；处理状态与计划照片同步。' : '按场次 / 计划整理；日期来自计划或关联活动，未设日期明确标注。').fontSize(14).fontColor(Theme.muted)
      if (this.route.mode === 'byPlan') {
        Button(this.route.byPlan.portfolio ? '作品集展示 · 返回全部照片' : '作品集展示 · 成片与已发布').constraintSize({ minHeight: 48 }).width('100%')
          .enabled(!this.state.busy && !this.route.collection.submitting).backgroundColor(Theme.tint).fontColor(Theme.accent)
          .onClick((): void => { this.route.byPlan.setPortfolio(!this.route.byPlan.portfolio); })
      }
      Button(this.distributionOpen ? '收起照片处理分布' : '展开照片处理分布').id('album-distribution-toggle').constraintSize({ minHeight: 48 }).width('100%')
        .backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { this.distributionOpen = !this.distributionOpen; })
      if (this.distributionOpen) { DistributionChart({ title: this.route.collection.planId ? '本计划照片处理分布' : '全仓照片处理分布', items: this.distribution(), paletteId: Theme.paletteId }) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder planCard(plan: AlbumPlan) {
    Row({ space: 14 }) {
      if (plan.cover?.thumbnailPath) { ManagedImage({ sourcePath: plan.cover.thumbnailPath, label: plan.name + '封面', failureText: '封面缩略图加载失败' }).width(80).height(100) }
      else { Text(plan.total ? '封面待恢复' : '待导入').width(80).height(100).textAlign(TextAlign.Center).fontColor(Theme.muted).backgroundColor(Theme.tint).borderRadius(14) }
      Column({ space: 7 }) {
        Text(plan.name).fontSize(18).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(plan.event + ' · ' + (plan.date || '日期待定')).fontSize(14).fontColor(Theme.muted)
        Text(plan.total + ' 张 · 成片 ' + plan.counts[4] + ' · 归档 ' + plan.counts[5]).fontSize(14).fontColor(Theme.accent)
        Text(PHOTO_STAGE_LABELS.slice(0, 4).map((label: string, index: number) => label + ' ' + plan.counts[index]).join(' · ')).fontSize(14).fontColor(Theme.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }
  build() {
    if (this.route.mode === 'queue' || this.route.byPlan.planId) {
      PhotoGrid({ state: this.state, photos: this.state.photos, route: this.route.collection, from: 'album', entrance: this.entrance, scroller: this.scroller,
        topInset: this.topInset, bottomInset: this.bottomInset, sidePadding: Theme.pagePadding,
        header: (): void => { this.scope(); }, view: this.view,
        addPhotos: (): void => { this.importPhotos(this.route.collection.planId); }, showAlbum: (): void => { this.route.byPlan.setPortfolio(false); } })
    } else {
      Scroll(this.scroller) {
        Column({ space: Theme.sectionSpacing }) {
          Blank().height(this.topInset).width('100%')
          this.scope()
          PhotoImportStatus({ state: this.state })
          Select((this.route.byPlan.portfolio ? ['全部作品', '已发布'] : PHOTO_FILTER_LABELS).map((label: string): SelectOption => { return { value: label }; })).id(this.route.byPlan.portfolio ? 'portfolio-status-filter' : 'album-status-filter')
            .value((this.route.byPlan.portfolio ? ['全部作品', '已发布'] : PHOTO_FILTER_LABELS)[this.route.byPlan.portfolio ? [0, 7].indexOf(this.route.byPlan.filter) : this.route.byPlan.filter]).constraintSize({ minHeight: 48 })
            .enabled(!this.state.busy).onSelect((filter: number): void => { this.route.byPlan.setFilter(this.route.byPlan.portfolio ? [0, 7][filter] : filter); this.route.groupOffset = 0; this.restoreOffset(); }).accessibilityText('场次照片状态筛选')
          if (this.route.byPlan.feedback) { Text(this.route.byPlan.feedback).fontSize(14).fontColor(Theme.accent) }
          Text('全仓照片 ' + this.state.albumSummary.total + ' 张 · 成片 ' + this.state.albumSummary.counts[4] + ' · 归档 ' + this.state.albumSummary.counts[5]).fontSize(14).fontColor(Theme.muted)
          ForEach(this.groups(), (plan: AlbumPlan) => {
            InteractiveCard({ label: '打开相册计划 ' + plan.name, hint: '双击查看本场照片', effects: this.state.settings.effects,
              action: (): void => { this.route.groupOffset = this.scroller.currentOffset().yOffset; this.route.byPlan.setPlan(plan.id); }, content: (): void => { this.planCard(plan); } }).id('album-plan:' + plan.id)
          }, (plan: AlbumPlan) => plan.id)
          if (!this.groups().length) {
            if (this.route.byPlan.filter || this.route.byPlan.portfolio) { Button('清除照片范围筛选').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.byPlan.setPortfolio(false); this.route.byPlan.setFilter(0); }) }
            EmptyState({ title: this.state.projects.length ? '这个筛选下没有场次' : '照片从一份计划开始', message: '先明确照片所属计划，参考图与收录图片不进入成果相册。', button: '导入照片', action: (): void => { this.importPhotos(''); } })
          }
          Blank().height(this.bottomInset).width('100%')
        }.width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).padding({ left: Theme.pagePadding, right: Theme.pagePadding }).alignItems(HorizontalAlign.Start)
      }.id('album-plan-list').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
        .onAreaChange((_old: Area, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreOffset(); } })
        .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.groupOffset = this.scroller.currentOffset().yOffset; } })
    }
  }
}
