import { StatusPill, EmptyState, InteractiveCard, PillTone } from '../components/Surfaces';
import { displayName } from '../utils/format';
import { PhotoImportStatus } from './PhotoImportStatus';
import { PHOTO_FILTER_LABELS, photoStatusLabel, PHOTO_EDIT_STATUSES } from '../models/PhotoStages';
import { PhotoCollectionRoute, PhotoViewerRoute, selectPhotoCollection } from '../viewmodels/PhotoCollection';
import { StaggerEntrance } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { ManagedImage } from '../components/ManagedImage';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { ArrayDataSource } from '../models/ArrayDataSource';
import { photoColumnCount } from '../ui/responsive';
import { groupPhotoRows, indexPhotoRows, changedPhotoRows } from '../models/PhotoRows';
import { PhotoAsset, PhotoStatus } from '../models/Entities';
import { vibration } from '../ui/vibration';

@ComponentV2
export struct PhotoGrid {
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

    @Local columnCount: number = 2;
    private rowsSource: ArrayDataSource<PhotoAsset[]> = new ArrayDataSource<PhotoAsset[]>([]);
    private rowIndexes: Map<string, number> = new Map<string, number>();
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
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
    }

    @Monitor('photos', 'route', 'route.filter', 'route.portfolio', 'route.queue', 'route.planId', 'columnCount')
    private refreshRows(): void {
        this.rowsSource.replace(this.photoRows);
        this.rowIndexes = indexPhotoRows(this.photoRows);
        this.previousSelection = new Set<string>(this.route.selectedIds);
        this.previousSelecting = this.route.selecting;
    }

    private previousSelection: Set<string> = new Set<string>();
    private previousSelecting: boolean = false;

    @Monitor('route.selecting', 'route.selectedIds')
    private selectionChanged(): void {
        const next = this.selectedPhotoIds;
        if (this.previousSelecting !== this.route.selecting) {
            for (let index = 0; index < this.rowsSource.totalCount(); index++) {
                this.rowsSource.changed(index);
            }
        } else {
            changedPhotoRows(this.rowIndexes, this.previousSelection, next).forEach((index: number): void => {
                this.rowsSource.changed(index);
            });
        }
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

    private photoTone(status: PhotoStatus): PillTone {
        if (status === PhotoStatus.FINAL || status === PhotoStatus.PUBLISHED || status === PhotoStatus.RETOUCHED) {
            return 'success';
        }
        if (status === PhotoStatus.WAITING || status === PhotoStatus.SELECTED) {
            return 'warning';
        }
        if (status === PhotoStatus.ARCHIVED) {
            return 'neutral';
        }
        return 'brand';
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
        Column({ space: 10 }) {
            Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
                this.scopeControls()
                Select(this.filterLabels().map((label: string): SelectOption => {
                    return { value: label };
                }))
                    .selected(this.filters().indexOf(this.route.filter))
                    .value(this.filterLabels()[this.filters().indexOf(this.route.filter)] || this.filterLabels()[0])
                    .constraintSize({ minWidth: 132, minHeight: 36 })
                    .margin({ right: 8, bottom: 8 })
                    .backgroundColor(Theme.surface)
                    .borderRadius(12)
                    .enabled(!this.state.busy && !this.route.submitting)
                    .id(this.route.portfolio ? 'portfolio-status-filter' : 'photo-status-filter')
                    .onSelect((index: number): void => {
                        vibration.dotVibration();
                        this.route.setFilter(this.filters()[index]);
                    })
                    .accessibilityText('照片状态筛选')
                    .controlSize(ControlSize.SMALL)
                    .font({ size: 13 })
                Text('共 ' + this.visiblePhotos.length + ' 张')
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .margin({ bottom: 8 })
            }.width('100%')
            if (this.route.selecting) {
                Row({ space: 10 }) {
                    Text('已选 ' + this.route.selectedIds.length + ' 张')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.ink)
                    Select(PHOTO_EDIT_STATUSES.map((status: PhotoStatus): SelectOption => {
                        return { value: '标为' + photoStatusLabel(status) };
                    }))
                        .value('标为' + photoStatusLabel(this.route.targetStatus))
                        .layoutWeight(1)
                        .constraintSize({ minHeight: 36 })
                        .backgroundColor(Theme.surface)
                        .borderRadius(12)
                        .enabled(!this.state.busy && !this.route.submitting)
                        .onSelect((index: number): void => {
                            vibration.dotVibration();
                            this.route.targetStatus = PHOTO_EDIT_STATUSES[index];
                        })
                        .accessibilityText('批量照片状态')
                        .controlSize(ControlSize.SMALL)
                        .font({ size: 13 })
                }.width('100%')
                    .padding(10)
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.line })
            }
            if (this.route.feedback) {
                Text(this.route.feedback)
                    .id('photo-collection-feedback')
                    .fontSize(13)
                    .fontColor(Theme.accent)
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder photoContent(photo: PhotoAsset) {
        Column({ space: 6 }) {
            Stack({ alignContent: Alignment.TopEnd }) {
                if (photo.thumbnailPath) {
                    ManagedImage({
                        sourcePath: photo.thumbnailPath,
                        label: this.state.projectName(photo.projectId) + '，' + photoStatusLabel(photo.status),
                        failureText: '缩略图加载失败，可打开原图',
                        radius: Theme.slotRadius,
                    }).width('100%').aspectRatio(0.8)
                } else {
                    Column({ space: 4 }) {
                        SymbolGlyph(Icons.importPhoto)
                            .fontSize(22)
                            .fontColor([Theme.muted])
                            .accessibilityLevel('no')
                        Text(photo.localPath ? '缩略图未建' : '媒体待恢复')
                            .fontSize(11)
                            .fontColor(Theme.muted)
                    }.width('100%')
                        .aspectRatio(0.8)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(HorizontalAlign.Center)
                        .backgroundColor(Theme.tint)
                        .borderRadius(Theme.slotRadius)
                }
                if (this.route.selecting) {
                    Stack({ alignContent: Alignment.Center }) {
                        SymbolGlyph(this.selectedPhotoIds.has(photo.id) ? Icons.done : Icons.pending)
                            .fontSize(18)
                            .fontColor([this.selectedPhotoIds.has(photo.id) ? Theme.onAccent : Theme.onAccent])
                            .accessibilityLevel('no')
                    }.width(26)
                        .height(26)
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(this.selectedPhotoIds.has(photo.id) ? Theme.brand : Theme.scrim)
                        .margin(8)
                }
            }.width('100%')
                .borderRadius(Theme.slotRadius)
                .clip(true)
                .border(this.route.selecting && this.selectedPhotoIds.has(photo.id) ?
                    { width: 2, color: Theme.brand } :
                    { width: 0, color: Theme.transparent })
            Column({ space: 4 }) {
                StatusPill({
                    label: photoStatusLabel(photo.status),
                    tone: this.photoTone(photo.status),
                    compact: true,
                })
                if (!this.route.planId) {
                    Text(displayName(this.state.projectName(photo.projectId)))
                        .fontSize(12)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
            }.id('photo-caption:' + photo.id)
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 8, right: 8, top: 2, bottom: 8 })
        }.width('100%')
    }

    private columns(): number {
        return this.columnCount;
    }

    build() {
        List({ space: Theme.cardSpacing, scroller: this.scroller }) {
            ListItem() {
                Column() {
                    Blank().height(this.topInset > 0 ? this.topInset + 8 : 0).width('100%')
                    Column({ space: 10 }) {
                        this.header();
                        PhotoImportStatus({ state: this.state, projectId: this.route.planId });
                        this.controls()
                    }.width('100%').opacity(this.step() >= 1 ? 1 : 0)
                }.width('100%')
            }
            if (!this.visiblePhotos.length) {
                ListItem() {
                    Column({ space: 12 }) {
                        EmptyState({
                            title: this.route.portfolio ? '作品从第一张成片开始' : this.route.queue ? '这个范围没有待处理照片' : '这个范围还没有照片',
                            message: this.route.portfolio ? '成片与已发布使用同一份照片，参考图不计入作品。' : '可以调整筛选，或明确所属计划后导入。',
                            button: this.route.portfolio ? '打开相册' : '导入照片',
                            icon: Icons.importPhoto,
                            action: (): void => {
                                if (this.route.portfolio) {
                                    this.showAlbum();
                                } else {
                                    this.addPhotos();
                                }
                            },
                        })
                        if (this.route.filter) {
                            Button('清除照片状态筛选', { type: ButtonType.Normal, stateEffect: false })
                                .height(38)
                                .padding({ left: 16, right: 16 })
                                .borderRadius(Theme.controlRadius)
                                .backgroundColor(Theme.tint)
                                .fontSize(13)
                                .fontColor(Theme.accent)
                                .onClick((): void => {
                                    vibration.dotVibration();
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
                                    label: this.state.projectName(photo.projectId) + '，' + photoStatusLabel(photo.status),
                                    hint: this.route.selecting ? '双击切换照片选择' : '双击打开照片详情',
                                    effects: this.state.settings.effects,
                                    contentPadding: 0,
                                    action: (): void => {
                                        this.choose(photo);
                                    },
                                    content: (): void => {
                                        this.photoContent(photo);
                                    },
                                }).id('photo-thumbnail:' + photo.id).layoutWeight(1)
                            }, (photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status)
                            ForEach(new Array<number>(Math.max(0, this.columns() - row.length)).fill(0), (_value: number) => {
                                Blank().layoutWeight(1)
                            }, (_value: number, index: number) => String(index))
                        }.width('100%')
                            .alignItems(VerticalAlign.Top)
                            .opacity(this.step() >= 2 ? 1 : 0)
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
            .padding({ left: this.sidePadding, right: this.sidePadding })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onAreaChange((_old: Area, area: Area): void => {
                const count = photoColumnCount(Number(area.width));
                if (count !== this.columnCount) {
                    this.columnCount = count;
                }
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
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
