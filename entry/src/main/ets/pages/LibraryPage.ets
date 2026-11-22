import { SymbolGlyphModifier } from '@kit.ArkUI';
import { ArrayDataSource } from '../models/ArrayDataSource';
import { cardColumnCount } from '../ui/responsive';
import { displayName } from '../utils/format';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS } from '../models/constants';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { vibration } from '../ui/vibration';
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
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string) => void = () => {};
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
        return ['全部位置', '未填位置'].concat(this.locations());
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

    private typeLabel(type: AssetType): string {
        const idx = ASSET_TYPES.indexOf(type);
        return idx >= 0 ? ASSET_TYPE_LABELS[idx] : '其他';
    }

    private typeCount(type: string): number {
        if (!type) {
            return this.state.assets.length;
        }
        return this.state.assets.filter((item: Asset) => item.type === type as AssetType).length;
    }

    private categoryColor(type: AssetType): Resource {
        if (type === AssetType.COSTUME) {
            return Theme.accent;
        }
        if (type === AssetType.WIG || type === AssetType.MAKEUP) {
            return Theme.purple;
        }
        if (type === AssetType.SHOES) {
            return Theme.warning;
        }
        if (type === AssetType.PROP) {
            return Theme.info;
        }
        if (type === AssetType.ACCESSORY) {
            return Theme.success;
        }
        if (type === AssetType.LENS) {
            return Theme.danger;
        }
        return Theme.muted;
    }

    private categoryBg(type: AssetType): Resource {
        if (type === AssetType.WIG || type === AssetType.MAKEUP) {
            return Theme.purpleBg;
        }
        if (type === AssetType.SHOES) {
            return Theme.warningBg;
        }
        if (type === AssetType.PROP) {
            return Theme.noticeBg;
        }
        if (type === AssetType.ACCESSORY) {
            return Theme.successBg;
        }
        if (type === AssetType.LENS) {
            return Theme.dangerBg;
        }
        return Theme.tint;
    }

    @Builder categoryChip(type: string, label: string, selected: boolean, tint: Resource, bg: Resource, icon: Resource | undefined) {
        Button({ type: ButtonType.Capsule, stateEffect: false }) {
            Row({ space: 6 }) {
                if (icon) {
                    SymbolGlyph(icon)
                        .fontSize(15)
                        .fontColor([selected ? Theme.onAccent : tint])
                        .accessibilityLevel('no')
                }
                Text(this.typeCount(type) > 0 ? label + ' ' + this.typeCount(type) : label)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(selected ? Theme.onAccent : Theme.ink)
            }.padding({ left: 14, right: 14 })
        }.height(40)
            .backgroundColor(selected ? (type ? tint : Theme.brand) : (type ? bg : Theme.tint))
            .border({ width: 1, color: selected ? (type ? tint : Theme.brand) : Theme.line, radius: Theme.pillRadius })
            .borderRadius(Theme.pillRadius)
            .onClick((): void => {
                vibration.dotVibration();
                this.route.type = this.route.type === type ? '' : type;
                this.route.changed();
            })
            .accessibilitySelected(selected)
            .accessibilityText('按分类筛选：' + label)
    }

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    @Builder controls() {
        Column({ space: 12 }) {
            Scroll() {
                Row({ space: 8 }) {
                    this.categoryChip('', '全部', !this.route.type, Theme.brand, Theme.tint, undefined)
                    ForEach(ASSET_TYPES, (assetType: AssetType) => {
                        this.categoryChip(assetType, this.typeLabel(assetType), this.route.type === assetType,
                            this.categoryColor(assetType), this.categoryBg(assetType), Icons.assetTypeSymbol(assetType))
                    }, (assetType: AssetType) => assetType)
                }.padding({ right: 4 })
            }.id('library-type-strip')
                .width('100%')
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
            Row({ space: 8 }) {
                Select(['全部状态'].concat(ASSET_STATUS_LABELS).map((label: string): SelectOption => {
                    return { value: label };
                }))
                    .value(this.route.status ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.route.status as AssetStatus)] : '全部状态')
                    .height(38)
                    .backgroundColor(Theme.tint)
                    .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                    .borderRadius(Theme.pillRadius)
                    .clip(true)
                    .onSelect((index: number): void => {
                        vibration.dotVibration();
                        this.route.status = index ? ASSET_STATUSES[index - 1] : '';
                        this.route.changed();
                    })
                    .accessibilityText('衣柜装备状态筛选')
                    .controlSize(ControlSize.SMALL)
                    .font({ size: 13 })
                Select(this.locationLabels().map((label: string): SelectOption => {
                    return { value: label };
                }))
                    .value(this.locationLabels()[this.locationIndex()])
                    .height(38)
                    .backgroundColor(Theme.tint)
                    .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                    .borderRadius(Theme.pillRadius)
                    .clip(true)
                    .onSelect((index: number): void => {
                        vibration.dotVibration();
                        this.route.locationMode = index === 0 ? 'all' : index === 1 ? 'unrecorded' : 'named';
                        this.route.location = index > 1 ? this.locations()[index - 2] : '';
                        this.route.changed();
                    })
                    .accessibilityText('衣柜存放位置筛选')
                    .controlSize(ControlSize.SMALL)
                    .font({ size: 13 })
                Blank()
                if (this.route.filtered) {
                    Button('重置', { type: ButtonType.Capsule, stateEffect: false })
                        .id('library-reset-filter')
                        .height(38)
                        .padding({ left: 14, right: 14 })
                        .backgroundColor(Theme.tint)
                        .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                        .borderRadius(Theme.pillRadius)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.accent)
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.route.clear();
                        })
                        .accessibilityText('清除衣柜筛选条件')
                }
            }.width('100%')
                .alignItems(VerticalAlign.Center)
        }.id('library-filter-panel')
            .width('100%')
            .padding(14)
            .backgroundColor(Theme.surface)
            .border({ width: 1, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
            .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        if (this.route.feedback) {
            Text(this.route.feedback).fontSize(13).fontColor(Theme.accent)
        }
        SectionHeading({
            title: this.route.type ? this.typeLabel(this.route.type as AssetType) : '我的衣柜',
            icon: this.route.type ? Icons.assetTypeSymbol(this.route.type) : Icons.library,
            trailing: this.visibleAssets.length + ' 件装备',
        })
    }

    @Builder assetContent(asset: Asset) {
        Row({ space: 10 }) {
            Column() {
            }.width(4)
                .height(44)
                .borderRadius(Theme.pillRadius)
                .backgroundColor(this.categoryColor(asset.type))
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(Icons.assetTypeSymbol(asset.type))
                    .fontSize(20)
                    .fontColor([this.categoryColor(asset.type)])
                    .accessibilityLevel('no')
            }.width(44)
                .height(44)
                .borderRadius(Theme.slotRadius)
                .backgroundColor(this.categoryBg(asset.type))
            Column({ space: 6 }) {
                Row({ space: 8 }) {
                    Text(displayName(asset.name))
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                    StatusPill({
                        label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] || '可用',
                        tone: this.assetStatusTone(asset.status),
                        compact: true,
                    })
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
                Row({ space: 6 }) {
                    Text(this.typeLabel(asset.type))
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.categoryColor(asset.type))
                        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(this.categoryBg(asset.type))
                        .flexShrink(0)
                    if (asset.location.trim()) {
                        Row({ space: 3 }) {
                            SymbolGlyph(Icons.location)
                                .fontSize(12)
                                .fontColor([Theme.muted])
                                .accessibilityLevel('no')
                            Text(asset.location.trim())
                                .fontSize(12)
                                .fontColor(Theme.muted)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }.layoutWeight(1)
                    } else {
                        Blank().layoutWeight(1)
                    }
                    if (asset.status !== AssetStatus.OWNED && this.state.assetUsage(asset.id).activeProjects.length > 0) {
                        Row({ space: 3 }) {
                            SymbolGlyph(Icons.alert)
                                .fontSize(11)
                                .fontColor([Theme.warning])
                                .accessibilityLevel('no')
                            Text('缺' + this.state.assetUsage(asset.id).activeProjects.length)
                                .fontSize(11)
                                .fontWeight(FontWeight.Medium)
                                .fontColor(Theme.warning)
                        }.padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(Theme.pillRadius)
                            .backgroundColor(Theme.warningBg)
                            .flexShrink(0)
                    } else if (this.state.assetUsage(asset.id).projects.length > 0) {
                        Text(this.state.assetUsage(asset.id).projects.length + ' 计划')
                            .fontSize(11)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.muted)
                            .flexShrink(0)
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(13)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
            .height(60)
            .alignItems(VerticalAlign.Center)
    }

    @Builder assetMenu(asset: Asset) {
        Menu() {
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.library).fontSize(18).fontColor([Theme.accent]),
                content: '查看详情',
            }).onClick((): void => {
                vibration.dotVibration();
                this.route.anchorId = asset.id;
                this.open('asset', asset.id);
            })
            if (asset.status !== AssetStatus.OWNED) {
                MenuItem({
                    symbolStartIcon: new SymbolGlyphModifier(Icons.done).fontSize(18).fontColor([Theme.success]),
                    content: '标为可用',
                }).enabled(this.writable())
                    .onClick((): void => {
                        vibration.dotVibration();
                        const copy = JSON.parse(JSON.stringify(asset)) as Asset;
                        copy.status = AssetStatus.OWNED;
                        void this.state.saveAsset(copy);
                    })
            }
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.edit).fontSize(18).fontColor([Theme.ink]),
                content: '编辑装备',
            }).enabled(this.writable())
                .onClick((): void => {
                    vibration.dotVibration();
                    this.edit('asset', asset.id, '');
                })
            MenuItem({
                symbolStartIcon: new SymbolGlyphModifier(Icons.remove).fontSize(18).fontColor([Theme.danger]),
                content: '删除装备',
            }).contentFontColor(Theme.danger)
                .enabled(this.writable())
                .onClick((): void => {
                    vibration.dotVibration();
                    this.remove('asset', asset.id);
                })
        }
    }

    build() {
        Column({ space: 0 }) {
            Column({ space: 10 }) {
                Blank().height(this.topInset).width('100%')
                this.controls()
            }.width('100%')
                .constraintSize({ maxWidth: Theme.contentMaxWidth })
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: 8 })
                .alignItems(HorizontalAlign.Start)
                .opacity(this.animStep >= 1 ? 1 : 0)
            List({ space: Theme.cardSpacing, scroller: this.scroller }) {
                LazyForEach(this.source, (asset: Asset) => {
                    ListItem() {
                        InteractiveCard({
                            label: '打开装备 ' + asset.name,
                            hint: '双击打开装备详情',
                            effects: this.state.settings.effects,
                            contentPadding: 14,
                            hasMenu: true,
                            action: (): void => {
                                this.route.anchorId = asset.id;
                                this.open('asset', asset.id);
                            },
                            content: (): void => {
                                this.assetContent(asset);
                            },
                            contextMenu: (): void => {
                                this.assetMenu(asset);
                            },
                        }).id('wardrobe-asset:' + asset.id)
                    }.opacity(this.animStep >= 2 ? 1 : 0)
                }, (asset: Asset) => asset.id + ':' + asset.status + ':' + asset.name + ':' + asset.location + ':' + asset.type)
                if (!this.visibleAssets.length) {
                    ListItem() {
                        EmptyState({
                            title: this.route.filtered ? '没有匹配的装备' : '让每一件装备有归处',
                            message: this.route.filtered ? '名称、分类、状态与位置共同限定当前结果。' : '按服装、假发、鞋靴、道具等分类收纳，随时复用到计划。',
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
                ListItem() {
                    Column() {
                        Blank().height(this.bottomInset).width('100%')
                    }.width('100%')
                }
            }.id('library-scroll')
                .layoutWeight(1)
                .width('100%')
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .cachedCount(4)
                .lanes(this.visibleAssets.length > 0 ? this.columns : 1, Theme.cardSpacing)
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
        }.width('100%')
            .height('100%')
            .alignItems(HorizontalAlign.Center)
    }
}
