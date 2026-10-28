import { StatusPill, EmptyState, InteractiveCard } from '../common/Surfaces';
import { displayName } from '../../utils/format/format';
import { PhotoImportStatus } from './PhotoImportStatus';
import { PHOTO_FILTER_LABELS, photoStatusLabel, PHOTO_EDIT_STATUSES } from '../../domain/photos/PhotoStages';
import { PhotoCollectionRoute, PhotoViewerRoute, selectPhotoCollection } from '../../models/PhotoCollection';
import { StaggerEntrance } from '../../ui/animation/motion';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { ManagedImage } from '../common/ManagedImage';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { ArrayDataSource } from '../../models/ArrayDataSource';
import { groupPhotoRows } from '../../domain/photos/PhotoRows';
import { PhotoAsset, PhotoStatus } from '../../models/Entities';
import { vibration } from '../../ui/feedback/vibration';

@ComponentV2
export struct PhotoGrid {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Param entrance: StaggerEntrance | undefined = undefined;
    @Param entranceStep: number = 2;
    private step(): number {
        return this.entrance ? this.entrance.step : this.entranceStep;
    }

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
    @BuilderParam scopeControls: () => void = this.emptyHeader;
    @BuilderParam header: () => void = this.emptyHeader;
    @Builder emptyHeader() {
    }

    @Local viewportWidth: number = 360;
    private rowsSource: ArrayDataSource<PhotoAsset[]> = new ArrayDataSource<PhotoAsset[]>([]);
    private restoreTimer: number = -1;
    private restoring: boolean = false;
    private restored: boolean = false;
    private viewportHeight: number = 0;

    aboutToAppear(): void {
        this.route.reconcile(this.photos);
        this.refreshRows();
        this.restoreOffset();
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
    }

    @Monitor('photos', 'route', 'route.filter', 'route.portfolio', 'route.queue', 'route.planId', 'viewportWidth')
    private refreshRows(): void {
        this.rowsSource.replace(this.photoRows);
        this.previousSelection = new Set<string>(this.route.selectedIds);
        this.previousSelecting = this.route.selecting;
    }
    private previousSelection: Set<string> = new Set<string>();
    private previousSelecting: boolean = false;
    @Monitor('route.selecting', 'route.selectedIds')
    private selectionChanged(): void {
        const next = this.selectedPhotoIds;
        this.photoRows.forEach((row: PhotoAsset[], index: number): void => {
            if (this.previousSelecting !== this.route.selecting || row.some((photo: PhotoAsset) => this.previousSelection.has(photo.id) !== next.has(photo.id))) {
                this.rowsSource.changed(index);
            }
        });
        this.previousSelection = new Set<string>(this.route.selectedIds);
        this.previousSelecting = this.route.selecting;
    }

    @Monitor('photos')
    private photosChanged(): void {
        this.route.reconcile(this.photos);
    }

    @Monitor('route', 'route.filter', 'route.portfolio', 'route.planId', 'route.restoreVersion')
    private contextChanged(): void {
        this.restoreOffset();
    }

    private restoreOffset(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoring = true;
        if (this.viewportHeight <= 0) {
            return;
        }
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false });
            this.restoring = false;
            this.restored = true;
            if (this.route.anchorId && this.visiblePhotos.some((photo: PhotoAsset) => photo.id === this.route.anchorId)) {
                try {
                    this.getUIContext().getFocusController().requestFocus('photo-thumbnail:' + this.route.anchorId);
                } catch (error) {
                }
            }
        }, 0);
    }

    @Computed
    private get visiblePhotos(): PhotoAsset[] {
        return selectPhotoCollection(this.photos, this.route);
    }

    @Computed
    private get photoRows(): PhotoAsset[][] {
        return groupPhotoRows(this.visiblePhotos, this.columns());
    }

    @Computed
    private get selectedPhotoIds(): Set<string> {
        return new Set<string>(this.route.selectedIds);
    }

    private filters(): number[] {
        return this.route.portfolio ? [0, 7] : this.route.queue ? [0, 1, 3] : [0, 1, 2, 3, 4, 5, 6, 7];
    }

    private filterLabels(): string[] {
        return this.route.portfolio ? ['全部作品', '已发布'] : this.filters().map((filter: number) => PHOTO_FILTER_LABELS[filter]);
    }

    private choose(photo: PhotoAsset): void {
        if (this.state.busy || this.route.submitting) {
            return;
        }
        if (!this.route.selecting) {
            this.route.offset = this.scroller.currentOffset().yOffset;
            this.view(new PhotoViewerRoute(photo.id, this.from, this.route, this.photos));
            return;
        }
        this.route.toggle(photo.id, this.photos);
    }

    @Builder controls() {
        Column({ space: 12 }) {
            Text('当前范围 ' + this.visiblePhotos.length + ' 张').fontSize(14).fontColor(Theme.muted)
            Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
                this.scopeControls()
                Select(this.filterLabels().map((label: string): SelectOption => {
                    return { value: label };
                }))
                    .selected(this.filters().indexOf(this.route.filter))
                    .value(this.filterLabels()[this.filters().indexOf(this.route.filter)] || this.filterLabels()[0])
                    .constraintSize({ minWidth: 140 })
                    .margin({ right: 8, bottom: 8 })
                    .enabled(!this.state.busy && !this.route.submitting).constraintSize({ minHeight: 48 })
                    .id(this.route.portfolio ? 'portfolio-status-filter' : 'photo-status-filter')
                    .onSelect((index: number): void => {
                        vibration.dotVibration();
                        this.route.setFilter(this.filters()[index]);
                    })
                    .accessibilityText('照片状态筛选')
            }.width('100%')
            if (this.route.selecting) {
                Row() {
                    Text('已选 ' + this.route.selectedIds.length + ' 张').fontSize(14).fontColor(Theme.ink).layoutWeight(1)
                }.width('100%')
                Row({ space: 12 }) {
                    Select(PHOTO_EDIT_STATUSES.map((status: PhotoStatus): SelectOption => {
                        return { value: '标为' + photoStatusLabel(status) };
                    }))
                        .value('标为' + photoStatusLabel(this.route.targetStatus))
                        .layoutWeight(1)
                        .constraintSize({ minHeight: 48 })
                        .enabled(!this.state.busy && !this.route.submitting)
                        .onSelect((index: number): void => {
                            this.route.targetStatus = PHOTO_EDIT_STATUSES[index];
                        }).accessibilityText('批量照片状态')
                }.width('100%')
            }
            if (this.route.feedback) {
                Text(this.route.feedback).id('photo-collection-feedback').fontSize(14).fontColor(Theme.accent)
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder photoContent(photo: PhotoAsset) {
        Column({ space: 6 }) {
            if (photo.thumbnailPath) {
                ManagedImage({ sourcePath: photo.thumbnailPath, label: this.state.projectName(photo.projectId) + '，' + photoStatusLabel(photo.status), failureText: '缩略图加载失败，可打开原图' })
                    .width('100%').aspectRatio(0.8).borderRadius(14).clip(true)
            } else {
                Text(photo.localPath ? '缩略图未建立，可打开原图' : '媒体待恢复')
                    .width('100%')
                    .aspectRatio(0.8)
                    .backgroundColor(Theme.surface)
                    .borderRadius(14)
                    .fontColor(Theme.muted)
                    .textAlign(TextAlign.Center)
            }
            Column({ space: 6 }) {
                if (this.route.selecting) {
                    Text(this.selectedPhotoIds.has(photo.id) ? '✓ 已选' : '○ 点选').fontSize(14).fontColor(Theme.accent)
                }
                StatusPill({ label: photoStatusLabel(photo.status) })
                if (!this.route.planId) {
                    Text(displayName(this.state.projectName(photo.projectId)))
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
            }.id('photo-caption:' + photo.id).width('100%').alignItems(HorizontalAlign.Start).padding({ left: 10, right: 10, top: 2, bottom: 10 })
        }.width('100%')
    }

    private columns(): number {
        return this.viewportWidth >= 720 ? 4 : this.viewportWidth >= 520 ? 3 : 2;
    }

    build() {
        List({ space: Theme.cardSpacing, scroller: this.scroller }) {
            ListItem() {
                Column() {
                    Blank().height(this.topInset > 0 ? this.topInset + Theme.sectionSpacing : 0).width('100%')
                    Column({ space: 12 }) {
                        this.header();
                        PhotoImportStatus({ state: this.state, projectId: this.route.planId });
                        this.controls()
                    }.width('100%').opacity(this.step() >= 1 ? 1 : 0)
                }.width('100%')
            }
            if (!this.visiblePhotos.length) {
                ListItem() {
                    Column({ space: 12 }) {
                        EmptyState({ title: this.route.portfolio ? '作品从第一张成片开始' : this.route.queue ? '这个范围没有待处理照片' : '这个范围还没有照片',
                            message: this.route.portfolio ? '成片与已发布使用同一份照片，参考图不计入作品。' : '可以调整筛选，或明确所属计划后导入。',
                            button: this.route.portfolio ? '打开相册' : '导入照片', action: (): void => {
                                if (this.route.portfolio) {
                                    this.showAlbum();
                                } else {
                                    this.addPhotos();
                                }
                            }
                        })
                        if (this.route.filter) {
                            Button('清除照片状态筛选').constraintSize({ minHeight: 48 }).onClick((): void => {
                                this.route.setFilter(0);
                            })
                        }
                    }.width('100%')
                }
            } else {
                LazyForEach(this.rowsSource, (row: PhotoAsset[]) => {
                    ListItem() {
                        Row({ space: 12 }) {
                            ForEach(row, (photo: PhotoAsset) => {
                                InteractiveCard({
                                    label: this.state.projectName(photo.projectId) + '，' + photoStatusLabel(photo.status), hint: this.route.selecting ? '双击切换照片选择' : '双击打开照片详情',
                                    effects: this.state.settings.effects, contentPadding: 0, action: (): void => {
                                        this.choose(photo);
                                    }, content: (): void => {
                                        this.photoContent(photo);
                                    }
                                }).id('photo-thumbnail:' + photo.id).layoutWeight(1)
                            }, (photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status)
                            ForEach(new Array<number>(Math.max(0, this.columns() - row.length)).fill(0), (_value: number) => {
                                Blank().layoutWeight(1)
                            }, (_value: number, index: number) => String(index))
                        }.width('100%').alignItems(VerticalAlign.Top).opacity(this.step() >= 2 ? 1 : 0)
                    }
                }, (row: PhotoAsset[]) => row.map((photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status).join('|'))
            }
            ListItem() {
                Column() {
                    Blank().height(this.bottomInset).width('100%')
                }.width('100%')
            }
        }.id(this.route.portfolio ? 'portfolio-photo-list' : 'photo-list')
            .width('100%')
            .constraintSize({ maxWidth: Theme.contentMaxWidth })
            .height('100%')
            .padding({ left: this.sidePadding, right: this.sidePadding }).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            .onAreaChange((_old: Area, area: Area): void => {
                this.viewportWidth = Number(area.width);
                this.viewportHeight = Number(area.height);
                if (!this.restored && this.viewportHeight > 0) {
                    this.restoreOffset();
                }
            })
            .onDidScroll((): void => {
                if (this.restored && !this.restoring) {
                    this.route.offset = this.scroller.currentOffset().yOffset;
                }
            })
    }
}
