import { ArrayDataSource } from '../models/ArrayDataSource';
import { cardColumnCount } from '../ui/responsive';
import { MetaRow } from '../components/MetaRow';
import { displayName } from '../utils/format';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS } from '../models/constants';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { vibration } from '../ui/vibration';
import { DashboardSearch } from '../components/DashboardSearch';
import { AppState } from '../viewmodels/ApplicationState';
import { WardrobeRoute, wardrobeAssets, wardrobeLocations } from '../models/Wardrobe';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { Asset, AssetStatus, AssetType } from '../models/Entities';
import { InteractiveCard, EmptyState, PillTone, SectionHeading, StatusPill } from '../components/Surfaces';

@ComponentV2
export struct LibraryPage {
    @Require @Param state: AppState;
    @Require @Param route: WardrobeRoute;
    @Param scroller: Scroller = new Scroller();
    @Param topInset: number = 100;
    @Param bottomInset: number = 110;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Param entranceSession: MainEntranceSession = new MainEntranceSession();
    @Param active: boolean = false;
    @Local animStep: number = 0;
    @Local columns: number = 1;
    private enterPlayed: boolean = false;
    private enterTimers: number[] = [];
    private measured: boolean = false;
    private restoring: boolean = true;
    private restoreTimer: number = -1;

    aboutToAppear(): void {
        this.refreshRows();
        if (this.active) {
            this.enter();
        }
    }

    @Monitor('active')
    activeChanged(): void {
        if (this.active) {
            this.enter();
            this.restoreOffset();
        }
    }

    @Monitor('route.restoreVersion')
    restoreChanged(): void {
        this.restoreOffset();
    }

    private enter(): void {
        if (this.enterPlayed) {
            return;
        }
        this.enterPlayed = true;
        if (!this.entranceSession.claim('LibraryPage')) {
            this.animStep = 2;
            return;
        }
        this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => {
            this.animStep = step;
        });
    }

    aboutToDisappear(): void {
        cancelStaggerEnterAnimation(this.enterTimers);
        this.enterTimers = [];
        this.animStep = 2;
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
    }

    private restoreOffset(): void {
        if (!this.measured) {
            return;
        }
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoring = true;
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offset, animation: false });
            if (this.route.anchorId) {
                try {
                    this.getUIContext().getFocusController().requestFocus('wardrobe-asset:' + this.route.anchorId);
                } catch (error) {
                }
            }
            this.restoring = false;
        }, 0);
    }

    @Computed
    private get visibleAssets(): Asset[] {
        return wardrobeAssets(this.state.assets, this.route);
    }

    private source: ArrayDataSource<Asset> = new ArrayDataSource<Asset>([]);

    @Monitor('visibleAssets')
    private refreshRows(): void {
        this.source.replace(this.visibleAssets);
    }

    private locations(): string[] {
        const values = wardrobeLocations(this.state.assets);
        if (this.route.locationMode === 'named' && !values.includes(this.route.location)) {
            values.push(this.route.location);
        }
        return values;
    }

    private locationLabels(): string[] {
        return ['全部位置', '未记录位置'].concat(this.locations().map((value: string) => '存放位置：' + value));
    }

    private locationIndex(): number {
        return this.route.locationMode === 'all' ? 0 : this.route.locationMode === 'unrecorded' ? 1 : this.locations()
            .indexOf(this.route.location) + 2;
    }

    private assetStatusTone(status: AssetStatus): PillTone {
        if (status === AssetStatus.OWNED) {
            return 'success';
        }
        if (status === AssetStatus.ORDERED) {
            return 'brand';
        }
        if (status === AssetStatus.REPAIR || status === AssetStatus.LENT) {
            return 'warning';
        }
        return 'neutral';
    }

    @Builder controls() {
        DashboardSearch({
            value: this.route.query,
            placeholder: '搜索装备 / 存放位置',
            label: '搜索衣柜',
            changed: (value: string): void => {
                this.route.query = value;
                this.route.changed();
            },
        })
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            Select(['全部类型'].concat(ASSET_TYPE_LABELS).map((label: string): SelectOption => {
                return { value: label };
            }))
                .value(this.route.type ? ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.route.type as AssetType)] : '全部类型')
                .constraintSize({ minHeight: 36 })
                .backgroundColor(Theme.surface)
                .borderRadius(12)
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.route.type = index ? ASSET_TYPES[index - 1] : '';
                    this.route.changed();
                })
                .accessibilityText('衣柜装备类型筛选')
                .margin({ right: 8, bottom: 8 })
                .controlSize(ControlSize.SMALL)
                .font({ size: 13 })
            Select(['全部状态'].concat(ASSET_STATUS_LABELS).map((label: string): SelectOption => {
                return { value: label };
            }))
                .value(this.route.status ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.route.status as AssetStatus)] : '全部状态')
                .constraintSize({ minHeight: 36 })
                .backgroundColor(Theme.surface)
                .borderRadius(12)
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.route.status = index ? ASSET_STATUSES[index - 1] : '';
                    this.route.changed();
                })
                .accessibilityText('衣柜装备状态筛选')
                .margin({ right: 8, bottom: 8 })
                .controlSize(ControlSize.SMALL)
                .font({ size: 13 })
            Select(this.locationLabels().map((label: string): SelectOption => {
                return { value: label };
            }))
                .value(this.locationLabels()[this.locationIndex()])
                .constraintSize({ minHeight: 36 })
                .backgroundColor(Theme.surface)
                .borderRadius(12)
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.route.locationMode = index === 0 ? 'all' : index === 1 ? 'unrecorded' : 'named';
                    this.route.location = index > 1 ? this.locations()[index - 2] : '';
                    this.route.changed();
                })
                .accessibilityText('衣柜存放位置筛选')
                .margin({ bottom: 8 })
                .controlSize(ControlSize.SMALL)
                .font({ size: 13 })
        }.width('100%')
        if (this.route.filtered) {
            Button('清除衣柜筛选', { type: ButtonType.Normal, stateEffect: false })
                .height(34)
                .padding({ left: 12, right: 12 })
                .borderRadius(12)
                .backgroundColor(Theme.tint)
                .fontSize(12)
                .fontColor(Theme.muted)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.route.clear();
                })
        }
        if (this.route.feedback) {
            Text(this.route.feedback).fontSize(13).fontColor(Theme.accent)
        }
        SectionHeading({
            title: '我的衣柜',
            icon: Icons.library,
            trailing: this.visibleAssets.length + ' 件装备',
        })
    }

    @Builder assetContent(asset: Asset) {
        Column({ space: 10 }) {
            Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                    SymbolGlyph(Icons.assetTypeSymbol(asset.type))
                        .fontSize(20)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(40)
                    .height(40)
                    .borderRadius(Theme.slotRadius)
                    .backgroundColor(Theme.tint)
                Column({ space: 4 }) {
                    Row({ space: 8 }) {
                        Text(displayName(asset.name))
                            .fontSize(17)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.ink)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                        StatusPill({
                            label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] || '自有',
                            tone: this.assetStatusTone(asset.status),
                            compact: true,
                        })
                    }.width('100%')
                    Row({ space: 12 }) {
                        Text(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(asset.type)] || '其他')
                            .fontSize(12)
                            .fontColor(Theme.muted)
                        MetaRow({
                            icon: Icons.location,
                            text: asset.location.trim() || '未记录位置',
                        })
                    }
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                SymbolGlyph(Icons.chevronRightSymbol)
                    .fontSize(14)
                    .fontColor([Theme.muted])
                    .accessibilityLevel('no')
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            Row({ space: 10 }) {
                MetaRow({
                    icon: Icons.plan,
                    text: '关联计划 ' + this.state.assetUsage(asset.id).projects.length + ' 份',
                })
                if (asset.status !== AssetStatus.OWNED && this.state.assetUsage(asset.id).activeProjects.length > 0) {
                    Row({ space: 4 }) {
                        SymbolGlyph(Icons.alert)
                            .fontSize(12)
                            .fontColor([Theme.warning])
                            .accessibilityLevel('no')
                        Text('影响 ' + this.state.assetUsage(asset.id).activeProjects.length + ' 份进行中计划')
                            .fontSize(11)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.warning)
                    }.padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(Theme.badgeRadius)
                        .backgroundColor(Theme.warningBg)
                }
            }.width('100%')
                .alignItems(VerticalAlign.Center)
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @LocalBuilder listHeader() {
        Column({ space: 10 }) {
            Blank().height(this.topInset).width('100%')
            this.controls()
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
            .opacity(this.animStep >= 1 ? 1 : 0)
            .padding({ bottom: Theme.cardSpacing })
    }

    build() {
        List({ space: 12, scroller: this.scroller }) {
            ListItemGroup({ header: this.listHeader, space: Theme.cardSpacing }) {
                LazyForEach(this.source, (asset: Asset) => {
                    ListItem() {
                        InteractiveCard({
                            label: '打开装备 ' + asset.name,
                            hint: '双击打开装备详情',
                            effects: this.state.settings.effects,
                            contentPadding: 14,
                            action: (): void => {
                                this.route.anchorId = asset.id;
                                this.open('asset', asset.id);
                            },
                            content: (): void => {
                                this.assetContent(asset);
                            },
                        }).id('wardrobe-asset:' + asset.id)
                    }.opacity(this.animStep >= 2 ? 1 : 0)
                }, (asset: Asset) => asset.id)
                if (!this.visibleAssets.length) {
                    ListItem() {
                        EmptyState({
                            title: this.route.filtered ? '没有匹配的装备' : '让每一件装备有归处',
                            message: this.route.filtered ? '名称、类型、状态与位置共同限定当前结果。' : '记录位置和真实状态，再复用到计划。',
                            button: this.route.filtered ? '清除筛选' : '添加装备',
                            icon: Icons.library,
                            action: (): void => {
                                if (this.route.filtered) {
                                    this.route.clear();
                                } else {
                                    this.add('asset', '');
                                }
                            },
                        })
                    }
                }
            }
            ListItem() {
                Column() {
                    Blank().height(this.bottomInset).width('100%')
                }.width('100%')
            }
        }.id('library-scroll')
            .width('100%')
            .height('100%')
            .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
            .cachedCount(4)
            .lanes(this.columns, Theme.cardSpacing)
            .constraintSize({ maxWidth: Theme.contentMaxWidth })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .align(Alignment.Top)
            .onAreaChange((_old: Area, area: Area): void => {
                const columns = cardColumnCount(Number(area.width));
                if (this.columns !== columns) {
                    this.columns = columns;
                }
                if (!this.measured && Number(area.height) > 0) {
                    this.measured = true;
                    this.restoreOffset();
                }
            })
            .onDidScroll((): void => {
                if (this.measured && !this.restoring) {
                    this.route.offset = this.scroller.currentOffset().yOffset;
                }
            })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
