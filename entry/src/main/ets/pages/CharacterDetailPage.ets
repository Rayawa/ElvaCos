import { SheetContent } from '../components/SheetContent';
import { DetailLink } from '../components/DetailLink';
import { DetailTag } from '../components/DetailTag';
import { Icons } from '../ui/Icons';
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
import { Character, CharacterVariant } from '../models/Entities';
import { SectionHeading, EmptyState } from '../components/Surfaces';

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

    private validVersion(): boolean {
        return !this.route.variantId || this.variants().some((variant: CharacterVariant) => variant.id === this.route.variantId);
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

    @Builder header() {
        Select(new Array<SelectOption>({ value: '不指定版本' }).concat(this.variants().map((variant: CharacterVariant): SelectOption => {
            return { value: variant.name };
        })))
            .value(this.route.variantId ? this.variants().find((variant: CharacterVariant) => variant.id === this.route.variantId)?.name || '版本已不存在' : '不指定版本')
            .constraintSize({ minHeight: Theme.controlHeight })
            .backgroundColor(Theme.tint)
            .borderRadius(12)
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
            .constraintSize({ minHeight: 48 })
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
    }

    @Builder profile() {
        Column({ space: 12 }) {
            if (this.character.cover) {
                ManagedImage({
                    large: true,
                    sourcePath: this.character.cover,
                    label: this.character.name + '角色封面（不改变计划照片）',
                    fit: ImageFit.Contain,
                    ratio: 1.3,
                    radius: Theme.cardRadius,
                }).width('100%')
                    .aspectRatio(1.3)
            }
            Row({ space: 10 }) {
                Column({ space: 3 }) {
                    Text(this.character.workName || '所属作品待补充')
                        .fontSize(14)
                        .fontColor(this.character.workName ? Theme.ink : Theme.muted)
                        .fontWeight(FontWeight.Medium)
                    if (this.character.description) {
                        Text(this.character.description)
                            .fontSize(13)
                            .fontColor(Theme.muted)
                    }
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(this.character.favorite ? Icons.starFill : Icons.star)
                            .fontSize(16)
                            .fontColor([this.character.favorite ? Theme.warning : Theme.muted])
                            .accessibilityLevel('no')
                        Text(this.character.favorite ? '已收藏' : '收藏')
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(this.character.favorite ? Theme.warning : Theme.ink)
                    }.padding({ left: 12, right: 12 })
                }.height(36)
                    .borderRadius(Theme.controlRadius)
                    .backgroundColor(this.character.favorite ? Theme.warningBg : Theme.tint)
                    .enabled(this.writable())
                    .onClick((): void => {
                        void this.favorite();
                    })
                    .accessibilityText(this.character.favorite ? '取消收藏 ' + this.character.name : '收藏 ' + this.character.name)
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            Row({ space: 10 }) {
                DetailTag({ label: '版本', value: this.variants().length + ' 个', tone: 'brand' }).layoutWeight(1)
                DetailTag({ label: '计划履历', value: this.works().length + ' 份', tone: 'neutral' }).layoutWeight(1)
            }.width('100%')
        }.padding(16)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.heroRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 10, color: Theme.shadow, offsetX: 0, offsetY: 3 })
        Column({ space: 12 }) {
            this.header()
        }.padding(18)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        Row({ space: 10 }) {
            SectionHeading({ title: '角色版本', icon: Icons.plan, trailing: this.variants().length + ' 个' }).layoutWeight(1)
            Button({ type: ButtonType.Normal, stateEffect: false }) {
                Row({ space: 5 }) {
                    SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                    Text('添加版本').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                }.padding({ left: 12, right: 12 })
            }.height(36)
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.tint)
                .enabled(this.writable())
                .onClick((): void => {
                    vibration.dotVibration();
                    this.edit('variant', '', this.character.id);
                })
        }.width('100%')
            .alignItems(VerticalAlign.Center)
        ForEach(this.variants(), (variant: CharacterVariant) => {
            Column({ space: 8 }) {
                Row({ space: 8 }) {
                    Text(variant.name)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                        .layoutWeight(1)
                    Button({ type: ButtonType.Circle, stateEffect: false }) {
                        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
                            .fontSize(19)
                            .fontColor([Theme.muted])
                            .accessibilityLevel('no')
                    }.width(36)
                        .height(36)
                        .backgroundColor(Theme.tint)
                        .enabled(this.writable())
                        .bindMenu(this.variantMenuItems(variant))
                        .accessibilityText(variant.name + '，编辑或删除版本')
                }.width('100%')
                if (variant.notes) {
                    Text(variant.notes).fontSize(13).fontColor(Theme.muted)
                }
                Button('用此版本新建计划', { type: ButtonType.Normal, stateEffect: false })
                    .height(38)
                    .padding({ left: 14, right: 14 })
                    .borderRadius(12)
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
            }.width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(16)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }, (variant: CharacterVariant) => variant.id)
        if (!this.variants().length) {
            Text('可选：添加服装或造型版本，下次创建计划时复用。').fontSize(13).fontColor(Theme.muted)
        }
        Column() {
            DetailLink({
                title: '收录',
                value: this.state.entries.filter((entry) => entry.scopeKind === 'character' && entry.scopeId === this.character.id).length + ' 条',
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
    }

    @Builder history() {
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
            images: this.state.references.filter((reference: ReferenceImage) => reference.characterId === this.character.id),
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
                }.constraintSize({ maxWidth: Theme.readingMaxWidth })
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
