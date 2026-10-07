import { PHOTO_LABELS, PHOTO_STATUSES } from '../common/constants';
import { StaggerEntrance } from '../common/motion';
import { PressFeedback } from '../common/pressFeedback';
import { ManagedImage } from './ManagedImage';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { photoStage, portfolioStage } from '../model/Rules';
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
  @Param portfolio: boolean = false;
  @Event open: (kind: string, id: string) => void = () => {};
  @Param topInset: number = 0;
  @Param bottomInset: number = 20;
  @Param sidePadding: number = 0;
  @BuilderParam header: () => void = this.emptyHeader;
  @Builder emptyHeader() {}
  @Local filter: number = 0;
  @Local selecting: boolean = false;
  @Local selectedIds: string[] = [];
  @Local targetStatus: PhotoStatus = PhotoStatus.SELECTED;
  private rowsSource: ArrayDataSource<PhotoAsset[]> = new ArrayDataSource<PhotoAsset[]>([]);
  aboutToAppear(): void { this.refreshRows(); }
  @Monitor('photos', 'filter', 'portfolio', 'viewportWidth', 'selecting', 'selectedIds')
  private refreshRows(): void { this.rowsSource.replace(this.rows()); }
  @Monitor('photos')
  private photosChanged(): void { this.selectedIds = []; }
  private visible(): PhotoAsset[] {
    if (!this.portfolio) { return photoStage(this.photos, this.filter); }
    return portfolioStage(this.photos, this.filter);
  }
  private filterLabels(): string[] { return this.portfolio ? ['全部作品', '成片', '已发布'] : ['全部', '待选', '已选', '待修', '成片']; }
  private choose(photo: PhotoAsset): void {
    if (!this.selecting) { this.open('photo', photo.id); return; }
    this.selectedIds = this.selectedIds.includes(photo.id) ? this.selectedIds.filter((id: string) => id !== photo.id) : this.selectedIds.concat(photo.id);
  }
  private async apply(): Promise<void> {
    if (await this.state.setPhotoStatuses(this.selectedIds, this.targetStatus)) { this.selectedIds = []; this.selecting = false; }
  }
  @Builder controls() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Select(this.filterLabels().map((label: string): SelectOption => { return { value: label }; }))
          .selected(this.filter).value(this.filterLabels()[this.filter]).layoutWeight(1).enabled(!this.state.busy)
          .id(this.portfolio ? 'portfolio-status-filter' : 'photo-status-filter')
          .onSelect((index: number) => { vibration.dotVibration(); this.filter = index; this.selectedIds = []; })
            .accessibilityText('照片状态筛选')
            .visualEffect(this.feedback.effect('select-1'))
            .compositingFilter(this.feedback.filter('select-1'))
            .attributeModifier(this.feedback.control('select-1'))
        Button(this.selecting ? '取消选择' : '批量选片')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .enabled(!this.state.busy && this.photos.length > 0)
          .onClick(() => { vibration.dotVibration(); this.selecting = !this.selecting; this.selectedIds = []; })
          .accessibilityText(this.selecting ? '取消选择' : '批量选片')
          .visualEffect(this.feedback.effect('button-2'))
          .compositingFilter(this.feedback.filter('button-2'))
          .attributeModifier(this.feedback.control('button-2'))
      }.width('100%')
      if (this.selecting) {
        Row() {
          Text('已选 ' + this.selectedIds.length + ' 张').fontSize(14).fontColor(Theme.ink).layoutWeight(1)
          Button(this.selectedIds.length === this.visible()
            .length ? '取消全选' : '全选当前筛选')
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .enabled(!this.state.busy)
            .onClick(() => { vibration.dotVibration(); this.selectedIds = this.selectedIds.length === this.visible()
            .length ? [] : this.visible()
            .map((photo: PhotoAsset) => photo.id); })
            .accessibilityText(this.selectedIds.length === this.visible()
            .length ? '取消全选' : '全选当前筛选')
            .visualEffect(this.feedback.effect('button-3'))
            .compositingFilter(this.feedback.filter('button-3'))
            .attributeModifier(this.feedback.control('button-3'))
        }.width('100%')
        Row({ space: 12 }) {
          Select([{ value: '标为已选' }, { value: '标为待修' }, { value: '标为成片' }, { value: '退回待选' }])
            .value(this.targetStatus === PhotoStatus.WAITING ? '标为待修' : this.targetStatus === PhotoStatus.FINAL ? '标为成片' : this.targetStatus === PhotoStatus.RAW ? '退回待选' : '标为已选')
            .layoutWeight(1)
            .enabled(!this.state.busy)
            .onSelect((index: number) => { vibration.dotVibration(); this.targetStatus = [PhotoStatus.SELECTED, PhotoStatus.WAITING, PhotoStatus.FINAL, PhotoStatus.RAW][index]; })
              .accessibilityText('批量照片状态')
              .visualEffect(this.feedback.effect('select-4'))
              .compositingFilter(this.feedback.filter('select-4'))
              .attributeModifier(this.feedback.control('select-4'))
          Button(this.state.busy ? '更新中…' : '应用')
            .backgroundColor(Theme.brand)
            .fontColor(Theme.onAccent)
            .enabled(!this.state.busy && this.selectedIds.length > 0)
            .onClick(() => { vibration.dotVibration(); this.apply(); })
            .accessibilityText(this.state.busy ? '更新中' : '应用状态')
            .visualEffect(this.feedback.effect('button-5'))
            .compositingFilter(this.feedback.filter('button-5'))
            .attributeModifier(this.feedback.control('button-5'))
        }.width('100%')
      }
    }.width('100%')
  }
  @Local viewportWidth: number = 360;
  @Builder photoContent(photo: PhotoAsset) {
    Column({ space: 6 }) {
              if (photo.thumbnailPath) { ManagedImage({
                  sourcePath: photo.thumbnailPath,
                  label: this.state.projectName(photo.projectId) + '，' + PHOTO_LABELS[PHOTO_STATUSES.indexOf(photo.status)]
                })
                  .width('100%')
                  .aspectRatio(0.8)
                  .borderRadius(14)
                  .clip(true)
                  .accessibilityText(this.state.projectName(photo.projectId) + '，' + PHOTO_LABELS[PHOTO_STATUSES.indexOf(photo.status)]) }
              else { Text('照片待恢复')
                .width('100%')
                .aspectRatio(0.8)
                .backgroundColor(Theme.surface)
                .borderRadius(14)
                .fontColor(Theme.muted)
                .textAlign(TextAlign.Center)
                .visualEffect(this.feedback.effect('missing-photo:' + photo.id))
                .compositingFilter(this.feedback.filter('missing-photo:' + photo.id))
                .attributeModifier(this.feedback.control('missing-photo:' + photo.id)) }
              Column({ space: 6 }) {
              if (this.selecting) { Text(this.selectedIds.includes(photo.id) ? '✓ 已选' : '○ 点选').fontSize(14).fontColor(Theme.accent) }
              Text(PHOTO_LABELS[PHOTO_STATUSES.indexOf(photo.status)]).fontSize(12).fontColor(Theme.accent)
              Text(this.state.projectName(photo.projectId)).fontSize(11).fontColor(Theme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.id('photo-caption:' + photo.id).width('100%').alignItems(HorizontalAlign.Start)
                .padding({ left: 12, right: 12, top: 4, bottom: 14 })
            }.width('100%')
  }
  private rows(): PhotoAsset[][] {
    const count = this.viewportWidth >= 720 ? 4 : this.viewportWidth >= 520 ? 3 : 2;
    const rows: PhotoAsset[][] = [];
    const photos = this.visible();
    for (let i = 0; i < photos.length; i += count) { rows.push(photos.slice(i, i + count)); }
    return rows;
  }
  build() {
    List({ space: Theme.sectionSpacing, scroller: this.scroller }) {
      ListItem() {
        Column() {
          Blank().height(this.topInset > 0 ? this.topInset + Theme.sectionSpacing : 0).width('100%')
          Column({ space: 12 }) { this.header(); this.controls() }.
        width('100%').opacity(this.step() >= 1 ? 1 : 0).translate({ y: this.step() >= 1 ? 0 : 20 })
        }.width('100%')
      }
      if (this.photos.length === 0) {
        ListItem() { EmptyState({ title: this.portfolio ? '作品从第一张成片开始' : '每一张，都是一次登场', message: this.portfolio ? '在照片中标记为成片或已发布后，会展示在这里。' : '切换到计划的「照片」，通过系统选择器导入。' })
          .opacity(this.step() >= 2 ? 1 : 0)
          .translate({ y: this.step() >= 2 ? 0 : 20 }) }
      } else if (this.visible().length === 0) {
        ListItem() { EmptyState({ title: '这个状态下还没有照片', message: '切换筛选查看其他照片。' }).opacity(this.step() >= 2 ? 1 : 0).translate({ y: this.step() >= 2 ? 0 : 20 }) }
      } else {
        LazyForEach(this.rowsSource, (row: PhotoAsset[]) => {
          ListItem() {
            Row({ space: 12 }) {
              ForEach(row, (photo: PhotoAsset) => {
                InteractiveCard({
                  label: this.state.projectName(photo.projectId) + '，' + PHOTO_LABELS[PHOTO_STATUSES.indexOf(photo.status)],
                  hint: this.selecting ? '双击切换照片选择' : '双击打开照片详情',
                  effects: this.state.settings.effects,
                  contentPadding: 0,
                  action: () => this.choose(photo),
                  content: () => { this.photoContent(photo); }
                }).layoutWeight(1)
              }, (photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status + ':' + this.selecting + ':' + this.selectedIds.includes(photo.id))
              ForEach(new Array<number>(Math.max(0, (this.viewportWidth >= 720 ? 4 : this.viewportWidth >= 520 ? 3 : 2) - row.length))
                .fill(0), (_value: number, index: number) => { Blank()
                .layoutWeight(1) }, (_value: number, index: number) => String(index))
            }.width('100%').alignItems(VerticalAlign.Top).opacity(this.step() >= 2 ? 1 : 0).translate({ y: this.step() >= 2 ? 0 : 20 })
          }
        }, (row: PhotoAsset[]) => row.map((photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status + ':' + this.selecting + ':' + this.selectedIds.includes(photo.id))
          .join('|'))
      }
      ListItem() { Column() { Blank().height(this.bottomInset).width('100%') }.width('100%') }
    }.id(this.portfolio ? 'portfolio-photo-list' : 'photo-list').width('100%')
      .constraintSize({ maxWidth: Theme.contentMaxWidth })
      .height('100%')
      .padding({ left: this.sidePadding, right: this.sidePadding })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); })
  }
}
