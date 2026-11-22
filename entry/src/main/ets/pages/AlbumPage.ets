import { curves, SymbolGlyphModifier } from '@kit.ArkUI';
import { ArrayDataSource } from '../models/ArrayDataSource';
import { EmptyState } from '../components/Surfaces';
import { displayName } from '../utils/format';
import { PhotoImportStatus } from '../views/PhotoImportStatus';
import { photoColumnCount } from '../ui/responsive';
import { AppState } from '../viewmodels/ApplicationState';
import { AlbumRoute } from '../viewmodels/AlbumRoute';
import { AlbumPlan } from '../models/AlbumSummary';
import { PhotoCollectionRoute, PhotoViewerRoute, selectPhotoCollection } from '../viewmodels/PhotoCollection';
import { PHOTO_STAGE_LABELS, PHOTO_FILTER_LABELS } from '../models/PhotoStages';
import { CosProject, PhotoAsset } from '../models/Entities';
import { StaggerEntrance, MainEntranceSession } from '../ui/motion';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { DistributionChart } from '../components/DistributionChart';
import { PhotoDistributionItem } from '../models/Statistics';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { PhotoGrid } from '../views/PhotoGrid';
import { ManagedImage } from '../components/ManagedImage';

@ComponentV2
struct AlbumPlanTile {
    @Require @Param plan: AlbumPlan;
    @Param canImport: boolean = true;
    @Event open: () => void = () => {};
    @Event importPhotos: () => void = () => {};
    @Event openProject: () => void = () => {};
    @Local pressed: boolean = false;
    @Local menuShown: boolean = false;
    private longPressTriggered: boolean = false;

    @Builder planMenu() {
        Menu() {
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.tabPhoto).fontSize(18).fontColor([Theme.accent]),
                content: '打开相册',
            }).onClick((): void => {
                this.menuShown = false;
                vibration.dotVibration();
                this.open();
            })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.add).fontSize(18).fontColor([Theme.ink]),
                content: '导入照片',
            }).enabled(this.canImport)
                .onClick((): void => {
                    this.menuShown = false;
                    vibration.dotVibration();
                    this.importPhotos();
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.plan).fontSize(18).fontColor([Theme.ink]),
                content: '查看所属计划',
            }).onClick((): void => {
                this.menuShown = false;
                vibration.dotVibration();
                this.openProject();
            })
        }
    }

    build() {
        Column({ space: 0 }) {
            if (this.plan.cover?.thumbnailPath) {
                ManagedImage({
                    sourcePath: this.plan.cover.thumbnailPath,
                    label: this.plan.name + '封面',
                    failureText: '封面缩略图加载失败',
                    ratio: 0,
                    radius: 0,
                }).width('100%')
            } else {
                Column({ space: 6 }) {
                    SymbolGlyph(Icons.camera)
                        .fontSize(26)
                        .fontColor([Theme.muted])
                        .accessibilityLevel('no')
                    Text(this.plan.total ? '缩略图待恢复' : '暂无照片')
                        .fontSize(11)
                        .fontColor(Theme.muted)
                }.width('100%')
                    .aspectRatio(0.95)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)
                    .backgroundColor(Theme.tint)
            }
            Column({ space: 6 }) {
                Text(displayName(this.plan.name))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.ink)
                    .lineHeight(19)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 6 }) {
                    SymbolGlyph(Icons.event)
                        .fontSize(11)
                        .fontColor([Theme.muted])
                        .accessibilityLevel('no')
                    Text(displayName(this.plan.event || this.plan.date || '独立计划'))
                        .fontSize(11)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                    if (this.plan.counts[2] > 0) {
                        Text('待修 ' + this.plan.counts[2])
                            .fontSize(11)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.warning)
                            .flexShrink(0)
                    } else {
                        Row({ space: 3 }) {
                            SymbolGlyph(Icons.camera)
                                .fontSize(11)
                                .fontColor([Theme.muted])
                                .accessibilityLevel('no')
                            Text(String(this.plan.total))
                                .fontSize(11)
                                .fontColor(Theme.muted)
                        }.alignItems(VerticalAlign.Center)
                            .flexShrink(0)
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            }.width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 10, right: 10, top: 8, bottom: 10 })
        }.id('album-plan:' + this.plan.id)
            .width('100%')
            .backgroundColor(Theme.surface)
            .border({ width: 0.6, color: Theme.line, radius: Theme.cardRadius })
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
                this.open();
            })
            .bindContextMenu(this.menuShown, this.planMenu, {
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
            .accessibilityText('打开相册计划 ' + this.plan.name + '，共 ' + this.plan.total + ' 张照片')
            .accessibilityLevel('yes')
    }
}

@ComponentV2
export struct AlbumPage {
    @Require @Param state: AppState;
    @Require @Param route: AlbumRoute;
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    @Param entranceSession: MainEntranceSession = new MainEntranceSession();
    @Param active: boolean = true;
    @Param topInset: number = Theme.detailTop;
    @Param bottomInset: number = Theme.contentBottom;
    @Event view: (route: PhotoViewerRoute) => void = () => {};
    @Event importPhotos: (planId: string) => void = () => {};
    @Event openPlan: (planId: string) => void = () => {};
    @Event openProject: (planId: string) => void = () => {};
    @Event setCover: (photo: PhotoAsset) => void = () => {};
    @Event removePhoto: (id: string) => void = () => {};
    @Event applySelection: (route: PhotoCollectionRoute) => void = () => {};
    @Param scroller: Scroller = new Scroller();
    @Local distributionOpen: boolean = false;
    @Local columnCount: number = 2;
    @Local userColumns: number = 0;
    private planSource: ArrayDataSource<AlbumPlan> = new ArrayDataSource<AlbumPlan>([]);
    private entered: boolean = false;
    private restoreTimer: number = -1;
    private restoring: boolean = false;
    private measured: boolean = false;

    aboutToAppear(): void {
        this.route.reconcile(this.state.projects, this.state.photos);
        this.syncPlanSource();
        this.restoreOffset();
        if (this.active) {
            this.enter();
        }
    }

    private enter(): void {
        if (this.entrance.managed || this.entered) {
            return;
        }
        this.entered = true;
        if (this.entranceSession.claim('AlbumPage')) {
            this.entrance.play(this.getUIContext());
        } else {
            this.entrance.finish(4);
        }
    }

    @Monitor('active')
    activeChanged(): void {
        if (this.active) {
            this.enter();
            this.route.restoreVersion++;
            this.route.collection.restoreVersion++;
        }
    }

    @Monitor('state.projects', 'state.photos')
    dataChanged(): void {
        this.route.reconcile(this.state.projects, this.state.photos);
        this.syncPlanSource();
    }

    @Monitor('state.albumSummary', 'route.byPlan.filter', 'route.byPlan.portfolio', 'route.byPlan.planId', 'route.mode')
    private syncPlanSource(): void {
        this.planSource.replace(this.groups());
    }

    aboutToDisappear(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
        if (!this.entrance.managed) {
            this.entrance.finish(4);
        }
    }

    @Monitor('route.mode', 'route.byPlan.planId')
    modeChanged(): void {
        this.measured = false;
        this.restoreOffset();
    }

    @Monitor('route.restoreVersion')
    contextChanged(): void {
        this.restoreOffset();
    }

    private restoreOffset(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        if (this.route.mode !== 'byPlan' || this.route.byPlan.planId) {
            return;
        }
        this.restoring = true;
        if (!this.measured) {
            return;
        }
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.groupOffset, animation: false });
            this.restoring = false;
        }, 0);
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

    private groups(): AlbumPlan[] {
        const collection = this.route.byPlan;
        if (collection.planId && !this.state.projects.some((project: CosProject) => project.id === collection.planId)) {
            return [];
        }
        if (collection.filter === 0 && !collection.portfolio) {
            return this.state.albumSummary.plans;
        }
        const plans = new Set<string>(selectPhotoCollection(this.state.photos, collection).map((photo: PhotoAsset) => photo.projectId));
        return this.state.albumSummary.plans.filter((plan: AlbumPlan) => plans.has(plan.id));
    }

    private distribution(): PhotoDistributionItem[] {
        const planId = this.route.collection.planId;
        const counts = planId ? this.state.readiness(planId).photos.byStage : this.state.albumSummary.counts;
        return PHOTO_STAGE_LABELS.map((label: string, index: number): PhotoDistributionItem => ({ label: label, value: counts[index] }));
    }

    private albumFilterOptions(): number[] {
        return this.route.byPlan.portfolio ? [0, 7] : [0, 1, 2, 3, 4, 5, 7, 6];
    }

    private albumFilterLabel(filter: number): string {
        if (this.route.byPlan.portfolio) {
            return filter === 7 ? '已发布' : '全部成片';
        }
        return PHOTO_FILTER_LABELS[filter] || '全部';
    }

    @Builder planFilter() {
        Select(new Array<SelectOption>({ value: '全部计划' }).concat(this.state.projects.map((project: CosProject): SelectOption => {
            return { value: project.name };
        })))
            .value(this.route.collection.planId ? this.state.projectName(this.route.collection.planId) : '全部计划')
            .id('album-plan-filter')
            .height(34)
            .constraintSize({ minWidth: 108, maxWidth: 164, minHeight: 34 })
            .backgroundColor(Theme.tint)
            .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
            .borderRadius(Theme.pillRadius)
            .clip(true)
            .enabled(!this.state.busy && !this.route.collection.submitting)
            .onSelect((index: number): void => {
                vibration.dotVibration();
                const id = index ? this.state.projects[index - 1].id : '';
                if (id && this.route.mode === 'byPlan' && !this.route.byPlan.planId) {
                    this.route.groupOffset = this.scroller.currentOffset().yOffset;
                    this.openPlan(id);
                } else {
                    this.route.collection.setPlan(id);
                }
            })
            .accessibilityText('按计划筛选照片')
            .controlSize(ControlSize.SMALL)
            .font({ size: 12 })
    }

    @Builder headerBar() {
        if (this.route.mode !== 'byPlan' || this.route.byPlan.planId) {
            Row({ space: 8 }) {
                Text(this.route.mode === 'queue' ? '修图队列' : displayName(this.state.projectName(this.route.byPlan.planId)))
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                if (this.route.mode === 'byPlan') {
                    Button(this.route.byPlan.portfolio ? '仅成片 ✓' : '仅成片', { type: ButtonType.Capsule, stateEffect: false })
                        .id('album-portfolio-toggle')
                        .height(34)
                        .padding({ left: 12, right: 12 })
                        .fontSize(12)
                        .fontWeight(this.route.byPlan.portfolio ? FontWeight.Medium : FontWeight.Regular)
                        .enabled(!this.state.busy && !this.route.collection.submitting)
                        .backgroundColor(this.route.byPlan.portfolio ? Theme.brand : Theme.surface)
                        .fontColor(this.route.byPlan.portfolio ? Theme.onAccent : Theme.ink)
                        .border({ width: 0.8, color: this.route.byPlan.portfolio ? Theme.brand : Theme.line, radius: Theme.pillRadius })
                        .borderRadius(Theme.pillRadius)
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.route.byPlan.setPortfolio(!this.route.byPlan.portfolio);
                        })
                        .accessibilityText(this.route.byPlan.portfolio ? '显示全部照片，取消仅看成片' : '仅看成片与已发布')
                }
                Button(this.distributionOpen ? '收起' : '分布', { type: ButtonType.Capsule, stateEffect: false })
                    .id('album-distribution-toggle')
                    .height(34)
                    .padding({ left: 12, right: 12 })
                    .fontSize(12)
                    .fontWeight(this.distributionOpen ? FontWeight.Medium : FontWeight.Regular)
                    .backgroundColor(this.distributionOpen ? Theme.brand : Theme.surface)
                    .fontColor(this.distributionOpen ? Theme.onAccent : Theme.ink)
                    .border({ width: 0.8, color: this.distributionOpen ? Theme.brand : Theme.line, radius: Theme.pillRadius })
                    .borderRadius(Theme.pillRadius)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.distributionOpen = !this.distributionOpen;
                    })
                    .accessibilityText(this.distributionOpen ? '收起照片进度分布' : '展开照片进度分布')
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            if (this.distributionOpen) {
                DistributionChart({
                    title: this.route.collection.planId ? '本计划照片处理分布' : '全部照片处理分布',
                    items: this.distribution(),
                    paletteId: Theme.paletteId,
                })
            }
        }
    }

    @Builder bottomFooter() {
        Column() {
            Blank().height(this.bottomInset).width('100%')
        }.width('100%')
    }

    build() {
        if (this.route.mode === 'queue' || this.route.byPlan.planId) {
            PhotoGrid({
                state: this.state,
                photos: this.state.photos,
                route: this.route.collection,
                from: 'album',
                entrance: this.entrance,
                scroller: this.scroller,
                topInset: this.topInset,
                bottomInset: this.bottomInset,
                sidePadding: Theme.pagePadding,
                header: (): void => {
                    this.headerBar();
                },
                scopeControls: (): void => {
                    this.planFilter();
                },
                view: this.view,
                applySelection: (): void => {
                    this.applySelection(this.route.collection);
                },
                addPhotos: (): void => {
                    this.importPhotos(this.route.collection.planId);
                },
                showAlbum: (): void => {
                    this.route.byPlan.setPortfolio(false);
                },
                setCover: this.setCover,
                removePhoto: this.removePhoto,
            })
        } else {
            Column({ space: 0 }) {
                Column({ space: 8 }) {
                    Blank().height(this.topInset).width('100%')
                    Column() {
                        Row({ space: 8 }) {
                            Scroll() {
                                Row({ space: 6 }) {
                                    ForEach(this.albumFilterOptions(), (filter: number) => {
                                        Button(this.albumFilterLabel(filter), { type: ButtonType.Capsule, stateEffect: false })
                                            .height(34)
                                            .padding({ left: 12, right: 12 })
                                            .fontSize(12)
                                            .fontWeight(this.route.byPlan.filter === filter ? FontWeight.Medium : FontWeight.Regular)
                                            .backgroundColor(this.route.byPlan.filter === filter ? Theme.brand : Theme.tint)
                                            .fontColor(this.route.byPlan.filter === filter ? Theme.onAccent : Theme.ink)
                                            .border({ width: 0.8, color: this.route.byPlan.filter === filter ? Theme.brand : Theme.line, radius: Theme.pillRadius })
                                            .borderRadius(Theme.pillRadius)
                                            .enabled(!this.state.busy)
                                            .onClick((): void => {
                                                vibration.dotVibration();
                                                const next = filter !== 0 && this.route.byPlan.filter === filter ? 0 : filter;
                                                this.route.byPlan.setFilter(next);
                                                this.route.groupOffset = 0;
                                                this.restoreOffset();
                                            })
                                            .accessibilityText('按状态筛选相册：' + this.albumFilterLabel(filter))
                                    }, (filter: number) => String(filter))
                                }.padding({ right: 4 })
                            }.id(this.route.byPlan.portfolio ? 'portfolio-status-filter' : 'album-status-filter')
                                .layoutWeight(1)
                                .scrollable(ScrollDirection.Horizontal)
                                .scrollBar(BarState.Off)
                                .edgeEffect(EdgeEffect.Spring)
                            Button(this.route.byPlan.portfolio ? '仅成片 ✓' : '仅成片', { type: ButtonType.Capsule, stateEffect: false })
                                .id('album-portfolio-toggle')
                                .height(34)
                                .padding({ left: 10, right: 10 })
                                .fontSize(12)
                                .fontWeight(this.route.byPlan.portfolio ? FontWeight.Medium : FontWeight.Regular)
                                .enabled(!this.state.busy && !this.route.collection.submitting)
                                .backgroundColor(this.route.byPlan.portfolio ? Theme.brand : Theme.tint)
                                .fontColor(this.route.byPlan.portfolio ? Theme.onAccent : Theme.ink)
                                .border({ width: 0.8, color: this.route.byPlan.portfolio ? Theme.brand : Theme.line, radius: Theme.pillRadius })
                                .borderRadius(Theme.pillRadius)
                                .onClick((): void => {
                                    vibration.dotVibration();
                                    this.route.byPlan.setPortfolio(!this.route.byPlan.portfolio);
                                })
                                .accessibilityText(this.route.byPlan.portfolio ? '显示全部照片，取消仅看成片' : '仅看成片与已发布')
                            Button(this.columns() + '列', { type: ButtonType.Capsule, stateEffect: false })
                                .id('album-column-toggle')
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
                            Button(this.distributionOpen ? '收起' : '分布', { type: ButtonType.Capsule, stateEffect: false })
                                .id('album-distribution-toggle')
                                .height(34)
                                .padding({ left: 10, right: 10 })
                                .fontSize(12)
                                .fontWeight(this.distributionOpen ? FontWeight.Medium : FontWeight.Regular)
                                .backgroundColor(this.distributionOpen ? Theme.brand : Theme.tint)
                                .fontColor(this.distributionOpen ? Theme.onAccent : Theme.ink)
                                .border({ width: 0.8, color: this.distributionOpen ? Theme.brand : Theme.line, radius: Theme.pillRadius })
                                .borderRadius(Theme.pillRadius)
                                .onClick((): void => {
                                    vibration.dotVibration();
                                    this.distributionOpen = !this.distributionOpen;
                                })
                                .accessibilityText(this.distributionOpen ? '收起照片进度分布' : '展开照片进度分布')
                        }.width('100%')
                            .alignItems(VerticalAlign.Center)
                    }.id('album-filter-panel')
                        .width('100%')
                        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                        .backgroundColor(Theme.surface)
                        .border({ width: 1, color: Theme.line, radius: Theme.cardRadius })
                        .borderRadius(Theme.cardRadius)
                        .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
                    if (this.distributionOpen) {
                        DistributionChart({
                            title: '全部照片处理分布（' + this.groups().length + ' 个相册 ' + this.state.albumSummary.total + ' 张）',
                            items: this.distribution(),
                            paletteId: Theme.paletteId,
                        })
                    }
                    PhotoImportStatus({ state: this.state })
                    if (this.route.byPlan.feedback) {
                        Text(this.route.byPlan.feedback).fontSize(12).fontColor(Theme.accent)
                    }
                }.width('100%')
                    .constraintSize({ maxWidth: Theme.contentMaxWidth })
                    .padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: 8 })
                    .alignItems(HorizontalAlign.Start)
                if (!this.groups().length) {
                    Scroll() {
                        Column({ space: 12 }) {
                            if (this.route.byPlan.filter || this.route.byPlan.portfolio) {
                                Button('查看全部相册', { type: ButtonType.Capsule, stateEffect: false })
                                    .height(36)
                                    .padding({ left: 16, right: 16 })
                                    .backgroundColor(Theme.tint)
                                    .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                                    .borderRadius(Theme.pillRadius)
                                    .fontSize(13)
                                    .fontColor(Theme.accent)
                                    .onClick((): void => {
                                        vibration.dotVibration();
                                        this.route.byPlan.setPortfolio(false);
                                        this.route.byPlan.setFilter(0);
                                    })
                            }
                            EmptyState({
                                title: this.state.projects.length ? '这个筛选下还没有相册' : '照片按计划归类整理',
                                message: this.state.projects.length ? '可以切换筛选状态，或直接导入新照片到对应计划。' : '先创建一个计划，再将出图照片导入其中；参考图不进入相册。',
                                button: '导入照片',
                                icon: Icons.add,
                                action: (): void => {
                                    this.importPhotos('');
                                },
                            })
                            Blank().height(this.bottomInset).width('100%')
                        }.width('100%')
                            .constraintSize({ maxWidth: Theme.contentMaxWidth })
                            .padding({ left: Theme.pagePadding, right: Theme.pagePadding, top: 8 })
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
                        LazyForEach(this.planSource, (plan: AlbumPlan) => {
                            FlowItem() {
                                AlbumPlanTile({
                                    plan: plan,
                                    canImport: !this.state.busy && !this.state.staleScopes.length,
                                    open: (): void => {
                                        this.route.groupOffset = this.scroller.currentOffset().yOffset;
                                        this.openPlan(plan.id);
                                    },
                                    importPhotos: (): void => {
                                        this.importPhotos(plan.id);
                                    },
                                    openProject: (): void => {
                                        this.openProject(plan.id);
                                    },
                                })
                            }.width('100%')
                        }, (plan: AlbumPlan) => plan.id + ':' + (plan.cover?.thumbnailPath || '') + ':' + plan.total + ':' + plan.counts[2] + ':' + plan.counts[4])
                    }.id('album-plan-list')
                        .layoutWeight(1)
                        .width('100%')
                        .constraintSize({ maxWidth: Theme.contentMaxWidth })
                        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
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
                            if (!this.measured && Number(area.height) > 0) {
                                this.measured = true;
                                this.restoreOffset();
                            }
                        })
                        .onDidScroll((): void => {
                            if (this.measured && !this.restoring) {
                                this.route.groupOffset = this.scroller.currentOffset().yOffset;
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
}
