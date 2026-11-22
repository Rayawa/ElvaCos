import { SymbolGlyphModifier, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ArrayDataSource } from '../models/ArrayDataSource';
import { cardColumnCount } from '../ui/responsive';
import { displayName } from '../utils/format';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS } from '../models/constants';
import { scrollByAxis } from '../ui/scroll';
import { vibration } from '../ui/vibration';
import { AppState } from '../viewmodels/ApplicationState';
import { WardrobeRoute, wardrobeLocations } from '../models/Wardrobe';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { Asset, AssetStatus, AssetType } from '../models/Entities';
import { InteractiveCard, EmptyState, PillTone, SectionHeading, StatusPill } from '../components/Surfaces';

@ComponentV2
export struct WardrobeSearchPage {
    @Require @Param state: AppState;
    @Require @Param route: WardrobeRoute;
    @Param geometryId: string = 'wardrobe-search-shared';
    @Event onClose: () => void = () => {};
    @Event open: (kind: string, id: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string) => void = () => {};
    @Local columns: number = 1;
    @Local backPressed: boolean = false;
    @Local animStep: number = 0;
    @Local topGap: number = 12;
    private scroller: Scroller = new Scroller();
    private source: ArrayDataSource<Asset> = new ArrayDataSource<Asset>([]);
    private focusTimer: number = -1;

    aboutToAppear(): void {
        this.refreshRows();
        try {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
            if (context) {
                void window.getLastWindow(context).then((win: window.Window): void => {
                    const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
                    const topVp = this.getUIContext().px2vp(area.topRect.height);
                    this.topGap = topVp > 0 ? Math.round(topVp) + 8 : 12;
                }).catch((_error: Error): void => {});
            }
        } catch (_error) {
        }
        this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, (): void => {
            this.animStep = 1;
        });
        this.focusTimer = setTimeout((): void => {
            this.focusTimer = -1;
            try {
                this.getUIContext().getFocusController().requestFocus('wardrobe-search-input');
            } catch (_error) {
            }
        }, 220);
    }

    aboutToDisappear(): void {
        if (this.focusTimer >= 0) {
            clearTimeout(this.focusTimer);
            this.focusTimer = -1;
        }
    }

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    private typeLabel(type: AssetType): string {
        const idx = ASSET_TYPES.indexOf(type);
        return idx >= 0 ? ASSET_TYPE_LABELS[idx] : '其他';
    }

    private statusLabel(status: AssetStatus): string {
        const idx = ASSET_STATUSES.indexOf(status);
        return idx >= 0 ? ASSET_STATUS_LABELS[idx] : '可用';
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

    @Computed
    private get matchedAssets(): Asset[] {
        const q = this.route.query.trim().toLocaleLowerCase();
        if (!q) {
            return this.state.assets;
        }
        return this.state.assets.filter((asset: Asset): boolean => {
            const haystack = (asset.name + ' ' + asset.brand + ' ' + asset.location + ' ' +
                this.typeLabel(asset.type) + ' ' + this.statusLabel(asset.status)).toLocaleLowerCase();
            return haystack.includes(q);
        });
    }

    @Monitor('matchedAssets')
    private refreshRows(): void {
        this.source.replace(this.matchedAssets);
    }

    private applySuggestion(keyword: string): void {
        vibration.dotVibration();
        this.route.query = keyword;
        this.route.changed();
    }

    @Builder suggestionChip(label: string, icon: Resource, tint: Resource, bg: Resource) {
        Button({ type: ButtonType.Capsule, stateEffect: false }) {
            Row({ space: 6 }) {
                SymbolGlyph(icon)
                    .fontSize(14)
                    .fontColor([tint])
                    .accessibilityLevel('no')
                Text(label)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.ink)
            }.padding({ left: 12, right: 12 })
        }.height(36)
            .backgroundColor(bg)
            .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
            .borderRadius(Theme.pillRadius)
            .onClick((): void => {
                this.applySuggestion(label);
            })
            .accessibilityText('按' + label + '筛选搜索')
    }

    @Builder suggestionsCard() {
        Column({ space: 10 }) {
            Scroll() {
                Row({ space: 8 }) {
                    ForEach(ASSET_TYPES, (assetType: AssetType) => {
                        this.suggestionChip(
                            this.typeLabel(assetType),
                            Icons.assetTypeSymbol(assetType),
                            this.categoryColor(assetType),
                            this.categoryBg(assetType),
                        )
                    }, (assetType: AssetType) => assetType)
                }.padding({ right: 4 })
            }.width('100%')
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
            if (wardrobeLocations(this.state.assets).length > 0) {
                Scroll() {
                    Row({ space: 8 }) {
                        ForEach(wardrobeLocations(this.state.assets), (loc: string) => {
                            this.suggestionChip(loc, Icons.location, Theme.accent, Theme.tint)
                        }, (loc: string) => loc)
                    }.padding({ right: 4 })
                }.width('100%')
                    .scrollable(ScrollDirection.Horizontal)
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
            }
        }.id('wardrobe-search-suggestions')
            .width('100%')
            .padding(12)
            .backgroundColor(Theme.surface)
            .border({ width: 1, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
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
                        label: this.statusLabel(asset.status),
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
                    if (asset.brand.trim()) {
                        Text(asset.brand.trim())
                            .fontSize(11)
                            .fontColor(Theme.muted)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
            Row({ space: 10 }) {
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.chevronLeftSymbol)
                        .fontSize(22)
                        .fontColor([Theme.ink])
                        .accessibilityLevel('no')
                }.id('wardrobe-search-back')
                    .width(44)
                    .height(44)
                    .backgroundColor(Theme.surface)
                    .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                    .borderRadius(Theme.pillRadius)
                    .scale({
                        x: this.backPressed ? 0.94 : 1,
                        y: this.backPressed ? 0.94 : 1,
                    })
                    .animation({ duration: 120, curve: Curve.EaseOut })
                    .onTouch((event: TouchEvent): void => {
                        if (event.type === TouchType.Down) {
                            this.backPressed = true;
                        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                            this.backPressed = false;
                        }
                    })
                    .onClick((): void => {
                        vibration.backVibration();
                        this.onClose();
                    })
                    .accessibilityText('返回衣柜')
                Search({ value: this.route.query, placeholder: '搜索装备名 / 品牌 / 存放位置' })
                    .id('wardrobe-search-input')
                    .layoutWeight(1)
                    .height(44)
                    .searchButton('搜索')
                    .backgroundColor(Theme.tint)
                    .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                    .borderRadius(Theme.pillRadius)
                    .placeholderFont({ size: 14 })
                    .textFont({ size: 14 })
                    .defaultFocus(false)
                    .geometryTransition(this.geometryId, { follow: true })
                    .transition(TransitionEffect.opacity(0.99))
                    .onChange((value: string): void => {
                        this.route.query = value;
                        this.route.changed();
                    })
                    .onSubmit((value: string): void => {
                        vibration.dotVibration();
                        this.route.query = value;
                        this.route.changed();
                    })
                    .accessibilityText('搜索衣柜装备')
            }.width('100%')
                .constraintSize({ maxWidth: Theme.contentMaxWidth })
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding, top: this.topGap, bottom: 8 })
                .alignItems(VerticalAlign.Center)
            Column({ space: 10 }) {
                if (!this.route.query.trim()) {
                    this.suggestionsCard()
                }
                Row({ space: 8 }) {
                    Column() {
                        SectionHeading({
                            title: this.route.query.trim() ? '搜索结果' : '全部装备',
                            icon: Icons.search,
                            trailing: this.matchedAssets.length + ' 件装备',
                        })
                    }.layoutWeight(1)
                    if (this.route.query.trim()) {
                        Button('清空', { type: ButtonType.Capsule, stateEffect: false })
                            .id('wardrobe-search-clear')
                            .height(34)
                            .padding({ left: 12, right: 12 })
                            .backgroundColor(Theme.tint)
                            .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                            .borderRadius(Theme.pillRadius)
                            .fontSize(12)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.accent)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.route.query = '';
                                this.route.changed();
                            })
                            .accessibilityText('清空衣柜搜索关键词')
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
                if (this.matchedAssets.length > 0) {
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
                                }).id('wardrobe-search-asset:' + asset.id)
                            }
                        }, (asset: Asset) => asset.id + ':' + asset.status + ':' + asset.name + ':' + asset.location + ':' + asset.type + ':' + asset.brand)
                        ListItem() {
                            Column() {
                                Blank().height(Theme.detailBottom).width('100%')
                            }.width('100%')
                        }
                    }.id('wardrobe-search-scroll')
                        .layoutWeight(1)
                        .width('100%')
                        .cachedCount(4)
                        .lanes(this.columns, Theme.cardSpacing)
                        .scrollBar(BarState.Off)
                        .edgeEffect(EdgeEffect.Spring)
                        .align(Alignment.Top)
                        .onAxisEvent((event: AxisEvent): void => {
                            scrollByAxis(this.scroller, event);
                        })
                } else {
                    EmptyState({
                        title: '没有找到匹配装备',
                        message: '试试装备名称、品牌、分类或存放位置关键词。',
                        button: '清空搜索',
                        icon: Icons.search,
                        action: (): void => {
                            vibration.dotVibration();
                            this.route.query = '';
                            this.route.changed();
                        },
                    })
                }
            }.width('100%')
                .layoutWeight(1)
                .constraintSize({ maxWidth: Theme.contentMaxWidth })
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .opacity(this.animStep >= 1 ? 1 : 0)
        }.width('100%')
            .height('100%')
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(Theme.bg)
            .onAreaChange((_old: Area, area: Area): void => {
                const columns = cardColumnCount(Number(area.width));
                if (this.columns !== columns) {
                    this.columns = columns;
                }
            })
    }
}
