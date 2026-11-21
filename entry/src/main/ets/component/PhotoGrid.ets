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

@ObservedV2
class PhotoSelection {
  @Trace active: boolean = false;
  @Trace ids: Set<string> = new Set<string>();
}

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
  private selection: PhotoSelection = new PhotoSelection();
  @Local targetStatus: PhotoStatus = PhotoStatus.SELECTED;
  @Local columns: number = 2;
  @Local visiblePhotos: PhotoAsset[] = [];
  private rowsSource: ArrayDataSource<PhotoAsset[]> = new ArrayDataSource<PhotoAsset[]>([]);
  aboutToAppear(): void { this.refreshVisible(); }
  @Monitor('photos', 'filter', 'portfolio')
  private refreshVisible(): void {
    this.visiblePhotos = this.portfolio ? portfolioStage(this.photos, this.filter) : photoStage(this.photos, this.filter);
    this.refreshRows();
  }
  @Monitor('columns')
  private refreshRows(): void {
    const rows: PhotoAsset[][] = [];
    for (let index = 0; index < this.visiblePhotos.length; index += this.columns) {
      rows.push(this.visiblePhotos.slice(index, index + this.columns));
    }
    this.rowsSource.replace(rows);
  }
  @Monitor('photos')
  private photosChanged(): void { this.selection.ids = new Set<string>(); }
  private filterLabels(): string[] { return this.portfolio ? ['全部作品', '成片', '已发布'] : ['全部', '待选', '已选', '待修', '成片']; }
  private choose(photo: PhotoAsset): void {
    if (!this.selection.active) { this.open('photo', photo.id); return; }
    const selected = new Set<string>(this.selection.ids);
    if (!selected.delete(photo.id)) { selected.add(photo.id); }
    this.selection.ids = selected;
  }
  private async apply(): Promise<void> {
    if (await this.state.setPhotoStatuses(Array.from(this.selection.ids), this.targetStatus)) {
      this.selection.ids = new Set<string>();
      this.selection.active = false;
    }
  }
  @Builder controls() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Select(this.filterLabels().map((label: string): SelectOption => { return { value: label }; }))
          .selected(this.filter).value(this.filterLabels()[this.filter]).layoutWeight(1).enabled(!this.state.busy)
          .id(this.portfolio ? 'portfolio-status-filter' : 'photo-status-filter')
          .onSelect((index: number) => { vibration.dotVibration(); this.filter = index; this.selection.ids = new Set<string>(); })
            .accessibilityText('照片状态筛选')
            .visualEffect(this.feedback.effect('select-1'))
            .compositingFilter(this.feedback.filter('select-1'))
            .attributeModifier(this.feedback.control('select-1'))
        Button(this.selection.active ? '取消选择' : '批量选片')
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .enabled(!this.state.busy && this.photos.length > 0)
          .onClick(() => { vibration.dotVibration(); this.selection.active = !this.selection.active; this.selection.ids = new Set<string>(); })
          .accessibilityText(this.selection.active ? '取消选择' : '批量选片')
          .visualEffect(this.feedback.effect('button-2'))
          .compositingFilter(this.feedback.filter('button-2'))
          .attributeModifier(this.feedback.control('button-2'))
      }.width('100%')
      if (this.selection.active) {
        Row() {
          Text('已选 ' + this.selection.ids.size + ' 张').fontSize(14).fontColor(Theme.ink).layoutWeight(1)
          Button(this.selection.ids.size === this.visiblePhotos.length ? '取消全选' : '全选当前筛选')
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .enabled(!this.state.busy)
            .onClick(() => {
              vibration.dotVibration();
              this.selection.ids = this.selection.ids.size === this.visiblePhotos.length ? new Set<string>() :
                new Set<string>(this.visiblePhotos.map((photo: PhotoAsset) => photo.id));
            })
            .accessibilityText(this.selection.ids.size === this.visiblePhotos.length ? '取消全选' : '全选当前筛选')
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
            .enabled(!this.state.busy && this.selection.ids.size > 0)
            .onClick(() => { vibration.dotVibration(); this.apply(); })
            .accessibilityText(this.state.busy ? '更新中' : '应用状态')
            .visualEffect(this.feedback.effect('button-5'))
            .compositingFilter(this.feedback.filter('button-5'))
            .attributeModifier(this.feedback.control('button-5'))
        }.width('100%')
      }
    }.width('100%')
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
      } else if (this.visiblePhotos.length === 0) {
        ListItem() { EmptyState({ title: '这个状态下还没有照片', message: '切换筛选查看其他照片。' }).opacity(this.step() >= 2 ? 1 : 0).translate({ y: this.step() >= 2 ? 0 : 20 }) }
      } else {
        LazyForEach(this.rowsSource, (row: PhotoAsset[]) => {
          ListItem() {
            Row({ space: 12 }) {
              ForEach(row, (photo: PhotoAsset) => {
                PhotoGridCard({
                  photo: photo,
                  state: this.state,
                  selection: this.selection,
                  choose: () => this.choose(photo)
                }).layoutWeight(1)
              }, (photo: PhotoAsset) => photo.id)
              ForEach(new Array<number>(Math.max(0, this.columns - row.length))
                .fill(0), (_value: number, index: number) => { Blank()
                .layoutWeight(1) }, (_value: number, index: number) => String(index))
            }.width('100%').alignItems(VerticalAlign.Top).opacity(this.step() >= 2 ? 1 : 0).translate({ y: this.step() >= 2 ? 0 : 20 })
          }
        }, (row: PhotoAsset[]) => row.map((photo: PhotoAsset) => photo.id + ':' + photo.projectId + ':' + photo.thumbnailPath + ':' + photo.status)
          .join('|'))
      }
      ListItem() { Column() { Blank().height(this.bottomInset).width('100%') }.width('100%') }
    }.id(this.portfolio ? 'portfolio-photo-list' : 'photo-list').width('100%')
      .constraintSize({ maxWidth: Theme.contentMaxWidth })
      .height('100%')
      .padding({ left: this.sidePadding, right: this.sidePadding })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange((_old: Area, area: Area) => {
        const width = Number(area.width);
        this.columns = width >= 720 ? 4 : width >= 520 ? 3 : 2;
      })
  }
}

@ComponentV2
struct PhotoGridCard {
  @Require @Param photo: PhotoAsset;
  @Require @Param state: AppState;
  @Require @Param selection: PhotoSelection;
  @Event choose: () => void = () => {};

  private projectName(): string { return this.state.projectName(this.photo.projectId); }
  private statusLabel(): string { return PHOTO_LABELS[PHOTO_STATUSES.indexOf(this.photo.status)]; }

  @Builder content() {
    Column({ space: 6 }) {
      if (this.photo.thumbnailPath) {
        ManagedImage({ sourcePath: this.photo.thumbnailPath, label: this.projectName() + '，' + this.statusLabel() })
          .width('100%').aspectRatio(0.8).borderRadius(14).clip(true)
      } else {
        Text('照片待恢复').width('100%').aspectRatio(0.8).backgroundColor(Theme.surface)
          .borderRadius(14).fontColor(Theme.muted).textAlign(TextAlign.Center)
      }
      Column({ space: 6 }) {
        if (this.selection.active) { Text(this.selection.ids.has(this.photo.id) ? '✓ 已选' : '○ 点选').fontSize(14).fontColor(Theme.accent) }
        Text(this.statusLabel()).fontSize(12).fontColor(Theme.accent)
        Text(this.projectName()).fontSize(11).fontColor(Theme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.id('photo-caption:' + this.photo.id).width('100%').alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: 4, bottom: 14 })
    }.width('100%')
  }

  build() {
    InteractiveCard({
      label: this.projectName() + '，' + this.statusLabel(),
      hint: this.selection.active ? '双击切换照片选择' : '双击打开照片详情',
      effects: this.state.settings.effects,
      contentPadding: 0,
      action: this.choose,
      content: (): void => { this.content(); }
    })
  }
}
