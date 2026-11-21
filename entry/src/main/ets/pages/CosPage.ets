import { ArrayDataSource } from '../models/ArrayDataSource';
import { cardColumnCount } from '../ui/responsive';
import { filterCharacters } from '../models/CharacterLibrary';
import { MainEntranceSession, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../ui/motion';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { PlanListRoute, filterPlanList } from '../viewmodels/PlanListRoute';
import { PROJECT_LABELS, PROJECT_STATUSES } from '../models/constants';
import { DashboardSearch } from '../components/DashboardSearch';
import { ManagedImage } from '../components/ManagedImage';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { Character, CosProject, ProjectStatus } from '../models/Entities';
import { ProjectCard } from '../components/ProjectCard';
import { InteractiveCard, EmptyState, StatusPill } from '../components/Surfaces';
import { pressVisualEffect, pressLightFieldFilter } from '../ui/visualEffects';

const PLAN_SECTION_LABELS: string[] = ['进行中', '已完成', '全部'];

@ComponentV2
export struct CosPage {
    @Param scroller: Scroller = new Scroller();
    @Param topInset: number = 100;
    @Param bottomInset: number = 110;
    @Require @Param state: AppState;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event add: (kind: string, parent: string) => void = () => {};
    @Param projects: boolean = true;
    @Param route: PlanListRoute = new PlanListRoute();
    @Param entranceSession: MainEntranceSession = new MainEntranceSession();
    @Param active: boolean = false;
    private displayedSection: number = 0;
    private restoring: boolean = true;
    private measured: boolean = false;
    private restoreTimer: number = -1;
    @Local animStep: number = 0;
    @Local private pressedSection: number = -1;
    private enterPlayed: boolean = false;
    private enterTimers: number[] = [];

    aboutToAppear(): void {
        this.refreshRows();
        this.restore();
        if (this.active) {
            this.enter();
        }
    }

    @Monitor('active')
    activeChanged(): void {
        if (this.active) {
            this.enter();
            this.restore();
        }
    }

    private enter(): void {
        if (this.enterPlayed) {
            return;
        }
        this.enterPlayed = true;
        if (!this.entranceSession.claim('CosPage')) {
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
            this.restoreTimer = -1;
        }
    }

    @Monitor('route.section', 'route.restoreVersion')
    sectionChanged(): void {
        this.restore();
    }

    private restore(): void {
        this.restoring = true;
        this.displayedSection = this.route.section;
        if (!this.measured) {
            return;
        }
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false });
            if (!this.projects && this.route.anchorId) {
                try {
                    this.getUIContext().getFocusController().requestFocus('character-library:' + this.route.anchorId);
                } catch (error) {
                }
            }
            this.restoring = false;
        }, 0);
    }

    private resetPosition(): void {
        this.route.anchorId = '';
        this.route.offsets[this.route.section] = 0;
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    }

    @Computed
    private get visiblePlans(): CosProject[] {
        return filterPlanList(this.state.projects, this.state.readinessPlans, this.state.characters, this.route, this.state.localDate);
    }

    @Computed
    private get visibleCharacters(): Character[] {
        return filterCharacters(this.state.characters, this.route);
    }

    private statuses(): ProjectStatus[] {
        return PROJECT_STATUSES.filter((status: ProjectStatus): boolean => this.route.section === 2 || (this.route.section === 0 ? status !== ProjectStatus.COMPLETED && status !== ProjectStatus.ARCHIVED : status === ProjectStatus.COMPLETED));
    }

    private statusOptions(): SelectOption[] {
        const options: SelectOption[] = [{ value: '全部状态' }];
        return options.concat(this.statuses().map((status: ProjectStatus): SelectOption => {
            return { value: PROJECT_LABELS[PROJECT_STATUSES.indexOf(status)] };
        }));
    }

    private filtered(): boolean {
        return !!this.route.query.trim() || !!this.route.status || this.route.dateRange !== 'all';
    }

    private clearFilters(): void {
        vibration.dotVibration();
        this.route.query = '';
        this.route.status = '';
        this.route.dateRange = 'all';
        this.route.favoriteOnly = false;
        this.resetPosition();
    }

    @Builder characterBody(character: Character) {
        Row({ space: 14 }) {
            if (character.cover) {
                ManagedImage({ sourcePath: character.cover, label: character.name + '封面', radius: 12 })
                    .width(68)
                    .height(86)
                    .accessibilityText(character.name + '封面')
            } else {
                Stack({ alignContent: Alignment.Center }) {
                    Text(character.name.slice(0, 1))
                        .fontSize(26)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.accent)
                }.width(68)
                    .height(86)
                    .backgroundColor(Theme.tint)
                    .borderRadius(12)
                    .accessibilityLevel('no')
            }
            Column({ space: 6 }) {
                Row({ space: 6 }) {
                    Text(character.name)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .flexShrink(1)
                    if (character.favorite) {
                        SymbolGlyph(Icons.starFill)
                            .fontSize(15)
                            .fontColor([Theme.warning])
                            .accessibilityLevel('no')
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
                Text(character.workName || '所属作品待补充')
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 8 }) {
                    StatusPill({
                        label: this.state.characterSummary(character.id).variants.length + ' 个版本',
                        tone: 'neutral',
                        compact: true,
                    })
                    StatusPill({
                        label: this.state.characterSummary(character.id).planCount + ' 份计划',
                        tone: 'brand',
                        compact: true,
                    })
                }
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            SymbolGlyph(Icons.chevronRightSymbol)
                .fontSize(14)
                .fontColor([Theme.muted])
                .accessibilityLevel('no')
        }.width('100%')
    }

    private planSource: ArrayDataSource<CosProject> = new ArrayDataSource<CosProject>([]);
    private characterSource: ArrayDataSource<Character> = new ArrayDataSource<Character>([]);
    @Local columns: number = 1;

    @Monitor('visiblePlans', 'visibleCharacters')
    private refreshRows(): void {
        this.planSource.replace(this.visiblePlans);
        this.characterSource.replace(this.visibleCharacters);
    }

    @Builder planSectionChips() {
        Row({ space: 8 }) {
            ForEach(PLAN_SECTION_LABELS, (label: string, index: number) => {
                Button(label, { type: ButtonType.Normal, stateEffect: false })
                    .height(34)
                    .padding({ left: 14, right: 14 })
                    .borderRadius(Theme.pillRadius)
                    .fontSize(13)
                    .fontWeight(this.route.section === index ? FontWeight.Medium : FontWeight.Regular)
                    .fontColor(this.route.section === index ? Theme.onAccent : Theme.ink)
                    .backgroundColor(this.route.section === index ? Theme.brand : Theme.surface)
                    .border({ width: 0.8, color: this.route.section === index ? Theme.brand : Theme.line })
                    .visualEffect(pressVisualEffect(this.pressedSection === index && this.state.settings.effects, true, 5, 84))
                    .compositingFilter(pressLightFieldFilter(this.pressedSection === index && this.state.settings.effects))
                    .onTouch((event: TouchEvent): void => {
                        if (event.type === TouchType.Down) {
                            this.pressedSection = index;
                        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                            this.pressedSection = -1;
                        }
                    })
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.route.status = '';
                        this.route.section = index;
                        this.resetPosition();
                    })
                    .accessibilitySelected(this.route.section === index)
                    .accessibilityText(label + '计划')
            }, (label: string) => label)
        }.width('100%')
    }

    @LocalBuilder controls() {
        Column({ space: 10 }) {
            Blank().height(this.topInset).width('100%')
            DashboardSearch({
                value: this.route.query,
                placeholder: this.projects ? '搜索计划 / 角色' : '搜索角色 / 作品',
                label: this.projects ? '搜索计划' : '搜索角色',
                changed: (value: string): void => {
                    this.route.query = value;
                    this.resetPosition();
                },
            })
            if (this.projects) {
                this.planSectionChips()
                Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
                    Select(this.statusOptions())
                        .value(this.route.status ? PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.route.status as ProjectStatus)] : '全部状态')
                        .constraintSize({ minHeight: 36, minWidth: 132 })
                        .margin({ right: 8, bottom: 6 })
                        .backgroundColor(Theme.surface)
                        .borderRadius(12)
                        .onSelect((index: number): void => {
                            vibration.dotVibration();
                            this.route.status = index === 0 ? '' : this.statuses()[index - 1];
                            this.resetPosition();
                        })
                        .accessibilityText('计划状态筛选')
                        .controlSize(ControlSize.SMALL)
                        .font({ size: 13 })
                    Select([{ value: '全部日期' }, { value: '日期待定' }, { value: '日期已过' }, { value: '今天' }, { value: '未来七天' }, { value: '今天及以后' }])
                        .value(['全部日期', '日期待定', '日期已过', '今天', '未来七天', '今天及以后'][['all', 'undated', 'overdue', 'today', 'week', 'future'].indexOf(this.route.dateRange)])
                        .constraintSize({ minHeight: 36, minWidth: 132 })
                        .margin({ bottom: 6 })
                        .backgroundColor(Theme.surface)
                        .borderRadius(12)
                        .onSelect((index: number): void => {
                            vibration.dotVibration();
                            this.route.dateRange = ['all', 'undated', 'overdue', 'today', 'week', 'future'][index];
                            this.resetPosition();
                        })
                        .accessibilityText('计划日期筛选')
                        .controlSize(ControlSize.SMALL)
                        .font({ size: 13 })
                }.width('100%')
                Row({ space: 10 }) {
                    Text(this.visiblePlans.length + ' 份计划')
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .layoutWeight(1)
                    if (this.filtered()) {
                        Button('清除筛选', { type: ButtonType.Normal, stateEffect: false })
                            .height(34)
                            .padding({ left: 10, right: 10 })
                            .borderRadius(12)
                            .backgroundColor(Theme.tint)
                            .fontSize(12)
                            .fontColor(Theme.muted)
                            .onClick((): void => {
                                this.clearFilters();
                            })
                    }
                    Button({ type: ButtonType.Normal, stateEffect: false }) {
                        Row({ space: 4 }) {
                            SymbolGlyph(Icons.profile).fontSize(13).fontColor([Theme.accent]).accessibilityLevel('no')
                            Text('角色库').fontSize(12).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                            SymbolGlyph(Icons.chevronRightSymbol).fontSize(11).fontColor([Theme.accent]).accessibilityLevel('no')
                        }.padding({ left: 10, right: 10 })
                    }.id('plan-role-library')
                        .height(34)
                        .borderRadius(12)
                        .backgroundColor(Theme.tint)
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.open('characters', 'all');
                        })
                        .accessibilityText('打开角色库')
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            } else {
                Row({ space: 10 }) {
                    Select([{ value: '全部角色' }, { value: '已收藏角色' }])
                        .value(this.route.favoriteOnly ? '已收藏角色' : '全部角色')
                        .constraintSize({ minHeight: 36 })
                        .backgroundColor(Theme.surface)
                        .borderRadius(12)
                        .accessibilityText('角色收藏筛选')
                        .onSelect((index: number): void => {
                            vibration.dotVibration();
                            this.route.favoriteOnly = index === 1;
                            this.resetPosition();
                        })
                        .controlSize(ControlSize.SMALL)
                        .font({ size: 13 })
                    Text(this.visibleCharacters.length + ' 位角色')
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .layoutWeight(1)
                        .textAlign(TextAlign.End)
                    if (this.route.query.trim() || this.route.favoriteOnly) {
                        Button('清除筛选', { type: ButtonType.Normal, stateEffect: false })
                            .height(34)
                            .padding({ left: 10, right: 10 })
                            .borderRadius(12)
                            .backgroundColor(Theme.tint)
                            .fontSize(12)
                            .fontColor(Theme.muted)
                            .onClick((): void => {
                                this.clearFilters();
                            })
                    }
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ bottom: 10 })
            .opacity(this.animStep >= 1 ? 1 : 0)
            .translate({ y: this.animStep >= 1 ? 0 : 20 })
    }

    @Builder empty() {
        EmptyState({
            title: this.projects ? '当前范围没有计划' : '当前范围没有角色',
            message: '可以调整筛选条件，或立即添加一条新记录。',
            button: this.projects ? '新建计划' : '添加角色',
            icon: this.projects ? Icons.plan : Icons.profile,
            action: (): void => {
                this.add(this.projects ? 'project' : 'character', '');
            },
        })
    }

    build() {
        List({ space: Theme.cardSpacing, scroller: this.scroller }) {
            ListItemGroup({ header: this.controls, space: Theme.cardSpacing }) {
                if (this.projects) {
                    LazyForEach(this.planSource, (project: CosProject) => {
                        ListItem() {
                            ProjectCard({
                                state: this.state,
                                project: project,
                                open: (): void => {
                                    this.open('project', project.id);
                                },
                            })
                        }.opacity(this.animStep >= 2 ? 1 : 0)
                    }, (project: CosProject) => project.id)
                    if (!this.visiblePlans.length) {
                        ListItem() {
                            this.empty()
                        }
                    }
                } else {
                    LazyForEach(this.characterSource, (character: Character) => {
                        ListItem() {
                            InteractiveCard({
                                label: character.name,
                                hint: '双击打开角色详情',
                                effects: this.state.settings.effects,
                                contentPadding: 14,
                                action: (): void => {
                                    this.route.anchorId = character.id;
                                    this.open('character', character.id);
                                },
                                content: (): void => {
                                    this.characterBody(character);
                                },
                            }).id('character-library:' + character.id)
                        }.opacity(this.animStep >= 2 ? 1 : 0)
                    }, (character: Character) => character.id)
                    if (!this.visibleCharacters.length) {
                        ListItem() {
                            this.empty()
                        }
                    }
                }
            }
            ListItem() {
                Column() {
                    Blank().height(this.bottomInset).width('100%')
                }.width('100%')
            }
        }.id(this.projects ? 'project-list' : 'character-list')
            .width('100%')
            .height('100%')
            .constraintSize({ maxWidth: Theme.contentMaxWidth })
            .lanes(this.columns, 12)
            .cachedCount(4)
            .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onAreaChange((_, area: Area): void => {
                const columns = cardColumnCount(Number(area.width));
                if (this.columns !== columns) {
                    this.columns = columns;
                }
                if (!this.measured && Number(area.height) > 0) {
                    this.measured = true;
                    this.restore();
                }
            })
            .onDidScroll((): void => {
                if (this.measured && !this.restoring) {
                    this.route.offsets[this.displayedSection] = this.scroller.currentOffset().yOffset;
                }
            })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
