import { curves, SymbolGlyphModifier } from '@kit.ArkUI';
import { EmptyState } from '../components/Surfaces';
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
import { PhotoAsset, PhotoStatus } from '../models/Entities';
import { vibration } from '../ui/vibration';

@ComponentV2
struct PhotoGridTile {
    @Require @Param state: AppState;
    @Require @Param photo: PhotoAsset;
    @Require @Param route: PhotoCollectionRoute;
    @Param canBatchSelect: boolean = false;
    @Event choose: (photo: PhotoAsset) => void = () => {};
    @Event openViewer: (photo: PhotoAsset) => void = () => {};
    @Event toggleBatchSelect: (photo: PhotoAsset) => void = () => {};
    @Event setCover: (photo: PhotoAsset) => void = () => {};
    @Event removePhoto: (id: string) => void = () => {};
    @Local pressed: boolean = false;
    @Local menuShown: boolean = false;
    private longPressTriggered: boolean = false;

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length && !this.route.submitting;
    }

    private selected(): boolean {
        return this.route.selecting && this.route.selectedIds.includes(this.photo.id);
    }

    @Builder photoMenu() {
        Menu() {
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.tabPhoto).fontSize(18).fontColor([Theme.accent]),
                content: '查看原图',
            }).onClick((): void => {
                this.menuShown = false;
                vibration.dotVibration();
                this.openViewer(this.photo);
            })
            if (this.canBatchSelect) {
                MenuItem({
                    symbolStartIcon: new SymbolGlyphModifier(this.selected() ? Icons.closeCircle : Icons.selectCircle)
                        .fontSize(18)
                        .fontColor([Theme.ink]),
                    content: this.selected() ? '取消选中' : '批量选择',
                }).enabled(!this.route.submitting)
                    .onClick((): void => {
                        this.menuShown = false;
                        vibration.dotVibration();
                        this.toggleBatchSelect(this.photo);
                    })
            }
            if (this.photo.thumbnailPath) {
                MenuItem({
                    symbolStartIcon: new SymbolGlyphModifier(Icons.starFill).fontSize(18).fontColor([Theme.warning]),
                    content: '设为角色封面',
                }).enabled(this.writable())
                    .onClick((): void => {
                        this.menuShown = false;
                        vibration.dotVibration();
                        this.setCover(this.photo);
                    })
            }
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(this.photo.status !== PhotoStatus.FINAL ? Icons.done : Icons.pending)
                    .fontSize(18)
                    .fontColor([this.photo.status !== PhotoStatus.FINAL ? Theme.success : Theme.warning]),
                content: this.photo.status !== PhotoStatus.FINAL ? '标为成片' : '标为待修',
            }).enabled(this.writable())
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    void this.state.setPhotoStatus(
                        this.photo,
                        this.photo.status !== PhotoStatus.FINAL ? PhotoStatus.FINAL : PhotoStatus.WAITING,
                    );
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.remove).fontSize(18).fontColor([Theme.danger]),
                content: '删除照片',
            }).contentFontColor(Theme.danger)
                .enabled(this.writable())
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.removePhoto(this.photo.id);
                })
        }
    }

    private statusColor(status: PhotoStatus): Resource {
        if (status === PhotoStatus.FINAL || status === PhotoStatus.PUBLISHED || status === PhotoStatus.RETOUCHED) {
            return Theme.success;
        }
        if (status === PhotoStatus.WAITING || status === PhotoStatus.SELECTED) {
            return Theme.warning;
        }
        if (status === PhotoStatus.ARCHIVED) {
            return Theme.muted;
        }
        return Theme.accent;
    }

    build() {
        Column({ space: 0 }) {
            Stack({ alignContent: Alignment.Center }) {
                if (this.photo.thumbnailPath) {
                    ManagedImage({
                        sourcePath: this.photo.thumbnailPath,
                        label: this.state.projectName(this.photo.projectId) + '，' + photoStatusLabel(this.photo.status),
                        failureText: '缩略图加载失败，可打开原图',
                        ratio: 0,
                        radius: 0,
                    }).width('100%')
                } else {
                    Column({ space: 6 }) {
                        SymbolGlyph(Icons.importPhoto)
                            .fontSize(24)
                            .fontColor([Theme.muted])
                            .accessibilityLevel('no')
                        Text(this.photo.localPath ? '缩略图生成中' : '原图待恢复')
                            .fontSize(11)
                            .fontColor(Theme.muted)
                    }.width('100%')
                        .aspectRatio(0.85)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(HorizontalAlign.Center)
                        .backgroundColor(Theme.tint)
                }
                if (this.route.selecting) {
                    Stack({ alignContent: Alignment.Center }) {
                        SymbolGlyph(this.selected() ? Icons.done : Icons.pending)
                            .fontSize(16)
                            .fontColor([Theme.onAccent])
                            .accessibilityLevel('no')
                    }.width(24)
                        .height(24)
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(this.selected() ? Theme.brand : Theme.scrim)
                        .position({ right: 8, top: 8 })
                        .hitTestBehavior(HitTestMode.None)
                }
            }.width('100%')
                .clip(true)
            Column({ space: 5 }) {
                if (this.photo.caption.trim() || !this.route.planId) {
                    Text(displayName(this.photo.caption.trim() || this.state.projectName(this.photo.projectId)))
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.ink)
                        .lineHeight(18)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                Row({ space: 5 }) {
                    Row() {
                    }.width(6)
                        .height(6)
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(this.statusColor(this.photo.status))
                    Text(photoStatusLabel(this.photo.status))
                        .fontSize(11)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                    Blank().layoutWeight(1)
                    if (this.photo.caption.trim() && !this.route.planId) {
                        Text(displayName(this.state.projectName(this.photo.projectId)))
                            .fontSize(11)
                            .fontColor(Theme.muted)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .constraintSize({ maxWidth: '58%' })
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            }.id('photo-caption:' + this.photo.id)
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 9, right: 9, top: 7, bottom: 9 })
        }.id('photo-thumbnail:' + this.photo.id)
            .width('100%')
            .backgroundColor(Theme.surface)
            .border(this.selected() ?
                { width: 2, color: Theme.brand, radius: Theme.cardRadius } :
                { width: 0.6, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
            .clip(true)
            .scale({ x: this.pressed ? 0.98 : 1, y: this.pressed ? 0.98 : 1 })
            .animation({ duration: 120, curve: curves.springMotion(0.35, 0.9) })
            .onTouch((event: TouchEvent): void => {
                if (event.type === TouchType.Down) {
                    this.pressed = true;
                    this.longPressTriggered = false;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressed = false;
                }
            })
            .gesture(
                LongPressGesture({ duration: 350 })
                    .onAction((): void => {
                        this.longPressTriggered = true;
                        this.pressed = false;
                        vibration.lightVibration();
                        this.menuShown = true;
                    })
            )
            .onClick((): void => {
                if (this.longPressTriggered) {
                    this.longPressTriggered = false;
                    return;
                }
                vibration.dotVibration();
                this.choose(this.photo);
            })
            .bindContextMenu(this.menuShown, this.photoMenu, {
                preview: MenuPreviewMode.IMAGE,
                aboutToDisappear: (): void => {
                    this.menuShown = false;
                },
                onDisappear: (): void => {
                    this.menuShown = false;
                },
            })
            .focusable(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(this.state.projectName(this.photo.projectId) + '，' + photoStatusLabel(this.photo.status))
            .accessibilityDescription(this.route.selecting ? (this.selected() ? '已选中，双击取消选择' : '双击选中此照片') : '双击打开照片详情')
            .accessibilityLevel('yes')
    }
}

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
    @Event applySelection: () => void = () => {};
    @Event setCover: (photo: PhotoAsset) => void = () => {};
    @Event removePhoto: (id: string) => void = () => {};
    @Param topInset: number = 0;
    @Param bottomInset: number = 20;
    @Param sidePadding: number = 0;
    @BuilderParam scopeControls: () => void = this.emptyHeader;
    @BuilderParam header: () => void = this.emptyHeader;

    @Builder emptyHeader() {
    }

    @Local columnCount: number = 2;
    @Local userColumns: number = 0;
    private photoSource: ArrayDataSource<PhotoAsset> = new ArrayDataSource<PhotoAsset>([]);
    private restoreTimer: number = -1;
    private restoring: boolean = false;
    private restored: boolean = false;
    private viewportHeight: number = 0;

    aboutToAppear(): void {
        this.route.reconcile(this.photos);
        this.syncPhotoSource();
        this.restoreOffset();
    }

    aboutToDisappear(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
    }

    @Monitor('photos', 'route', 'route.filter', 'route.portfolio', 'route.queue', 'route.planId')
    private syncPhotoSource(): void {
        this.photoSource.replace(this.visiblePhotos);
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

    private columns(): number {
        return Math.min(4, Math.max(2, this.columnCount));
    }

    private columnsTemplate(): string {
        return new Array<string>(this.columns()).fill('1fr').join(' ');
    }

    private applyColumns(next: number): void {
        const clamped = Math.min(4, Math.max(2, next));
        if (clamped === this.columnCount && this.userColumns === clamped) {
            return;
        }
        vibration.dotVibration();
        this.getUIContext().animateTo({ duration: 220, curve: curves.springMotion(0.4, 0.9) }, (): void => {
            this.userColumns = clamped;
            this.columnCount = clamped;
        });
    }

    private cycleColumns(): void {
        const current = this.columns();
        const next = current >= 4 ? 2 : current + 1;
        this.applyColumns(next);
    }

    private filters(): number[] {
        return this.route.portfolio ? [0, 7] : this.route.queue ? [0, 1, 3] : [0, 1, 2, 3, 4, 5, 7, 6];
    }

    private filterLabel(filter: number): string {
        if (this.route.portfolio) {
            return filter === 7 ? '已发布' : '全部成片';
        }
        return PHOTO_FILTER_LABELS[filter] || '全部';
    }

    private allVisibleSelected(): boolean {
        if (!this.visiblePhotos.length) {
            return false;
        }
        const selected = new Set<string>(this.route.selectedIds);
        return this.visiblePhotos.every((photo: PhotoAsset) => selected.has(photo.id));
    }

    private canBatchSelect(): boolean {
        return !this.state.busy && !this.route.submitting && this.visiblePhotos.length > 0 && !!(this.route.planId || this.route.queue);
    }

    private toggleSelectionMode(): void {
        if (this.route.submitting) {
            return;
        }
        vibration.dotVibration();
        if (this.route.selecting) {
            this.route.selecting = false;
            this.route.clearSelection();
        } else {
            this.route.selecting = true;
            this.route.clearSelection();
        }
    }

    private openPhotoViewer(photo: PhotoAsset): void {
        if (this.state.busy || this.route.submitting) {
            return;
        }
        this.route.offset = this.scroller.currentOffset().yOffset;
        this.view(new PhotoViewerRoute(photo.id, this.from, this.route, this.photos));
    }

    private toggleBatchItem(photo: PhotoAsset): void {
        if (this.route.submitting || !this.canBatchSelect()) {
            return;
        }
        if (!this.route.selecting) {
            this.route.selecting = true;
            this.route.clearSelection();
        }
        this.route.toggle(photo.id, this.photos);
    }

    private choose(photo: PhotoAsset): void {
        if (this.state.busy || this.route.submitting) {
            return;
        }
        if (!this.route.selecting) {
            this.openPhotoViewer(photo);
            return;
        }
        this.route.toggle(photo.id, this.photos);
    }

    @Builder controls() {
        Column({ space: 8 }) {
            Column() {
                Row({ space: 8 }) {
                    this.scopeControls()
                    Scroll() {
                        Row({ space: 6 }) {
                            ForEach(this.filters(), (filter: number) => {
                                Button(this.filterLabel(filter), { type: ButtonType.Capsule, stateEffect: false })
                                    .height(34)
                                    .padding({ left: 12, right: 12 })
                                    .fontSize(12)
                                    .fontWeight(this.route.filter === filter ? FontWeight.Medium : FontWeight.Regular)
                                    .backgroundColor(this.route.filter === filter ? Theme.brand : Theme.tint)
                                    .fontColor(this.route.filter === filter ? Theme.onAccent : Theme.ink)
                                    .border({ width: 0.8, color: this.route.filter === filter ? Theme.brand : Theme.line, radius: Theme.pillRadius })
                                    .borderRadius(Theme.pillRadius)
                                    .enabled(!this.state.busy && !this.route.submitting)
                                    .onClick((): void => {
                                        vibration.dotVibration();
                                        const next = filter !== 0 && this.route.filter === filter ? 0 : filter;
                                        this.route.setFilter(next);
                                    })
                                    .accessibilityText('筛选' + this.filterLabel(filter))
                            }, (filter: number) => String(filter))
                        }.padding({ right: 4 })
                    }.id(this.route.portfolio ? 'portfolio-status-filter' : 'photo-status-filter')
                        .layoutWeight(1)
                        .scrollable(ScrollDirection.Horizontal)
                        .scrollBar(BarState.Off)
                        .edgeEffect(EdgeEffect.Spring)
                    Button(this.columns() + '列', { type: ButtonType.Capsule, stateEffect: false })
                        .id('photo-column-toggle')
                        .height(34)
                        .padding({ left: 10, right: 10 })
                        .backgroundColor(Theme.tint)
                        .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                        .borderRadius(Theme.pillRadius)
                        .fontSize(12)
                        .fontColor(Theme.muted)
                        .onClick((): void => {
                            this.cycleColumns();
                        })
                        .accessibilityText('当前每行显示 ' + this.columns() + ' 列，点击切换列数，也支持双指捏合缩放')
                    if (this.canBatchSelect() || this.route.selecting) {
                        Button({ type: ButtonType.Capsule, stateEffect: false }) {
                            Row({ space: 4 }) {
                                SymbolGlyph(this.route.selecting ? Icons.closeCircle : Icons.selectCircle)
                                    .fontSize(16)
                                    .fontColor([this.route.selecting ? Theme.ink : Theme.accent])
                                    .accessibilityLevel('no')
                                Text(this.route.selecting ? '关闭' : '选择')
                                    .fontSize(12)
                                    .fontWeight(FontWeight.Medium)
                                    .fontColor(this.route.selecting ? Theme.ink : Theme.accent)
                            }.padding({ left: 10, right: 10 })
                        }.id(this.route.selecting ? 'photo-select-cancel' : 'photo-batch-toggle')
                            .height(34)
                            .backgroundColor(Theme.tint)
                            .border({ width: 0.8, color: this.route.selecting ? Theme.divider : Theme.line, radius: Theme.pillRadius })
                            .borderRadius(Theme.pillRadius)
                            .enabled(!this.route.submitting)
                            .onClick((): void => {
                                this.toggleSelectionMode();
                            })
                            .accessibilityText(this.route.selecting ? '关闭多选模式' : '进入照片多选模式')
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            }.id('photo-filter-panel')
                .width('100%')
                .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .backgroundColor(Theme.surface)
                .border({ width: 1, color: Theme.line, radius: Theme.cardRadius })
                .borderRadius(Theme.cardRadius)
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            if (this.route.selecting) {
                Row({ space: 8 }) {
                    Text('已选 ' + this.route.selectedIds.length)
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.accent)
                        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(Theme.tint)
                    Button(this.allVisibleSelected() ? '全不选' : '全选', { type: ButtonType.Capsule, stateEffect: false })
                        .id('photo-select-all')
                        .height(34)
                        .padding({ left: 10, right: 10 })
                        .backgroundColor(Theme.tint)
                        .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                        .borderRadius(Theme.pillRadius)
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.ink)
                        .enabled(!this.route.submitting && this.visiblePhotos.length > 0)
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.route.selectAll(this.photos);
                        })
                        .accessibilityText(this.allVisibleSelected() ? '取消全选当前照片' : '全选当前筛选照片')
                    Select(PHOTO_EDIT_STATUSES.map((status: PhotoStatus): SelectOption => {
                        return { value: '标为' + photoStatusLabel(status) };
                    }))
                        .value('标为' + photoStatusLabel(this.route.targetStatus))
                        .layoutWeight(1)
                        .height(34)
                        .constraintSize({ minHeight: 34 })
                        .backgroundColor(Theme.tint)
                        .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                        .borderRadius(Theme.pillRadius)
                        .clip(true)
                        .enabled(!this.state.busy && !this.route.submitting)
                        .onSelect((index: number): void => {
                            vibration.dotVibration();
                            this.route.targetStatus = PHOTO_EDIT_STATUSES[index];
                        })
                        .accessibilityText('选择要应用的照片状态')
                        .controlSize(ControlSize.SMALL)
                        .font({ size: 12 })
                    Button(this.route.submitting ? '应用中' : '应用', { type: ButtonType.Capsule, stateEffect: false })
                        .id('photo-select-apply')
                        .height(34)
                        .padding({ left: 14, right: 14 })
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(this.route.selectedIds.length > 0 && !this.route.submitting ? Theme.brand : Theme.tint)
                        .fontColor(this.route.selectedIds.length > 0 && !this.route.submitting ? Theme.onAccent : Theme.muted)
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .enabled(!this.state.busy && !this.route.submitting && this.route.selectedIds.length > 0)
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.applySelection();
                        })
                        .accessibilityText('将目标状态应用到已选照片')
                }.width('100%')
                    .padding(10)
                    .backgroundColor(Theme.surface)
                    .border({ width: 1, color: Theme.brand, radius: Theme.cardRadius })
                    .borderRadius(Theme.cardRadius)
                    .alignItems(VerticalAlign.Center)
            }
            if (this.route.feedback) {
                Text(this.route.feedback)
                    .id('photo-collection-feedback')
                    .fontSize(12)
                    .fontColor(Theme.accent)
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder bottomFooter() {
        Column() {
            Blank().height(this.bottomInset).width('100%')
        }.width('100%')
    }

    build() {
        Column({ space: 0 }) {
            Column({ space: 8 }) {
                Blank().height(this.topInset > 0 ? this.topInset + 4 : 0).width('100%')
                this.header();
                PhotoImportStatus({ state: this.state, projectId: this.route.planId });
                this.controls()
            }.width('100%')
                .constraintSize({ maxWidth: Theme.contentMaxWidth })
                .padding({ left: this.sidePadding, right: this.sidePadding, bottom: 8 })
                .opacity(this.step() >= 1 ? 1 : 0)
            if (!this.visiblePhotos.length) {
                Scroll() {
                    Column({ space: 12 }) {
                        EmptyState({
                            title: this.route.portfolio ? '成片区暂时空着' : this.route.queue ? '暂无待修照片' : '这个范围还没有照片',
                            message: this.route.portfolio ? '照片标记为「成片」或「已发布」后会自动出现在这里。' : this.route.queue ? '全部照片已完成修图或等待选片，可导入新照片继续。' : '可以切换上方筛选，或导入照片到所属计划。',
                            button: this.route.portfolio ? '查看全部相册' : '导入照片',
                            icon: this.route.portfolio ? Icons.camera : Icons.add,
                            action: (): void => {
                                if (this.route.portfolio) {
                                    this.showAlbum();
                                } else {
                                    this.addPhotos();
                                }
                            },
                        })
                        if (this.route.filter) {
                            Button('查看全部状态', { type: ButtonType.Capsule, stateEffect: false })
                                .height(36)
                                .padding({ left: 16, right: 16 })
                                .backgroundColor(Theme.tint)
                                .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                                .borderRadius(Theme.pillRadius)
                                .fontSize(13)
                                .fontColor(Theme.accent)
                                .onClick((): void => {
                                    vibration.dotVibration();
                                    this.route.setFilter(0);
                                })
                        }
                        Blank().height(this.bottomInset).width('100%')
                    }.width('100%')
                        .constraintSize({ maxWidth: Theme.contentMaxWidth })
                        .padding({ left: this.sidePadding, right: this.sidePadding, top: 8 })
                        .alignItems(HorizontalAlign.Center)
                }.layoutWeight(1)
                    .width('100%')
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
            } else {
                WaterFlow({
                    scroller: this.scroller,
                    footer: this.bottomFooter,
                    layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW,
                }) {
                    LazyForEach(this.photoSource, (photo: PhotoAsset) => {
                        FlowItem() {
                            PhotoGridTile({
                                state: this.state,
                                photo: photo,
                                route: this.route,
                                canBatchSelect: this.canBatchSelect(),
                                choose: (target: PhotoAsset): void => {
                                    this.choose(target);
                                },
                                openViewer: (target: PhotoAsset): void => {
                                    this.openPhotoViewer(target);
                                },
                                toggleBatchSelect: (target: PhotoAsset): void => {
                                    this.toggleBatchItem(target);
                                },
                                setCover: (target: PhotoAsset): void => {
                                    this.setCover(target);
                                },
                                removePhoto: (id: string): void => {
                                    this.removePhoto(id);
                                },
                            })
                        }.width('100%')
                            .opacity(this.step() >= 2 ? 1 : 0)
                    }, (photo: PhotoAsset) => photo.id + ':' + photo.thumbnailPath + ':' + photo.status)
                }.id(this.route.portfolio ? 'portfolio-photo-list' : 'photo-list')
                    .layoutWeight(1)
                    .width('100%')
                    .constraintSize({ maxWidth: Theme.contentMaxWidth })
                    .padding({ left: this.sidePadding, right: this.sidePadding })
                    .columnsTemplate(this.columnsTemplate())
                    .columnsGap(8)
                    .rowsGap(10)
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
                    .priorityGesture(
                        PinchGesture({ fingers: 2, distance: 10 })
                            .onActionEnd((event: GestureEvent): void => {
                                if (!event) {
                                    return;
                                }
                                if (event.scale > 1.15 && this.columns() > 2) {
                                    this.applyColumns(this.columns() - 1);
                                } else if (event.scale < 0.85 && this.columns() < 4) {
                                    this.applyColumns(this.columns() + 1);
                                }
                            })
                    )
                    .onAreaChange((_old: Area, area: Area): void => {
                        if (this.userColumns === 0) {
                            const count = Math.min(4, Math.max(2, photoColumnCount(Number(area.width))));
                            if (count !== this.columnCount) {
                                this.columnCount = count;
                            }
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
        }.width('100%')
            .height('100%')
            .alignItems(HorizontalAlign.Center)
    }
}
