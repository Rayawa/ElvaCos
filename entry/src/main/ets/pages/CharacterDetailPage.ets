import { LengthMetrics } from '@kit.ArkUI';
import { SheetContent } from '../components/SheetContent';
import { DetailLink } from '../components/DetailLink';
import { DetailTag } from '../components/DetailTag';
import { Icons } from '../ui/Icons';
import { RESPONSIVE_BREAKPOINT_MEDIUM, RESPONSIVE_BREAKPOINT_LARGE } from '../ui/responsive';
import { EntryCollectionView } from '../views/EntryCollectionView';
import { SheetHeader } from '../components/SheetHeader';
import { appSheetOptions, closeSheet } from '../ui/sheet';
import { StaggerEntrance } from '../ui/motion';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { ReferenceGallery } from '../views/ReferenceGallery';
import { ReferenceImage } from '../models/Planning';
import { ManagedImage } from '../components/ManagedImage';
import { WorkCard } from '../components/WorkCard';
import { ProjectWork } from '../models/ProjectWork';
import { CharacterRoute } from '../viewmodels/CharacterRoute';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Character, CharacterVariant, CosProject } from '../models/Entities';
import { SectionHeading, EmptyState, StatusPill } from '../components/Surfaces';

@ComponentV2
export struct CharacterDetail {
    @Require @Param state: AppState;
    @Require @Param character: Character;
    @Require @Param route: CharacterRoute;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event createPlan: (characterId: string, variantId: string) => void = () => {};
    @Event remove: (kind: string, id: string) => void = () => {};
    @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
    @Local contentWidth: number = 360;
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    private scroller: Scroller = new Scroller();
    private measured: boolean = false;
    private restoring: boolean = true;
    private restoreTimer: number = -1;
    private displayedSection: number = 0;

    aboutToAppear(): void {
        this.displayedSection = this.route.section;
        if (!this.entrance.managed) {
            this.entrance.play(this.getUIContext());
        }
    }

    aboutToDisappear(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        if (!this.entrance.managed) {
            this.entrance.reset();
        }
    }

    @Monitor('route.section', 'route.restoreVersion')
    viewChanged(): void {
        this.displayedSection = this.route.section;
        this.restoreOffset();
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
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false });
            this.restoring = false;
        }, 0);
    }

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    private async favorite(): Promise<void> {
        vibration.dotVibration();
        const c = JSON.parse(JSON.stringify(this.character)) as Character;
        c.favorite = !c.favorite;
        await this.state.saveCharacter(c);
    }

    private variants(): CharacterVariant[] {
        return this.state.variants.filter((v: CharacterVariant) => v.characterId === this.character.id);
    }

    private works(): ProjectWork[] {
        return this.state.workCards.filter((work: ProjectWork) => work.value.characterId === this.character.id);
    }

    private referencesList(): ReferenceImage[] {
        return this.state.references.filter((reference: ReferenceImage) => reference.characterId === this.character.id);
    }

    private entryCount(): number {
        return this.state.entries.filter((entry) => entry.scopeKind === 'character' && entry.scopeId === this.character.id).length;
    }

    private variantPlanCount(variantId: string): number {
        return this.state.projects.filter((project: CosProject) => project.characterId === this.character.id && project.variantId === variantId).length;
    }

    private validVersion(): boolean {
        return !this.route.variantId || this.variants().some((variant: CharacterVariant) => variant.id === this.route.variantId);
    }

    private monogram(): string {
        const trimmed = this.character.name.trim();
        return trimmed ? trimmed.slice(0, 1) : '角';
    }

    private variantMenuItems(variant: CharacterVariant): MenuElement[] {
        return [
            {
                value: '编辑版本',
                action: (): void => {
                    vibration.dotVibration();
                    this.edit('variant', variant.id, this.character.id);
                },
            },
            {
                value: '删除版本',
                action: (): void => {
                    vibration.dotVibration();
                    void this.remove('variant', variant.id);
                },
            },
        ];
    }

    @Builder heroCard() {
        Column({ space: 16 }) {
            if (this.character.cover) {
                Column() {
                    ManagedImage({
                        large: true,
                        sourcePath: this.character.cover,
                        label: this.character.name + '角色封面（不改变计划照片）',
                        fit: ImageFit.Cover,
                        ratio: 1.0,
                        radius: Theme.slotRadius,
                    }).width('100%')
                }.width(176)
                    .padding(4)
                    .backgroundColor(Theme.tint)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.divider })
                    .shadow({ radius: 12, color: Theme.shadow, offsetX: 0, offsetY: 4 })
            } else {
                Stack({ alignContent: Alignment.Center }) {
                    Text(this.monogram())
                        .fontSize(32)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.accent)
                }.width(84)
                    .height(84)
                    .borderRadius(Theme.cardRadius)
                    .backgroundColor(Theme.tint)
                    .border({ width: 1, color: Theme.divider })
            }
            Column({ space: 8 }) {
                Text(this.character.name || '未命名角色')
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .textAlign(TextAlign.Center)
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(Icons.bookmark)
                            .fontSize(13)
                            .fontColor([this.character.workName ? Theme.accent : Theme.muted])
                            .accessibilityLevel('no')
                        Text(this.character.workName || '所属作品待补充')
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(this.character.workName ? Theme.ink : Theme.muted)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }.height(34)
                        .padding({ left: 12, right: 12 })
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(Theme.tint)
                        .border({ width: 0.8, color: Theme.line })
                        .alignItems(VerticalAlign.Center)
                    Button({ type: ButtonType.Normal, stateEffect: false }) {
                        Row({ space: 5 }) {
                            SymbolGlyph(this.character.favorite ? Icons.starFill : Icons.star)
                                .fontSize(15)
                                .fontColor([this.character.favorite ? Theme.warning : Theme.muted])
                                .accessibilityLevel('no')
                            Text(this.character.favorite ? '已收藏' : '收藏')
                                .fontSize(13)
                                .fontWeight(FontWeight.Medium)
                                .fontColor(this.character.favorite ? Theme.warning : Theme.ink)
                        }.padding({ left: 12, right: 12 })
                    }.height(34)
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(this.character.favorite ? Theme.warningBg : Theme.tint)
                        .border({ width: 0.8, color: this.character.favorite ? Theme.warning : Theme.line })
                        .enabled(this.writable())
                        .onClick((): void => {
                            void this.favorite();
                        })
                        .accessibilityText(this.character.favorite ? '取消收藏 ' + this.character.name : '收藏 ' + this.character.name)
                }.width('100%')
            }.width('100%')
                .alignItems(HorizontalAlign.Center)
            if (this.character.description) {
                Text(this.character.description)
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .lineHeight(20)
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .backgroundColor(Theme.tint)
                    .borderRadius(Theme.slotRadius)
            }
            GridRow({
                columns: 12,
                gutter: 10,
                breakpoints: {
                    value: [RESPONSIVE_BREAKPOINT_MEDIUM, RESPONSIVE_BREAKPOINT_LARGE],
                    reference: BreakpointsReference.WindowSize,
                },
            }) {
                GridCol({ span: { xs: 6, sm: 6, md: 6 } }) {
                    DetailTag({
                        label: '造型版本',
                        value: this.variants().length + ' 个',
                        icon: Icons.plan,
                        tone: 'brand',
                        centered: true,
                    })
                }
                GridCol({ span: { xs: 6, sm: 6, md: 6 } }) {
                    Column() {
                        DetailTag({
                            label: '计划履历',
                            value: this.works().length + ' 份',
                            icon: Icons.event,
                            tone: this.works().length > 0 ? 'success' : 'neutral',
                            centered: true,
                        })
                    }.onClick((): void => {
                        vibration.dotVibration();
                        this.route.section = 1;
                    })
                }
                GridCol({ span: { xs: 6, sm: 6, md: 6 } }) {
                    Column() {
                        DetailTag({
                            label: '参考图',
                            value: this.referencesList().length + ' 张',
                            icon: Icons.camera,
                            tone: this.referencesList().length > 0 ? 'warning' : 'neutral',
                            centered: true,
                        })
                    }.onClick((): void => {
                        vibration.dotVibration();
                        this.route.section = 2;
                    })
                }
                GridCol({ span: { xs: 6, sm: 6, md: 6 } }) {
                    Column() {
                        DetailTag({
                            label: '收录条目',
                            value: this.entryCount() + ' 条',
                            icon: Icons.library,
                            tone: 'neutral',
                            centered: true,
                        })
                    }.onClick((): void => {
                        vibration.dotVibration();
                        this.route.entriesOpen = true;
                    })
                }
            }.width('100%')
        }.padding(18)
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.heroRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 10, color: Theme.shadow, offsetX: 0, offsetY: 3 })
    }

    @Builder quickPlanCard() {
        Column({ space: 12 }) {
            Row({ space: 8 }) {
                SymbolGlyph(Icons.plan)
                    .fontSize(16)
                    .fontColor([Theme.accent])
                    .accessibilityLevel('no')
                Text('用此角色发起计划')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                if (this.variants().length > 0) {
                    Text(this.variants().length + ' 个可选版本')
                        .fontSize(12)
                        .fontColor(Theme.muted)
                }
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            Select(new Array<SelectOption>({ value: '不指定版本' }).concat(this.variants().map((variant: CharacterVariant): SelectOption => {
                return { value: variant.name };
            })))
                .value(this.route.variantId ? this.variants().find((variant: CharacterVariant) => variant.id === this.route.variantId)?.name || '版本已不存在' : '不指定版本')
                .width('100%')
                .constraintSize({ minHeight: Theme.controlHeight })
                .backgroundColor(Theme.tint)
                .borderRadius(Theme.pillRadius)
                .accessibilityText('新建计划使用的角色版本')
                .id('character-plan-version')
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.route.variantId = index === 0 ? '' : this.variants()[index - 1].id;
                })
                .controlSize(ControlSize.SMALL)
                .font({ size: 14 })
            if (!this.validVersion()) {
                Text('所选版本已不存在，请重新选择后新建计划。').fontSize(13).fontColor(Theme.danger)
            }
            Button('用这个角色新建计划', { type: ButtonType.Normal, stateEffect: false })
                .constraintSize({ minHeight: 46 })
                .width('100%')
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.brand)
                .fontColor(Theme.onAccent)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .enabled(this.writable() && this.validVersion())
                .onClick((): void => {
                    vibration.dotVibration();
                    this.createPlan(this.character.id, this.route.variantId);
                })
            if (this.state.error) {
                Text(this.state.error).fontSize(13).fontColor(Theme.danger)
            }
        }.padding(16)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
    }

    @Builder variantsSection() {
        Column({ space: 12 }) {
            Row({ space: 10 }) {
                SectionHeading({ title: '造型版本', icon: Icons.plan, trailing: this.variants().length + ' 个' }).layoutWeight(1)
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('添加版本').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                    }.padding({ left: 12, right: 12 })
                }.height(34)
                    .borderRadius(Theme.pillRadius)
                    .backgroundColor(Theme.tint)
                    .border({ width: 0.8, color: Theme.line })
                    .enabled(this.writable())
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.edit('variant', '', this.character.id);
                    })
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            ForEach(this.variants(), (variant: CharacterVariant, index: number) => {
                Column({ space: 10 }) {
                    Row({ space: 10 }) {
                        Stack({ alignContent: Alignment.Center }) {
                            Text(String(index + 1))
                                .fontSize(14)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(Theme.accent)
                        }.width(36)
                            .height(36)
                            .borderRadius(Theme.slotRadius)
                            .backgroundColor(Theme.tint)
                        Column({ space: 3 }) {
                            Text(variant.name)
                                .fontSize(16)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(Theme.ink)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                            Row({ space: 6 }) {
                                StatusPill({
                                    label: this.variantPlanCount(variant.id) > 0 ? '关联 ' + this.variantPlanCount(variant.id) + ' 份计划' : '尚未发起计划',
                                    tone: this.variantPlanCount(variant.id) > 0 ? 'success' : 'neutral',
                                    compact: true,
                                })
                            }
                        }.layoutWeight(1)
                            .alignItems(HorizontalAlign.Start)
                        Button({ type: ButtonType.Circle, stateEffect: false }) {
                            SymbolGlyph($r('sys.symbol.ellipsis_circle'))
                                .fontSize(19)
                                .fontColor([Theme.muted])
                                .accessibilityLevel('no')
                        }.width(34)
                            .height(34)
                            .backgroundColor(Theme.tint)
                            .enabled(this.writable())
                            .bindMenu(this.variantMenuItems(variant))
                            .accessibilityText(variant.name + '，编辑或删除版本')
                    }.width('100%')
                        .alignItems(VerticalAlign.Center)
                    if (variant.notes) {
                        Text(variant.notes)
                            .fontSize(13)
                            .fontColor(Theme.muted)
                            .width('100%')
                            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                            .borderRadius(Theme.badgeRadius)
                            .backgroundColor(Theme.tint)
                    }
                    Row({ space: 8 }) {
                        Button('用此版本新建计划', { type: ButtonType.Normal, stateEffect: false })
                            .layoutWeight(1)
                            .height(38)
                            .borderRadius(Theme.controlRadius)
                            .backgroundColor(Theme.tint)
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.accent)
                            .enabled(this.writable())
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.route.variantId = variant.id;
                                this.createPlan(this.character.id, variant.id);
                            })
                            .accessibilityText('使用版本 ' + variant.name + ' 新建计划')
                        Button('编辑', { type: ButtonType.Normal, stateEffect: false })
                            .height(38)
                            .padding({ left: 14, right: 14 })
                            .borderRadius(Theme.controlRadius)
                            .backgroundColor(Theme.tint)
                            .fontSize(13)
                            .fontColor(Theme.ink)
                            .enabled(this.writable())
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.edit('variant', variant.id, this.character.id);
                            })
                            .accessibilityText('编辑版本 ' + variant.name)
                    }.width('100%')
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
                    .padding(14)
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.line })
                    .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            }, (variant: CharacterVariant) => variant.id)
            if (!this.variants().length) {
                Column({ space: 6 }) {
                    Text('还没有造型版本')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.ink)
                    Text('可选：添加常服、战损或不同期数造型，创建计划时可直接复用。')
                        .fontSize(12)
                        .fontColor(Theme.muted)
                        .textAlign(TextAlign.Center)
                }.width('100%')
                    .padding(16)
                    .alignItems(HorizontalAlign.Center)
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.line })
            }
            Column() {
                DetailLink({
                    title: '收录',
                    value: this.entryCount() + ' 条',
                    icon: Icons.library,
                    componentId: 'character-entry-link',
                    action: (): void => {
                        this.route.entriesOpen = true;
                    },
                })
            }.width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    @Builder profile() {
        if (this.contentWidth >= Theme.wideBreakpoint) {
            Row({ space: 20 }) {
                Column({ space: 14 }) {
                    this.heroCard()
                    this.quickPlanCard()
                }.layoutWeight(5)
                    .alignItems(HorizontalAlign.Start)
                Column({ space: 14 }) {
                    this.variantsSection()
                }.layoutWeight(7)
                    .alignItems(HorizontalAlign.Start)
            }.width('100%')
                .alignItems(VerticalAlign.Top)
        } else {
            this.heroCard()
            this.quickPlanCard()
            this.variantsSection()
        }
    }

    @Builder history() {
        Row({ space: 10 }) {
            DetailTag({
                label: '全部计划',
                value: this.works().length + ' 份',
                icon: Icons.plan,
                tone: 'brand',
                centered: true,
            }).layoutWeight(1)
            DetailTag({
                label: '已完成',
                value: this.works().filter((work: ProjectWork) => work.completed).length + ' 份',
                icon: Icons.done,
                tone: 'success',
                centered: true,
            }).layoutWeight(1)
        }.width('100%')
        SectionHeading({ title: '角色履历', icon: Icons.event, trailing: this.works().length + ' 份计划' })
        Text('按计划 / 活动日期倒序，日期待定列在末尾；卡片反映当前记录。').fontSize(13).fontColor(Theme.muted)
        ForEach(this.works(), (work: ProjectWork) => {
            WorkCard({
                work: work,
                effects: this.state.settings.effects,
                open: (): void => {
                    this.open('project', work.value.projectId);
                },
            })
        }, (work: ProjectWork) => work.value.projectId)
        if (!this.works().length) {
            EmptyState({
                title: '从喜欢到登场',
                message: '创建一份计划，留下场次、作品和一起完成的人。',
                button: '用这个角色新建计划',
                icon: Icons.plan,
                action: (): void => {
                    if (this.writable() && this.validVersion()) {
                        this.createPlan(this.character.id, this.route.variantId);
                    }
                },
            })
        }
    }

    @Builder references() {
        Text('角色参考图用于视觉准备，不计入成片或照片处理数量。').fontSize(13).fontColor(Theme.muted)
        ReferenceGallery({
            state: this.state,
            images: this.referencesList(),
            fullHeight: true,
            add: (): void => {
                void this.state.importReferences('', this.character.id);
            },
            open: (id: string): void => {
                this.open('reference', id);
            },
        })
    }

    @Builder entriesSheet() {
        SheetContent() {
            Column({ space: 14 }) {
                SheetHeader({
                    title: '角色收录',
                    hint: this.character.name,
                    haptic: this.state.settings.haptic,
                    hapticLevel: this.state.settings.hapticLevel,
                    close: (): void => {
                        void closeSheet((): void => {
                            this.route.entriesOpen = false;
                        });
                    },
                })
                EntryCollectionView({
                    embedded: true,
                    state: this.state,
                    route: this.route.entries,
                    componentId: 'character-entries-scroll',
                    active: this.route.entriesOpen,
                    restoreVersion: this.route.restoreVersion,
                    open: (kind: string, id: string): void => {
                        this.open(kind, id);
                    },
                }).layoutWeight(1)
            }.width('100%').height('100%').padding(Theme.pagePadding).backgroundColor(Theme.surface)
        }
    }

    build() {
        Column({ space: 12 }) {
            Scroll(this.scroller) {
                Column({ space: Theme.sectionSpacing }) {
                    Blank().height(Theme.detailTop).width('100%')
                    if (this.route.section === 0) {
                        this.profile()
                    } else if (this.route.section === 1) {
                        this.history()
                    } else {
                        this.references()
                    }
                    Blank().height(Theme.detailFloatingBottom).width('100%')
                }.constraintSize({ maxWidth: this.route.section === 0 && this.contentWidth >= Theme.wideBreakpoint ? Theme.contentMaxWidth : Theme.readingMaxWidth })
                    .alignItems(HorizontalAlign.Start)
                    .width('100%')
                    .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
            }.id('character-detail-scroll')
                .width('100%')
                .layoutWeight(1)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .align(Alignment.Top)
                .onAreaChange((_, area: Area): void => {
                    this.contentWidth = Number(area.width);
                    if (!this.measured && Number(area.height) > 0) {
                        this.measured = true;
                        this.restoreOffset();
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
        }.width('100%')
            .height('100%')
            .bindSheet(this.route.entriesOpen, this.entriesSheet(), appSheetOptions((): void => {
                this.route.entriesOpen = false;
            }, this.sheetEntrance, this.getUIContext()))
    }
}
