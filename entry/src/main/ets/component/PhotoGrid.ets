import { PHOTO_FILTER_LABELS, photoStatusLabel, PHOTO_EDIT_STATUSES } from '../model/PhotoStages';
import { PhotoCollectionRoute, PhotoViewerRoute, selectPhotoCollection } from '../model/PhotoCollection';
import { StaggerEntrance } from '../common/motion';
import { PressFeedback } from '../common/pressFeedback';
import { ManagedImage } from './ManagedImage';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { PhotoAsset, PhotoStatus } from '../model/Entities';
import { EmptyState, InteractiveCard } from './Surfaces';
import { vibration } from '../common/vibration';

@ComponentV2
export struct PhotoGrid {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param entrance: StaggerEntrance | undefined = undefined;
  @Param entranceStep: number = 2;
  private step(): number { return this.entrance ? this.entrance.step : this.entranceStep; }
  @Param scroller: Scroller = new Scroller();
  @Require @Param state: AppState;
  @Param photos: PhotoAsset[] = [];
  @Require @Param route: PhotoCollectionRoute;
  @Param from: string = 'album';
  @Event view: (route: PhotoViewerRoute) => void = () => {};
  @Event addPhotos: () => void = () => {};
  @Event showAlbum: () => void = () => {};
  @Param topInset: number = 0;
  @Param bottomInset: number = 20;
  @Param sidePadding: number = 0;
  @BuilderParam header: () => void = this.emptyHeader;
  @Builder emptyHeader() {}
  @Local viewportWidth: number = 360;
  private rowsSource: ArrayDataSource<PhotoAsset[]> = new ArrayDataSource<PhotoAsset[]>([]);
  private restoreTimer: number = -1;
  private restoring: boolean = false;
  private restored: boolean = false;
  private viewportHeight: number = 0;
  aboutToAppear(): void { this.route.reconcile(this.photos); this.refreshRows(); this.restoreOffset(); }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; } }
  @Monitor('photos', 'route.filter', 'route.portfolio', 'route.queue', 'route.planId', 'viewportWidth', 'route.selecting', 'route.selectedIds')
  private refreshRows(): void { this.rowsSource.replace(this.rows()); }
  @Monitor('photos')
  private photosChanged(): void { this.route.reconcile(this.photos); }
  @Monitor('route', 'route.filter', 'route.portfolio', 'route.planId', 'route.restoreVersion')
  private contextChanged(): void { this.restoreOffset(); }
  private restoreOffset(): void {
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoring = true;
    if (this.viewportHeight <= 0) { return; }
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false }); this.restoring = false; this.restored = true;
      if (this.route.anchorId && this.visible().some((photo: PhotoAsset) => photo.id === this.route.anchorId)) {
        try { this.getUIContext().getFocusController().requestFocus('photo-thumbnail:' + this.route.anchorId); } catch (error) {}
      }
    }, 0);
  }
  private visible(): PhotoAsset[] { return selectPhotoCollection(this.photos, this.route); }
  private filters(): number[] { return this.route.portfolio ? [0, 7] : this.route.queue ? [0, 1, 3] : [0, 1, 2, 3, 4, 5, 6, 7]; }
  private filterLabels(): string[] { return this.route.portfolio ? ['全部作品', '已发布'] : this.filters().map((filter: number) => PHOTO_FILTER_LABELS[filter]); }
  private choose(photo: PhotoAsset): void {
    if (this.state.busy || this.route.submitting) { return; }
    if (!this.route.selecting) {
      this.route.offset = this.scroller.currentOffset().yOffset;
      this.view(new PhotoViewerRoute(photo.id, this.from, this.route, this.photos)); return;
    }
    this.route.toggle(photo.id, this.photos);
  }
  private async apply(): Promise<void> {
    if (this.state.busy) { return; }
    const ids = this.route.begin(this.photos); if (!ids.length) { return; }
    try {
      const committed = await this.state.setPhotoStatuses(ids, this.route.targetStatus); this.route.finish(committed);
      this.route.feedback = committed ? '已更新 ' + ids.length + ' 张照片' : this.state.error || '更新失败，照片选择已保留';
    } catch (error) { this.route.finish(false); this.route.feedback = (error as Error).message || '更新失败，照片选择已保留'; }
  }
  @Builder controls() {
    Column({ space: 12 }) {
      Text('当前范围 ' + this.visible().length + ' 张').fontSize(14).fontColor(Theme.muted)
      Row({ space: 12 }) {
        Select(this.filterLabels().map((label: string): SelectOption => { return { value: label }; }))
          .selected(this.filters().indexOf(this.route.filter)).value(this.filterLabels()[this.filters().indexOf(this.route.filter)] || this.filterLabels()[0]).layoutWeight(1)
          .enabled(!this.state.busy && !this.route.submitting).constraintSize({ minHeight: 48 })
          .id(this.route.portfolio ? 'portfolio-status-filter' : 'photo-status-filter')
          .onSelect((index: number): void => { vibration.dotVibration(); this.route.setFilter(this.filters()[index]); })
          .accessibilityText('照片状态筛选')
        Button(this.route.selecting ? '取消选择' : '批量选片').constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).fontColor(Theme.accent)
          .enabled(!this.state.busy && !this.route.submitting && this.visible().length > 0)
          .onClick((): void => { this.route.selecting = !this.route.selecting; this.route.clearSelection(); })
      }.width('100%')
      if (this.route.selecting) {
        Row() {
          Text('已选 ' + this.route.selectedIds.length + ' 张').fontSize(14).fontColor(Theme.ink).layoutWeight(1)
          Button(this.visible().length > 0 && this.route.selectedIds.length === this.visible().length ? '取消全选' : '全选当前筛选')
            .constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy && !this.route.submitting)
            .onClick((): void => { this.route.selectAll(this.photos); })
        }.width('100%')
        Row({ space: 12 }) {
          Select(PHOTO_EDIT_STATUSES.map((status: PhotoStatus): SelectOption => { return { value: '标为' + photoStatusLabel(status) }; }))
            .value('标为' + photoStatusLabel(this.route.targetStatus)).layoutWeight(1).constraintSize({ minHeight: 48 }).enabled(!this.state.busy && !this.route.submitting)
            .onSelect((index: number): void => { this.route.targetStatus = PHOTO_EDIT_STATUSES[index]; }).accessibilityText('批量照片状态')
          Button(this.route.submitting ? '更新中…' : '标为' + photoStatusLabel(this.route.targetStatus)).id('photo-batch-apply')
            .constraintSize({ minHeight: 48 }).backgroundColor(Theme.brand).fontColor(Theme.onAccent)
            .enabled(!this.state.busy && !this.route.submitting && this.route.selectedIds.length > 0).onClick((): void => { this.apply(); })
        }.width('100%')
      }
      if (this.route.feedback) { Text(this.route.feedback).id('photo-collection-feedback').fontSize(14).fontColor(Theme.accent) }
    }.width('100%')
  }
  @Builder photoContent(photo: PhotoAsset) {
    Column({ space: 6 }) {
      if (photo.thumbnailPath) {
        ManagedImage({ sourcePath: photo.thumbnailPath, label: this.state.projectName(photo.projectId) + '，' + photoStatusLabel(photo.status), failureText: '缩略图加载失败，可打开原图' })
          .width('100%').aspectRatio(0.8).borderRadius(14).clip(true)
      } else {
        Text(photo.localPath ? '缩略图未建立，可打开原图' : '媒体待恢复').width('100%').aspectRatio(0.8).backgroundColor(Theme.surface).borderRadius(14).fontColor(Theme.muted).textAlign(TextAlign.Center)
      }
      Column({ space: 6 }) {
        if (this.route.selecting) { Text(this.route.selectedIds.includes(photo.id) ? '✓ 已选' : '○ 点选').fontSize(14).fontColor(Theme.accent) }
        Text(photoStatusLabel(photo.status)).fontSize(14).fontColor(Theme.accent)
        Text(this.state.projectName(photo.projectId)).fontSize(14).fontColor(Theme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.id('photo-caption:' + photo.id).width('100%').alignItems(HorizontalAlign.Start).padding({ left: 12, right: 12, top: 4, bottom: 14 })
    }.width('100%')
  }
  private columns(): number { return this.viewportWidth >= 720 ? 4 : this.viewportWidth >= 520 ? 3 : 2; }
  private rows(): PhotoAsset[][] {
    const rows: PhotoAsset[][] = []; const photos = this.visible(); const count = this.columns();
    for (let i = 0; i < photos.length; i += count) { rows.push(photos.slice(i, i + count)); } return rows;
  }
  build() {
    List({ space: Theme.sectionSpacing, scroller: this.scroller }) {
      ListItem() {
        Column() {
          Blank().height(this.topInset > 0 ? this.topInset + Theme.sectionSpacing : 0).width('100%')
          Column({ space: 12 }) { this.header(); this.controls() }.width('100%').opacity(this.step() >= 1 ? 1 : 0)
        }.width('100%')
      }
      if (!this.visible().length) {
        ListItem() {
          Column({ space: 12 }) {
          EmptyState({ title: this.route.portfolio ? '作品从第一张成片开始' : this.route.queue ? '这个范围没有待处理照片' : '这个范围还没有照片',
            message: this.route.portfolio ? '成片与已发布使用同一份照片，参考图不计入作品。' : '可以调整筛选，或明确所属计划后导入。',
            button: this.route.portfolio ? '打开相册' : '导入照片', action: (): void => { if (this.route.portfolio) { this.showAlbum(); } else { this.addPhotos(); } } })
          if (this.route.filter) { Button('清除照片状态筛选').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.setFilter(0); }) }
          }.width('100%')
        }
      } else {
        LazyForEach(this.rowsSource, (row: PhotoAsset[]) => {
          ListItem() {
            Row({ space: 12 }) {
              ForEach(row, (photo: PhotoAsset) => {
                InteractiveCard({
                  label: this.state.projectName(photo.projectId) + '，' + photoStatusLabel(photo.status), hint: this.route.selecting ? '双击切换照片选择' : '双击打开照片详情',
                  effects: this.state.settings.effects, contentPadding: 0, action: (): void => { this.choose(photo); }, content: (): void => { this.photoContent(photo); } }).id('photo-thumbnail:' + photo.id).layoutWeight(1)
              }, (photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status + ':' + this.route.selecting + ':' + this.route.selectedIds.includes(photo.id))
              ForEach(new Array<number>(Math.max(0, this.columns() - row.length)).fill(0), (_value: number) => { Blank().layoutWeight(1) }, (_value: number, index: number) => String(index))
            }.width('100%').alignItems(VerticalAlign.Top).opacity(this.step() >= 2 ? 1 : 0)
          }
        }, (row: PhotoAsset[]) => row.map((photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status + ':' + this.route.selecting + ':' + this.route.selectedIds.includes(photo.id)).join('|'))
      }
      ListItem() { Column() { Blank().height(this.bottomInset).width('100%') }.width('100%') }
    }.id(this.route.portfolio ? 'portfolio-photo-list' : 'photo-list').width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).height('100%')
      .padding({ left: this.sidePadding, right: this.sidePadding }).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .onAreaChange((_old: Area, area: Area): void => { this.viewportWidth = Number(area.width); this.viewportHeight = Number(area.height); if (!this.restored && this.viewportHeight > 0) { this.restoreOffset(); } })
      .onDidScroll((): void => { if (this.restored && !this.restoring) { this.route.offset = this.scroller.currentOffset().yOffset; } })
  }
}
