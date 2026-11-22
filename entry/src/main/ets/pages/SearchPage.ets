import { ArrayDataSource } from '../models/ArrayDataSource';
import { displayName } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { AppState } from '../viewmodels/ApplicationState';
import { SearchRoute, SearchHit, SearchSummary, globalSearch, searchRows, SEARCH_SECTIONS, SEARCH_RESOURCE_KINDS, SEARCH_RESOURCE_LABELS } from '../models/GlobalSearch';
import { DashboardSearch } from '../components/DashboardSearch';
import { EmptyState, InteractiveCard } from '../components/Surfaces';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';

@ComponentV2
export struct SearchPage {
    @Require @Param state: AppState;
    @Require @Param route: SearchRoute;
    @Event open: (hit: SearchHit) => void = () => {};
    @Event library: () => void = () => {};
    private source: ArrayDataSource<SearchHit> = new ArrayDataSource<SearchHit>([]);
    private scroller: Scroller = new Scroller();
    private restoreTimer: number = -1;
    private measured: boolean = false;
    private restoring: boolean = true;

    @Computed get summary(): SearchSummary {
        return globalSearch(this.state, this.route.query);
    }

    @Computed get rows(): SearchHit[] {
        return searchRows(this.summary, this.route);
    }

    aboutToAppear(): void {
        this.route.reconcile(this.rows);
        this.source.replace(this.rows);
        this.restoreOffset();
    }

    aboutToDisappear(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
    }

    @Monitor('route.restoreVersion')
    restoreChanged(): void {
        this.route.reconcile(this.rows);
        this.source.replace(this.rows);
        this.restoreOffset();
    }

    @Monitor('rows')
    resultsChanged(): void {
        this.route.reconcile(this.rows);
        this.source.replace(this.rows);
    }

    private restoreOffset(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoring = true;
        if (!this.measured) {
            return;
        }
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.route.section], animation: false });
            this.restoring = false;
        }, 0);
    }

    private hitSymbol(hit: SearchHit): Resource {
        if (hit.kind === 'project') {
            return Icons.plan;
        }
        if (hit.kind === 'character') {
            return Icons.tabProfile;
        }
        if (hit.kind === 'event') {
            return Icons.event;
        }
        if (hit.kind === 'asset') {
            return Icons.library;
        }
        if (hit.kind === 'photo') {
            return Icons.importPhoto;
        }
        return Icons.folder;
    }

    @Builder hitBody(hit: SearchHit) {
        Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(this.hitSymbol(hit))
                    .fontSize(18)
                    .fontColor([Theme.accent])
                    .accessibilityLevel('no')
            }.width(36)
                .height(36)
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.tint)
            Column({ space: 5 }) {
                Text(displayName(hit.title))
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                ContextRow({ label: hit.label, text: displayName(hit.detail) })
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(14)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }

    @Builder quickBentoTile(icon: Resource, title: string, subtitle: string) {
        Column({ space: 6 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(icon).fontSize(18).fontColor([Theme.accent]).accessibilityLevel('no')
            }.width(34).height(34).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
            Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text(subtitle).fontSize(12).fontColor(Theme.muted).maxLines(1)
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder emptyShortcuts() {
        Column({ space: 10 }) {
            Row({ space: 10 }) {
                InteractiveCard({
                    label: '打开角色库',
                    effects: this.state.settings.effects,
                    contentPadding: 14,
                    action: (): void => {
                        this.library();
                    },
                    content: (): void => this.quickBentoTile(Icons.tabProfile, '角色库', this.state.characters.length + ' 位角色'),
                }).id('search-role-library').layoutWeight(1)
                InteractiveCard({
                    label: '筛选计划与任务',
                    effects: this.state.settings.effects,
                    contentPadding: 14,
                    action: (): void => {
                        this.route.setSection(0);
                    },
                    content: (): void => this.quickBentoTile(Icons.plan, '计划与准备', this.state.projects.length + ' 份计划'),
                }).layoutWeight(1)
            }.width('100%')
            Row({ space: 10 }) {
                InteractiveCard({
                    label: '查看日程活动范围',
                    effects: this.state.settings.effects,
                    contentPadding: 14,
                    action: (): void => {
                        this.route.setSection(2);
                    },
                    content: (): void => this.quickBentoTile(Icons.event, '漫展与日程', this.state.events.length + ' 场活动'),
                }).layoutWeight(1)
                InteractiveCard({
                    label: '查看装备与资料收录',
                    effects: this.state.settings.effects,
                    contentPadding: 14,
                    action: (): void => {
                        this.route.setSection(3);
                    },
                    content: (): void => this.quickBentoTile(Icons.library, '装备与收录', (this.state.assets.length + this.state.entries.length) + ' 条记录'),
                }).layoutWeight(1)
            }.width('100%')
            Text('支持按名称、说明、地点或备注搜索；参考图在所属计划与角色中查看。')
                .fontSize(13)
                .fontColor(Theme.muted)
                .padding({ top: 4 })
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    build() {
        List({ space: 12, scroller: this.scroller }) {
            ListItem() {
                Column({ space: 12 }) {
                    Blank().height(Theme.detailTop).width('100%')
                    DashboardSearch({
                        value: this.route.query,
                        placeholder: '输入名称、说明或地点',
                        label: '全局搜索关键词',
                        componentId: 'global-search-input',
                        changed: (value: string): void => {
                            this.route.setQuery(value);
                        },
                    })
                    Row({ space: 10 }) {
                        if (this.route.section === 3) {
                            Select(SEARCH_RESOURCE_LABELS.map((value: string): SelectOption => {
                                return { value: value };
                            }))
                                .id('search-resource-filter')
                                .value(SEARCH_RESOURCE_LABELS[SEARCH_RESOURCE_KINDS.indexOf(this.route.resourceKind)])
                                .constraintSize({ minHeight: 36 })
                                .backgroundColor(Theme.surface)
                                .borderRadius(Theme.pillRadius)
                                .onSelect((index: number): void => {
                                    vibration.dotVibration();
                                    this.route.setResourceKind(SEARCH_RESOURCE_KINDS[index]);
                                })
                                .accessibilityText('搜索资源类型')
                                .controlSize(ControlSize.SMALL)
                                .font({ size: 13 })
                        }
                        ContextRow({
                            label: SEARCH_SECTIONS[this.route.section],
                            text: this.rows.length + ' 条结果',
                        }).id('search-result-count').layoutWeight(1)
                    }.width('100%')
                        .alignItems(VerticalAlign.Center)
                    if (this.route.section === 1 && this.route.query.trim()) {
                        Button('打开角色库', { type: ButtonType.Normal, stateEffect: false })
                            .id('search-role-library')
                            .width('100%')
                            .constraintSize({ minHeight: 42 })
                            .borderRadius(Theme.controlRadius)
                            .backgroundColor(Theme.tint)
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.accent)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.library();
                            })
                    }
                    if (this.route.feedback) {
                        Text(this.route.feedback).fontSize(14).fontColor(Theme.accent)
                    }
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
            }
            LazyForEach(this.source, (hit: SearchHit) => {
                ListItem() {
                    InteractiveCard({
                        label: '打开' + hit.title + '，' + hit.detail,
                        hint: '双击打开',
                        effects: this.state.settings.effects,
                        contentPadding: 14,
                        action: (): void => {
                            this.route.anchorKey = hit.key();
                            this.open(hit);
                        },
                        content: (): void => {
                            this.hitBody(hit);
                        },
                    }).id('search-result:' + hit.key())
                }
            }, (hit: SearchHit) => hit.key())
            if (!this.rows.length) {
                ListItem() {
                    if (this.route.query.trim()) {
                        EmptyState({
                            title: '当前范围没有匹配结果',
                            message: '可切换底部分段、调整关键词或清除搜索。',
                            button: '清除搜索',
                            icon: Icons.search,
                            action: (): void => {
                                this.route.setQuery('');
                            },
                        })
                    } else {
                        this.emptyShortcuts()
                    }
                }
            }
            ListItem() {
                Column() {
                    Blank().height(Theme.detailFloatingBottom).width('100%')
                }.width('100%')
            }
        }.id('search-results')
            .width('100%')
            .height('100%')
            .constraintSize({ maxWidth: Theme.contentMaxWidth })
            .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
            .cachedCount(4)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onAreaChange((_old: Area, area: Area): void => {
                if (!this.measured && Number(area.height) > 0) {
                    this.measured = true;
                    this.restoreOffset();
                }
            })
            .onDidScroll((): void => {
                if (this.measured && !this.restoring) {
                    this.route.offsets[this.route.section] = this.scroller.currentOffset().yOffset;
                }
            })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
