import { SheetContent } from '../components/SheetContent';
import { DetailLink } from '../components/DetailLink';
import { DashboardSplitLayout } from '../views/DashboardSplitLayout';
import { RollingNumber } from '../components/RollingNumber';
import { MetaRow } from '../components/MetaRow';
import { Icons } from '../ui/Icons';
import { displayName, formatTimestamp } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { WorkCard } from '../components/WorkCard';
import { DiaryEntry, ProjectStatus, Asset, AssetStatus, ChecklistItem, CosProject, CosEvent } from '../models/Entities';
import { EntryCollectionView } from '../views/EntryCollectionView';
import { budgetLabel } from '../models/PlanReadiness';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, PROJECT_LABELS, PROJECT_STATUSES, MIN_SPLIT_HEIGHT } from '../models/constants';
import { PressFeedback } from '../ui/pressFeedback';
import { StaggerEntrance } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { TeamMember, ReferenceImage } from '../models/Planning';
import { ReferenceGallery } from '../views/ReferenceGallery';
import { PreparationCategory, PreparationTask, preparationKeys } from '../models/Preparation';
import { PreparationTemplatePicker } from '../components/PreparationTemplatePicker';
import { appSheetOptions, closeSheet } from '../ui/sheet';
import { SheetHeader } from '../components/SheetHeader';
import { confirm } from '../ui/Confirm';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { ProjectRoute } from '../viewmodels/ProjectRoute';
import { InteractiveCard, SectionHeading, StatusPill, EmptyState, PillTone } from '../components/Surfaces';
import { planDate } from '../models/Rules';

@ComponentV2
export struct ProjectDetail {
    @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Require @Param state: AppState;
    @Param project: CosProject = new CosProject();
    @Param route: ProjectRoute = new ProjectRoute('');
    @Param topInset: number = Theme.detailTop;
    @Event open: (kind: string, id: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string) => void = () => {};
    @Local templateKeys: string[] = preparationKeys(1);
    @Local templateMode: number = 1;
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    private scroller: Scroller = new Scroller();
    private displayedSection: number = 0;
    private viewportTop: number = 0;
    @Local viewportWidth: number = 360;
    @Local viewportHeight: number = 800;
    private measured: boolean = false;
    private focusY: number | undefined = undefined;
    private scrollTimer: number = -1;
    private restoring: boolean = true;
    @Local focusFeedback: string = '';

    aboutToAppear(): void {
        this.displayedSection = this.route.section;
        const target = this.state.preparationTasks.find((task: PreparationTask) => task.id === this.route.focusTaskId && task.projectId === this.project.id);
        if (target && !this.route.expandedCategories.includes(target.categoryId)) {
            this.route.expandedCategories = this.route.expandedCategories.concat(target.categoryId);
        }
        if (target?.done) {
            this.route.showCompleted = true;
        }
        const packing = this.state.checklist.some((item: ChecklistItem) => item.id === this.route.focusPackingId && item.projectId === this.project.id);
        if (!this.route.focusHandled && (this.route.focusTaskId && !target || this.route.focusPackingId && !packing)) {
            this.route.focusHandled = true;
            this.focusFeedback = '原事项已不存在，保留当前计划与附近位置。';
        }
        this.restoreOffset();
        if (!this.entrance.managed) {
            this.entrance.play(this.getUIContext());
        }
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
        if (this.scrollTimer >= 0) {
            clearTimeout(this.scrollTimer);
        }
        if (!this.entrance.managed) {
            this.entrance.reset();
        }
    }

    @Computed
    private get isSplitOverview(): boolean {
        return this.route.section === 0 && this.viewportWidth >= Theme.wideBreakpoint && this.viewportHeight >= MIN_SPLIT_HEIGHT;
    }

    @Monitor('route.section', 'route.restoreVersion')
    private sectionChanged(): void {
        this.displayedSection = this.route.section;
        this.restoreOffset();
    }

    private pendingFocus(): boolean {
        return !this.route.focusHandled && Boolean(this.route.section === 1 ? this.route.focusTaskId : this.route.section === 2 ? this.route.focusPackingId : '');
    }

    private restoreOffset(): void {
        if (!this.measured || this.pendingFocus()) {
            return;
        }
        if (this.scrollTimer >= 0) {
            clearTimeout(this.scrollTimer);
        }
        this.restoring = true;
        this.scrollTimer = setTimeout((): void => {
            this.scrollTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false });
            this.restoring = false;
        }, 0);
    }

    private focusItem(id: string, area: Area): void {
        if (!this.pendingFocus() || id !== (this.route.section === 2 ? this.route.focusPackingId : this.route.focusTaskId)) {
            return;
        }
        this.focusY = Number(area.globalPosition.y);
        this.focusAfterMeasure();
    }

    private focusAfterMeasure(): void {
        if (!this.measured || this.focusY === undefined || !this.pendingFocus()) {
            return;
        }
        if (this.scrollTimer >= 0) {
            clearTimeout(this.scrollTimer);
        }
        this.restoring = true;
        this.scrollTimer = setTimeout((): void => {
            this.scrollTimer = -1;
            if (!this.pendingFocus() || this.focusY === undefined) {
                this.restoreOffset();
                return;
            }
            const offset = Math.max(0, this.scroller.currentOffset().yOffset + this.focusY - this.viewportTop - this.topInset - 12);
            this.scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
            this.route.offsets[this.displayedSection] = offset;
            this.route.focusHandled = true;
            this.focusY = undefined;
            this.restoring = false;
        }, 0);
    }

    private items(): ChecklistItem[] {
        const items = this.state.checklist.filter((item: ChecklistItem) => item.projectId === this.project.id)
            .sort((a: ChecklistItem, b: ChecklistItem) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
        for (const item of items) {
            if (!this.route.packingOrder.includes(item.id)) {
                this.route.packingOrder.push(item.id);
            }
        }
        return items.sort((a: ChecklistItem, b: ChecklistItem) => this.route.packingOrder.indexOf(a.id) - this.route.packingOrder.indexOf(b.id));
    }

    private equipment(): Asset[] {
        return this.state.projectAssets(this.project.id)
            .sort((a: Asset, b: Asset) => Number(a.status === AssetStatus.OWNED) - Number(b.status === AssetStatus.OWNED) || a.name.localeCompare(b.name));
    }

    private linked(asset: Asset): boolean {
        return this.state.projectAssets(this.project.id).some((a: Asset) => a.id === asset.id);
    }

    private location(item: ChecklistItem): string {
        return this.state.assets.find((a: Asset) => a.id === item.assetId)?.location || (item.assetId ? '存放位置待补充' : '随身物品');
    }

    private packingAssetStatus(item: ChecklistItem): string {
        const asset = this.state.assets.find((value: Asset) => value.id === item.assetId);
        return asset ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] : '装备已不存在';
    }

    private assetTone(status: AssetStatus): PillTone {
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

    private projectStatusTone(): PillTone {
        if (this.project.status === ProjectStatus.COMPLETED || this.project.status === ProjectStatus.READY) {
            return 'success';
        }
        if (this.project.status === ProjectStatus.SHOOTING || this.project.status === ProjectStatus.EVENT) {
            return 'warning';
        }
        if (this.project.status === ProjectStatus.ARCHIVED) {
            return 'neutral';
        }
        return 'brand';
    }

    private async unlink(asset: Asset): Promise<void> {
        const usage = this.state.assetUsage(asset.id);
        const ids = usage.checklist.filter((item: ChecklistItem) => item.projectId === this.project.id).map((item: ChecklistItem) => item.id);
        if (await confirm(this.getUIContext(), '解除装备关联？', usage.unlinkMessage(this.project), '解除关联')) {
            await this.state.unlinkAsset(this.project.id, asset.id, ids);
        }
    }

    @Builder linkSheet() {
        Column({ space: 14 }) {
            SheetHeader({
                title: '从衣柜添加',
                hint: '已有装备可以在多份计划里复用',
                haptic: this.state.settings.haptic,
                hapticLevel: this.state.settings.hapticLevel,
                close: (): void => {
                    this.route.linking = false;
                },
            }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
            List({ space: 10 }) {
                ForEach(this.state.assets, (asset: Asset) => {
                    ListItem() {
                        Button({ type: ButtonType.Normal, stateEffect: false }) {
                            Row({ space: 10 }) {
                                Stack({ alignContent: Alignment.Center }) {
                                    SymbolGlyph(Icons.assetTypeSymbol(asset.type)).fontSize(18).fontColor([Theme.accent]).accessibilityLevel('no')
                                }.width(36).height(36).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
                                Column({ space: 4 }) {
                                    Text(displayName(asset.name)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                                    ContextRow({
                                        label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)],
                                        text: asset.location || '位置待补充',
                                        tone: this.assetTone(asset.status),
                                    })
                                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                                Row({ space: 4 }) {
                                    if (this.linked(asset)) {
                                        SymbolGlyph(Icons.done).fontSize(15).fontColor([Theme.success]).accessibilityLevel('no')
                                        Text('已添加').fontSize(13).fontColor(Theme.success)
                                    } else {
                                        SymbolGlyph(Icons.add).fontSize(15).fontColor([Theme.accent]).accessibilityLevel('no')
                                        Text('添加').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                                    }
                                }
                            }.padding(12).width('100%')
                        }.width('100%')
                            .borderRadius(Theme.controlRadius)
                            .backgroundColor(Theme.bg)
                            .border({ width: 0.8, color: Theme.line })
                            .enabled(!this.state.busy && !this.linked(asset))
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.state.linkAsset(this.project.id, asset);
                            })
                            .accessibilityText('关联 ' + asset.name)
                            .visualEffect(this.feedback.effect('link-asset:' + asset.id, true))
                            .compositingFilter(this.feedback.filter('link-asset:' + asset.id, true))
                            .attributeModifier(this.feedback.control('link-asset:' + asset.id, true))
                    }
                }, (asset: Asset) => asset.id)
            }.layoutWeight(1)
                .width('100%')
                .edgeEffect(EdgeEffect.Spring)
                .opacity(this.sheetEntrance.step >= 2 ? 1 : 0)
                .translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
            if (this.state.assets.length === 0) {
                Text('衣柜还是空的，先添加一件装备。').fontSize(13).fontColor(Theme.muted)
            }
            Button({ type: ButtonType.Normal, stateEffect: false }) {
                Row({ space: 6 }) {
                    SymbolGlyph(Icons.add).fontSize(16).fontColor([Theme.accent]).accessibilityLevel('no')
                    Text('新装备').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                }
            }.accessibilityText('新装备')
                .width('100%')
                .constraintSize({ minHeight: 46 })
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.tint)
                .enabled(!this.state.busy)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.route.linking = false;
                    this.edit('asset', '', this.project.id);
                })
                .visualEffect(this.feedback.effect('button-2'))
                .compositingFilter(this.feedback.filter('button-2'))
                .attributeModifier(this.feedback.control('button-2'))
                .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
                .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
            Button('完成', { type: ButtonType.Normal, stateEffect: false })
                .accessibilityText('完成')
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.brand)
                .fontColor(Theme.onAccent)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.route.linking = false;
                })
                .visualEffect(this.feedback.effect('button-3'))
                .compositingFilter(this.feedback.filter('button-3'))
                .attributeModifier(this.feedback.control('button-3'))
                .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
                .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
        }.padding(Theme.pagePadding)
            .width('100%')
            .height('100%')
            .backgroundColor(Theme.surface)
    }

    @Builder checkButton(item: ChecklistItem) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
            Row({ space: 5 }) {
                SymbolGlyph(item.done ? Icons.done : Icons.pending)
                    .fontSize(16)
                    .fontColor([item.done ? Theme.success : Theme.onAccent])
                    .accessibilityLevel('no')
                Text(item.done ? '已装包' : '装包')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(item.done ? Theme.success : Theme.onAccent)
            }.padding({ left: 12, right: 12 })
        }.constraintSize({ minWidth: 88, minHeight: this.route.outing ? 56 : 42 })
            .borderRadius(Theme.controlRadius)
            .backgroundColor(item.done ? Theme.successBg : Theme.brand)
            .enabled(!this.state.busy && !this.state.staleScopes.length)
            .onClick((): void => {
                vibration.dotVibration();
                void this.state.toggleChecklist(item);
            })
            .accessibilityText(item.label + (item.done ? '，已装包，点击取消' : '，点击确认装包'))
            .visualEffect(this.feedback.effect('packing-confirm:' + item.id, false))
            .compositingFilter(this.feedback.filter('packing-confirm:' + item.id, false))
            .attributeModifier(this.feedback.control('packing-confirm:' + item.id, false))
    }

    @Builder activeSheet() {
        SheetContent() {
            if (this.route.contextSheet) {
                this.contextSheet()
            } else if (this.route.sheetKind === 0) {
                this.preparationSheet()
            } else {
                this.linkSheet()
            }
        }
    }

    /** 名称由原生标题栏承载，这里显示状态与日期上下文。 */
    @Builder header() {
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            StatusPill({
                label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)],
                tone: this.projectStatusTone(),
            }).margin({ right: 8, bottom: 4 })
            if (planDate(this.project, this.state.events)) {
                MetaRow({
                    icon: Icons.event,
                    text: planDate(this.project, this.state.events),
                }).margin({ right: 8, bottom: 4 })
                if (this.state.readiness(this.project.id).dateFromEvent) {
                    StatusPill({ label: '来自活动', tone: 'neutral', compact: true }).margin({ bottom: 4 })
                }
            }
        }.width('100%')
        if (this.project.shootingTime) {
            ContextRow({ label: '拍摄 / 约拍', text: this.project.shootingTime }).id('project-shooting-time')
        }
    }

    private categorySummary(id: string): string {
        const category = this.state.readiness(this.project.id).prep.categories.find((item) => item.id === id);
        return category ? category.done + '/' + category.total + ' 完成' : '尚未添加任务';
    }

    private categories(): PreparationCategory[] {
        return this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.project.id);
    }

    private tasks(categoryId: string): PreparationTask[] {
        return this.state.preparationTasks.filter((t: PreparationTask) => t.categoryId === categoryId)
            .sort((a: PreparationTask, b: PreparationTask) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
    }

    private visibleTasks(categoryId: string): PreparationTask[] {
        const tasks = this.tasks(categoryId);
        const visible = this.route.showCompleted ? tasks : tasks.filter((task: PreparationTask) => !task.done);
        return this.route.expandedCategories.includes(categoryId) ? visible : visible.slice(0, 1);
    }

    private expandCategory(id: string): void {
        vibration.dotVibration();
        this.route.expandedCategories = this.route.expandedCategories.includes(id) ? this.route.expandedCategories.filter((key: string) => key !== id) : this.route.expandedCategories.concat(id);
    }

    @Builder preparationSheet() {
        Column({ space: 14 }) {
            SheetHeader({
                title: '准备任务',
                hint: '准备完成与装包确认分别记录',
                haptic: this.state.settings.haptic,
                hapticLevel: this.state.settings.hapticLevel,
                close: (): void => {
                    this.route.preparing = false;
                },
            }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
            Row({ space: 10 }) {
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 6 }) {
                        SymbolGlyph(Icons.add).fontSize(15).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('自定义分类').fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                    }
                }.accessibilityText('自定义分类')
                    .layoutWeight(1)
                    .constraintSize({ minHeight: 44 })
                    .borderRadius(Theme.controlRadius)
                    .backgroundColor(Theme.tint)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.route.preparing = false;
                        this.edit('category', '', this.project.id);
                    })
                    .visualEffect(this.feedback.effect('button-6'))
                    .compositingFilter(this.feedback.filter('button-6'))
                    .attributeModifier(this.feedback.control('button-6'))
                    .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
                    .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 6 }) {
                        SymbolGlyph(Icons.add).fontSize(15).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('自定义任务').fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                    }
                }.accessibilityText('自定义任务')
                    .layoutWeight(1)
                    .constraintSize({ minHeight: 44 })
                    .borderRadius(Theme.controlRadius)
                    .backgroundColor(Theme.tint)
                    .enabled(!this.state.busy && this.categories().length > 0)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.route.preparing = false;
                        this.edit('preparation', '', this.project.id);
                    })
                    .visualEffect(this.feedback.effect('button-7'))
                    .compositingFilter(this.feedback.filter('button-7'))
                    .attributeModifier(this.feedback.control('button-7'))
                    .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
                    .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
            }.width('100%')
            Scroll() {
                PreparationTemplatePicker({
                    keys: this.templateKeys,
                    mode: this.templateMode,
                    change: (keys: string[], mode: number): void => {
                        this.templateKeys = keys;
                        this.templateMode = mode;
                    },
                })
            }.layoutWeight(1)
                .width('100%')
                .edgeEffect(EdgeEffect.Spring)
                .opacity(this.sheetEntrance.step >= 2 ? 1 : 0)
                .translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
            Button(this.state.busy ? '添加中…' : '补入所选任务', { type: ButtonType.Normal, stateEffect: false })
                .accessibilityText(this.state.busy ? '正在添加准备任务' : '补入所选准备任务')
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.brand)
                .fontColor(Theme.onAccent)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .enabled(!this.state.busy && this.templateKeys.length > 0)
                .onClick(async (): Promise<void> => {
                    vibration.dotVibration();
                    if (await this.state.addPreparationTemplate(this.project.id, this.templateKeys)) {
                        this.route.preparing = false;
                    }
                })
                .visualEffect(this.feedback.effect('button-8'))
                .compositingFilter(this.feedback.filter('button-8'))
                .attributeModifier(this.feedback.control('button-8'))
                .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
                .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
            Text('同名分类和任务不会重复添加，也不会重置已有完成状态。').fontSize(12).fontColor(Theme.muted)
        }.padding(Theme.pagePadding)
            .width('100%')
            .height('100%')
            .backgroundColor(Theme.surface)
    }

    @Builder preparation() {
        Column({ space: 12 }) {
            Row({ space: 10 }) {
                Text('准备进度')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.muted)
                RollingNumber({
                    value: this.state.readiness(this.project.id).prep.done,
                    fontSize: 22,
                    color: Theme.accent,
                    accessibilityLabel: '准备已完成数量',
                })
                Text('/ ' + this.state.readiness(this.project.id).prep.total)
                    .fontSize(15)
                    .fontColor(Theme.muted)
                    .layoutWeight(1)
                if (this.state.readiness(this.project.id).prep.waiting) {
                    StatusPill({ label: '在途 ' + this.state.readiness(this.project.id).prep.waiting, tone: 'warning', compact: true })
                }
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            Row() {
                Text('显示已完成')
                    .fontSize(14)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.route.showCompleted })
                    .onChange((value: boolean): void => {
                        vibration.dotVibration();
                        this.route.showCompleted = value;
                    })
                    .accessibilityText('显示已完成准备任务')
            }.width('100%')
                .constraintSize({ minHeight: 40 })
        }.width('100%')
            .padding(14)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
    }

    private categoryMenuItems(category: PreparationCategory): MenuElement[] {
        return [
            {
                value: '添加任务',
                action: (): void => {
                    vibration.dotVibration();
                    this.edit('preparation', '', category.id);
                },
            },
            {
                value: '编辑分类',
                action: (): void => {
                    vibration.dotVibration();
                    this.edit('category', category.id, this.project.id);
                },
            },
            {
                value: '删除分类',
                action: (): void => {
                    vibration.dotVibration();
                    void this.remove('category', category.id);
                },
            },
        ];
    }

    private taskMenuItems(task: PreparationTask): MenuElement[] {
        return [
            {
                value: '编辑任务',
                action: (): void => {
                    vibration.dotVibration();
                    this.edit('preparation', task.id, this.project.id);
                },
            },
            {
                value: '删除任务',
                action: (): void => {
                    vibration.dotVibration();
                    void this.remove('preparation', task.id);
                },
            },
        ];
    }

    @Builder preparationList() {
        SectionHeading({ title: '分类准备任务', icon: Icons.check })
        if (this.categories().length === 0) {
            EmptyState({
                title: '这次要准备哪些事？',
                message: '可选常用模板、复用装备模板，或自己添加分类。原有打包记录会保留。',
                button: '添加准备任务',
                icon: Icons.check,
                action: (): void => {
                    this.route.sheetKind = 0;
                    this.route.preparing = true;
                },
            })
        }
        ForEach(this.categories(), (category: PreparationCategory) => {
            Column({ space: 8 }) {
                Row({ space: 8 }) {
                    Button({ type: ButtonType.Normal, stateEffect: false }) {
                        Column({ space: 4 }) {
                            Text(category.name)
                                .fontSize(17)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(Theme.ink)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                            Text(this.categorySummary(category.id))
                                .fontSize(12)
                                .fontColor(Theme.muted)
                        }.alignItems(HorizontalAlign.Start)
                            .width('100%')
                            .padding({ top: 4, bottom: 4 })
                    }.backgroundColor(Color.Transparent)
                        .layoutWeight(1)
                        .constraintSize({ minHeight: 44 })
                        .onClick((): void => {
                            this.expandCategory(category.id);
                        })
                        .accessibilityText((this.route.expandedCategories.includes(category.id) ? '收起分类 ' : '展开分类 ') + category.name)
                    Button({ type: ButtonType.Circle, stateEffect: false }) {
                        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
                            .fontSize(20)
                            .fontColor([Theme.muted])
                            .accessibilityLevel('no')
                    }.width(36)
                        .height(36)
                        .backgroundColor(Theme.tint)
                        .enabled(!this.state.busy && !this.state.staleScopes.length)
                        .bindMenu(this.categoryMenuItems(category))
                        .accessibilityText(category.name + '，添加任务、编辑或删除分类')
                }.width('100%')
                    .alignItems(VerticalAlign.Center)
                ForEach(this.visibleTasks(category.id), (task: PreparationTask) => {
                    Row({ space: 10 }) {
                        Button({ type: ButtonType.Circle, stateEffect: false }) {
                            SymbolGlyph(task.done ? Icons.done : Icons.pending)
                                .fontSize(20)
                                .fontColor([task.done ? Theme.success : Theme.accent])
                                .accessibilityLevel('no')
                        }.width(38)
                            .height(38)
                            .backgroundColor(task.done ? Theme.successBg : Theme.tint)
                            .enabled(!this.state.busy)
                            .onClick((): void => {
                                vibration.dotVibration();
                                void this.state.togglePreparation(task);
                            })
                            .accessibilityText(category.name + '，' + task.label + (task.done ? '，已完成，点击取消' : '，点击完成'))
                        Column({ space: 4 }) {
                            Text(displayName(task.label))
                                .fontSize(15)
                                .fontWeight(FontWeight.Medium)
                                .fontColor(task.done ? Theme.muted : Theme.ink)
                                .decoration({ type: task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
                            if (!task.done && (task.waitingOn || task.waitingUntil)) {
                                ContextRow({
                                    label: '在途',
                                    text: (task.waitingOn || '等待外部进展') + (task.waitingUntil ? '，至 ' + task.waitingUntil : ''),
                                    tone: 'brand',
                                })
                            } else if (task.dueDate) {
                                ContextRow({
                                    label: !task.done && task.dueDate < this.state.localDate ? '逾期' : '截止',
                                    text: task.dueDate,
                                    tone: !task.done && task.dueDate < this.state.localDate ? 'danger' : 'warning',
                                })
                            }
                            if (task.notes && !task.dueDate && (task.done || !task.waitingOn && !task.waitingUntil)) {
                                Text(task.notes).fontSize(12).fontColor(Theme.muted).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                            }
                        }.layoutWeight(1)
                            .alignItems(HorizontalAlign.Start)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.edit('preparation', task.id, this.project.id);
                            })
                            .accessibilityText('编辑任务 ' + task.label)
                        Button({ type: ButtonType.Circle, stateEffect: false }) {
                            SymbolGlyph($r('sys.symbol.ellipsis_circle'))
                                .fontSize(18)
                                .fontColor([Theme.muted])
                                .accessibilityLevel('no')
                        }.width(34)
                            .height(34)
                            .backgroundColor(Color.Transparent)
                            .enabled(!this.state.busy && !this.state.staleScopes.length)
                            .bindMenu(this.taskMenuItems(task))
                            .accessibilityText(task.label + '，编辑或删除任务')
                    }.id('preparation-row:' + task.id)
                        .width('100%')
                        .padding(10)
                        .backgroundColor(Theme.tint)
                        .border({ width: task.id === this.route.focusTaskId ? 1.5 : 0.8, color: task.id === this.route.focusTaskId ? Theme.accent : Theme.line })
                        .borderRadius(12)
                        .onAreaChange((_, area: Area): void => {
                            this.focusItem(task.id, area);
                        })
                }, (task: PreparationTask) => task.id)
                if (this.tasks(category.id).length === 0) {
                    Text('点右上角菜单添加第一项任务').fontSize(12).fontColor(Theme.muted)
                }
            }.padding(14)
                .width('100%')
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
                .alignItems(HorizontalAlign.Start)
        }, (category: PreparationCategory) => category.id)
    }

    @Builder equipmentList() {
        SectionHeading({ title: '本次装备', icon: Icons.library, trailing: this.state.readiness(this.project.id).equipment.total + ' 件' })
        ForEach(this.equipment(), (asset: Asset) => {
            Row({ space: 10 }) {
                Stack({ alignContent: Alignment.Center }) {
                    SymbolGlyph(Icons.assetTypeSymbol(asset.type)).fontSize(18).fontColor([Theme.accent]).accessibilityLevel('no')
                }.width(36).height(36).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
                Column({ space: 4 }) {
                    Text(displayName(asset.name))
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.ink)
                    ContextRow({
                        label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)],
                        text: asset.location || '存放位置待补充',
                        tone: this.assetTone(asset.status),
                    })
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.open('asset', asset.id);
                    })
                    .accessibilityText(asset.name + '，打开装备详情')
                Button('移除', { type: ButtonType.Normal, stateEffect: false })
                    .height(34)
                    .padding({ left: 10, right: 10 })
                    .borderRadius(12)
                    .backgroundColor(Theme.tint)
                    .fontSize(12)
                    .fontColor(Theme.muted)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        void this.unlink(asset);
                    })
                    .accessibilityText('解除 ' + asset.name + ' 的计划关联')
            }.width('100%')
                .padding(14)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }, (asset: Asset) => asset.id)
        if (this.state.projectAssets(this.project.id).length === 0) {
            Row({ space: 10 }) {
                Text('还没有关联装备，可以新建或从衣柜复用。')
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .layoutWeight(1)
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('新装备').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                    }.padding({ left: 12, right: 12 })
                }.accessibilityText('新装备')
                    .height(36)
                    .borderRadius(12)
                    .backgroundColor(Theme.tint)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.edit('asset', '', this.project.id);
                    })
            }.width('100%')
                .padding(14)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
        }
        if (this.project.notes) {
            SectionHeading({ title: '备注', icon: Icons.note })
            Text(this.project.notes)
                .fontSize(14)
                .fontColor(Theme.muted)
                .padding(14)
                .width('100%')
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
        }
    }

    @Builder contextSheet() {
        Column({ space: 16 }) {
            SheetHeader({
                title: this.route.contextSheet === 'team' ? '团队分工' : this.route.contextSheet === 'references' ? '准备参考图' : this.route.contextSheet === 'records' ? '计划记录' : '计划收录',
                haptic: this.state.settings.haptic,
                hapticLevel: this.state.settings.hapticLevel,
                closeSize: 48,
                close: (): void => {
                    void closeSheet((): void => {
                        this.route.contextSheet = '';
                    });
                },
            })
            if (this.route.contextSheet === 'entries') {
                EntryCollectionView({
                    embedded: true,
                    state: this.state,
                    route: this.route.entries,
                    componentId: 'project-entries-scroll',
                    active: this.route.contextSheet === 'entries',
                    restoreVersion: this.route.restoreVersion,
                    open: (kind: string, id: string): void => {
                        this.open(kind, id);
                    },
                }).layoutWeight(1)
            } else {
                Scroll() {
                    Column({ space: 14 }) {
                        if (this.route.contextSheet === 'team') {
                            this.team()
                        } else if (this.route.contextSheet === 'records') {
                            ContextRow({ label: '自动记录', text: displayName(this.project.name) })
                            ForEach(this.state.projectDiary(this.project.id), (entry: DiaryEntry) => {
                                Column({ space: 6 }) {
                                    Text(formatTimestamp(entry.createdAt)).fontSize(12).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                                    Text(entry.text).fontSize(15).fontColor(Theme.ink)
                                }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(Theme.tint).borderRadius(12)
                            }, (entry: DiaryEntry) => entry.id)
                            if (!this.state.projectDiary(this.project.id).length) {
                                Text('这份计划还没有操作记录，后续记录会显示在这里。').fontSize(14).fontColor(Theme.muted)
                            }
                        } else if (this.route.contextSheet === 'references') {
                            ReferenceGallery({
                                state: this.state,
                                images: this.state.references.filter((image: ReferenceImage) => image.projectId === this.project.id),
                                add: (): void => {
                                    void this.state.importReferences(this.project.id);
                                },
                                open: (id: string): void => {
                                    this.open('reference', id);
                                },
                            })
                        }
                    }.width('100%').alignItems(HorizontalAlign.Start)
                }.layoutWeight(1).width('100%').edgeEffect(EdgeEffect.Spring)
            }
        }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
    }

    @Builder team() {
        Row({ space: 8 }) {
            SectionHeading({ title: '团队分工', icon: Icons.profile }).layoutWeight(1)
            Button({ type: ButtonType.Normal, stateEffect: false }) {
                Row({ space: 5 }) {
                    SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.onAccent]).accessibilityLevel('no')
                    Text('添加成员').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.onAccent)
                }.padding({ left: 12, right: 12 })
            }.accessibilityText('添加成员')
                .height(36)
                .borderRadius(Theme.pillRadius)
                .backgroundColor(Theme.brand)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.edit('team', '', this.project.id);
                })
        }.width('100%')
        ForEach(this.state.team.filter((m: TeamMember) => m.projectId === this.project.id), (m: TeamMember) => {
            Row({ space: 10 }) {
                Column({ space: 4 }) {
                    ContextRow({ label: m.role, text: m.name, prominent: true })
                    if (m.notes) {
                        Text(m.notes).fontSize(12).fontColor(Theme.muted)
                    }
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.edit('team', m.id, this.project.id);
                    })
                    .accessibilityText('编辑团队成员 ' + m.name)
                Button({ type: ButtonType.Circle, stateEffect: false }) {
                    SymbolGlyph(Icons.remove).fontSize(16).fontColor([Theme.danger]).accessibilityLevel('no')
                }.width(36)
                    .height(36)
                    .backgroundColor(Theme.dangerBg)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        void this.remove('team', m.id);
                    })
                    .accessibilityText('删除团队成员 ' + m.name)
            }.width('100%')
                .padding(14)
                .backgroundColor(Theme.tint)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
        }, (m: TeamMember) => m.id)
        if (!this.state.team.some((m: TeamMember) => m.projectId === this.project.id)) {
            Text('记录毛娘、妆娘、摄影、后勤和后期的人选。').fontColor(Theme.muted).fontSize(13)
        }
    }

    private nextActionLabel(): string {
        const readiness = this.state.readiness(this.project.id);
        if (readiness.hint?.label === '日程') {
            return '安排日期';
        }
        if (readiness.prep.next || readiness.prep.waiting || readiness.equipment.unavailable.length || !readiness.prep.total) {
            return '查看准备';
        }
        return '确认打包';
    }

    private nextAction(): void {
        vibration.dotVibration();
        if (this.nextActionLabel() === '安排日期') {
            this.edit('project', this.project.id, '');
        } else {
            this.route.section = this.nextActionLabel() === '确认打包' ? 2 : 1;
        }
    }

    @Builder overviewHero() {
        if (![ProjectStatus.COMPLETED, ProjectStatus.ARCHIVED].includes(this.project.status)) {
            Column({ space: 12 }) {
                StatusPill({ label: this.state.readiness(this.project.id).hint?.label || '下一步', tone: 'brand' })
                Text(displayName(this.state.readiness(this.project.id).hint?.text || this.state.readiness(this.project.id).pack.pending[0]?.label || '继续整理这份计划'))
                    .fontSize(21)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(2)
                Button(this.nextActionLabel(), { type: ButtonType.Normal, stateEffect: false })
                    .width('100%')
                    .height(48)
                    .borderRadius(Theme.controlRadius)
                    .backgroundColor(Theme.brand)
                    .fontColor(Theme.onAccent)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .onClick((): void => {
                        this.nextAction();
                    })
                    .visualEffect(this.feedback.effect('project-next-cta'))
                    .compositingFilter(this.feedback.filter('project-next-cta'))
                    .attributeModifier(this.feedback.control('project-next-cta'))
            }.padding(18)
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.heroRadius)
                .border({ width: 0.8, color: Theme.divider })
                .shadow({ radius: 12, color: Theme.shadow, offsetX: 0, offsetY: 4 })
        } else if (this.state.projectWork(this.project.id)) {
            WorkCard({
                work: this.state.projectWork(this.project.id)!,
                effects: this.state.settings.effects,
                hint: '双击查看本计划照片',
                open: (): void => {
                    this.route.section = 3;
                },
            })
        }
    }

    @Builder prepTileBody() {
        Column({ space: 6 }) {
            Row({ space: 6 }) {
                MetaRow({ icon: Icons.check, text: '准备完成', color: Theme.muted })
                Blank().layoutWeight(1)
                SymbolGlyph(Icons.chevronRightSymbol).fontSize(12).fontColor([Theme.muted]).accessibilityLevel('no')
            }.width('100%')
            Row({ space: 4 }) {
                RollingNumber({
                    value: this.state.readiness(this.project.id).prep.done,
                    fontSize: 22,
                    color: Theme.ink,
                    accessibilityLabel: '准备已完成数量',
                })
                Text('/ ' + this.state.readiness(this.project.id).prep.total).fontSize(14).fontColor(Theme.muted).margin({ bottom: 2 })
            }.alignItems(VerticalAlign.Bottom)
            if (this.state.readiness(this.project.id).prep.total > 0) {
                Progress({
                    value: this.state.readiness(this.project.id).prep.done,
                    total: Math.max(1, this.state.readiness(this.project.id).prep.total),
                    type: ProgressType.Linear,
                }).width('100%').color(Theme.brand).backgroundColor(Theme.tint).style({ strokeWidth: 4 })
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder packTileBody() {
        Column({ space: 6 }) {
            Row({ space: 6 }) {
                MetaRow({ icon: Icons.library, text: '打包确认', color: Theme.muted })
                Blank().layoutWeight(1)
                SymbolGlyph(Icons.chevronRightSymbol).fontSize(12).fontColor([Theme.muted]).accessibilityLevel('no')
            }.width('100%')
            Row({ space: 4 }) {
                RollingNumber({
                    value: this.state.readiness(this.project.id).pack.packed,
                    fontSize: 22,
                    color: Theme.ink,
                    accessibilityLabel: '打包已确认数量',
                })
                Text('/ ' + this.state.readiness(this.project.id).pack.total).fontSize(14).fontColor(Theme.muted).margin({ bottom: 2 })
            }.alignItems(VerticalAlign.Bottom)
            if (this.state.readiness(this.project.id).pack.total > 0) {
                Progress({
                    value: this.state.readiness(this.project.id).pack.packed,
                    total: Math.max(1, this.state.readiness(this.project.id).pack.total),
                    type: ProgressType.Linear,
                }).width('100%').color(Theme.success).backgroundColor(Theme.tint).style({ strokeWidth: 4 })
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder overviewReadinessCards() {
        Row({ space: 10 }) {
            InteractiveCard({
                label: '查看准备任务',
                effects: this.state.settings.effects,
                contentPadding: 14,
                action: (): void => {
                    this.route.section = 1;
                },
                content: (): void => this.prepTileBody(),
            }).layoutWeight(1)
            InteractiveCard({
                label: '查看打包清单',
                effects: this.state.settings.effects,
                contentPadding: 14,
                action: (): void => {
                    this.route.section = 2;
                },
                content: (): void => this.packTileBody(),
            }).layoutWeight(1)
        }.width('100%')
    }

    @Builder quickBentoTile(icon: Resource, title: string, value: string) {
        Column({ space: 6 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(icon).fontSize(17).fontColor([Theme.accent]).accessibilityLevel('no')
            }.width(32).height(32).borderRadius(Theme.controlRadius).backgroundColor(Theme.tint)
            Text(value).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.ink).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(title).fontSize(11).fontColor(Theme.muted).maxLines(1)
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder overviewQuickBento() {
        Row({ space: 10 }) {
            InteractiveCard({
                label: '打开花费统计',
                effects: this.state.settings.effects,
                contentPadding: 12,
                action: (): void => {
                    this.open('expenseStats', this.project.id);
                },
                content: (): void => {
                    this.quickBentoTile(Icons.wallet, '花费统计', '¥' + (this.state.readiness(this.project.id).money.spentCents / 100).toFixed(0));
                },
            }).id('project-money-open').layoutWeight(1)
            InteractiveCard({
                label: '团队分工',
                effects: this.state.settings.effects,
                contentPadding: 12,
                action: (): void => {
                    this.route.contextSheet = 'team';
                },
                content: (): void => {
                    this.quickBentoTile(Icons.profile, '团队分工', (this.state.projectWork(this.project.id)?.value.credits.length || 0) + ' 人');
                },
            }).id('project-team-open').layoutWeight(1)
            InteractiveCard({
                label: '准备参考图',
                effects: this.state.settings.effects,
                contentPadding: 12,
                action: (): void => {
                    this.route.contextSheet = 'references';
                },
                content: (): void => {
                    this.quickBentoTile(Icons.importPhoto, '参考图', this.state.references.filter((image: ReferenceImage) => image.projectId === this.project.id).length + ' 张');
                },
            }).layoutWeight(1)
        }.width('100%')
    }

    @Builder overviewDetailsPane() {
        Column({ space: 16 }) {
            this.overviewQuickBento()
            Column() {
                DetailLink({
                    title: '记一笔',
                    subtitle: budgetLabel(this.project.budgetConfigured, this.project.budgetCents),
                    icon: Icons.creditcard,
                    action: (): void => {
                        this.edit('expense', '', this.project.id);
                    },
                })
                if (this.state.readiness(this.project.id).equipment.unavailable.length) {
                    Divider().color(Theme.groupDivider)
                    DetailLink({
                        title: '装备问题',
                        value: this.state.readiness(this.project.id).equipment.unavailable.length + ' 件',
                        icon: Icons.alert,
                        componentId: 'project-equipment-issues',
                        action: (): void => {
                            this.route.section = 1;
                        },
                    })
                }
            }.width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            SectionHeading({ title: '关联资料', icon: Icons.folder })
            Column() {
                DetailLink({
                    title: displayName(this.state.characterName(this.project.characterId)),
                    subtitle: this.project.variantId ? this.state.variants.find((variant) => variant.id === this.project.variantId)?.name || '版本已不存在' : '',
                    icon: Icons.tabProfile,
                    action: (): void => {
                        this.open('character', this.project.characterId);
                    },
                })
                if (this.project.eventId) {
                    Divider().color(Theme.groupDivider)
                    DetailLink({
                        title: displayName(this.state.events.find((event: CosEvent) => event.id === this.project.eventId)?.name || '活动已不存在'),
                        icon: Icons.event,
                        action: (): void => {
                            this.open('event', this.project.eventId);
                        },
                    })
                }
                Divider().color(Theme.groupDivider)
                DetailLink({
                    title: '日期与活动',
                    subtitle: this.state.readiness(this.project.id).date || '日期待定',
                    icon: Icons.edit,
                    action: (): void => {
                        this.edit('project', this.project.id, '');
                    },
                })
                Divider().color(Theme.groupDivider)
                this.entryLink()
                Divider().color(Theme.groupDivider)
                DetailLink({
                    title: '计划记录',
                    value: this.state.projectDiary(this.project.id).length + ' 条',
                    icon: Icons.note,
                    componentId: 'project-records-open',
                    action: (): void => {
                        this.route.contextSheet = 'records';
                    },
                })
            }.width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            if (this.project.notes) {
                SectionHeading({ title: '计划备注', icon: Icons.note })
                Text(this.project.notes)
                    .fontSize(14)
                    .fontColor(Theme.muted)
                    .padding(14)
                    .width('100%')
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.cardRadius)
                    .border({ width: 0.8, color: Theme.line })
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder overview() {
        Column({ space: 16 }) {
            this.overviewHero()
            this.overviewReadinessCards()
            this.overviewDetailsPane()
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder splitOverviewLeft() {
        Column({ space: 14 }) {
            this.header()
            this.overviewHero()
            this.overviewReadinessCards()
        }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(1))
    }

    @Builder entryLink() {
        DetailLink({
            title: '收录',
            value: this.state.entries.filter((entry) => entry.scopeKind === 'project' && entry.scopeId === this.project.id).length + ' 条',
            icon: Icons.library,
            componentId: 'project-entry-link',
            action: (): void => {
                this.route.contextSheet = 'entries';
            },
        })
    }

    @Builder packing() {
        SectionHeading({
            title: '打包清单',
            icon: Icons.library,
            trailing: `${this.state.readiness(this.project.id).pack.packed} / ${this.state.readiness(this.project.id).pack.total} 已装包`,
        })
        if (this.route.outing) {
            ContextRow({ label: '出门模式', text: this.state.hand() === 'left' ? '左手操作' : this.state.hand() === 'right' ? '右手操作' : '智感握持' })
        }
        Progress({ value: this.state.readiness(this.project.id).pack.percent, total: 100, type: ProgressType.Linear })
            .accessibilityText('打包清单完成 ' + this.state.readiness(this.project.id).pack.percent + '%')
            .color(this.state.readiness(this.project.id).pack.percent >= 100 ? Theme.success : Theme.brand)
            .backgroundColor(Theme.tint)
            .style({ strokeWidth: 5 })
            .width('100%')
        if (this.items().length === 0) {
            EmptyState({
                title: '清单还空着',
                message: '添加装备会自动生成打包项，也可以添加手机、门票等随身物品。',
                button: '添加常用物品',
                icon: Icons.library,
                action: (): void => {
                    void this.state.generateChecklist(this.project.id);
                },
            })
        }
        ForEach(this.items(), (item: ChecklistItem) => {
            Row({ space: 12 }) {
                if (this.state.hand() === 'left') {
                    this.checkButton(item)
                }
                Column({ space: 4 }) {
                    Text(displayName(item.label))
                        .fontSize(this.route.outing ? 19 : 16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(item.done ? Theme.muted : Theme.ink)
                        .decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
                    if (item.assetId) {
                        Button({ type: ButtonType.Normal, stateEffect: false }) {
                            ContextRow({ label: this.packingAssetStatus(item), text: this.location(item), tone: 'neutral' })
                        }.backgroundColor(Color.Transparent)
                            .constraintSize({ minHeight: this.route.outing ? 52 : 38 })
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.open('asset', item.assetId);
                            })
                            .accessibilityText('查看 ' + item.label + ' 的装备位置与状态')
                    } else {
                        MetaRow({ icon: Icons.location, text: this.location(item) })
                    }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (!this.route.outing) {
                    Button({ type: ButtonType.Circle, stateEffect: false }) {
                        SymbolGlyph(Icons.remove).fontSize(15).fontColor([Theme.danger]).accessibilityLevel('no')
                    }.width(36)
                        .height(36)
                        .backgroundColor(Theme.dangerBg)
                        .enabled(!this.state.busy)
                        .onClick((): void => {
                            vibration.dotVibration();
                            void this.remove('checklist', item.id);
                        })
                        .accessibilityText('删除清单项 ' + item.label)
                }
                if (this.state.hand() !== 'left') {
                    this.checkButton(item)
                }
            }.width('100%')
                .id('packing-row:' + item.id)
                .padding(14)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({
                    width: item.id === this.route.focusPackingId ? 1.5 : 0.8,
                    color: item.id === this.route.focusPackingId ? Theme.accent : Theme.line,
                })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
                .onAreaChange((_, area: Area): void => {
                    this.focusItem(item.id, area);
                })
        }, (item: ChecklistItem) => item.id)
    }

    @Builder
    private splitDetailsRight() {
        Column() {
            this.overviewDetailsPane()
        }.width('100%').attributeModifier(this.entrance.group(2))
    }

    build() {
        Stack() {
            if (this.isSplitOverview) {
                DashboardSplitLayout({
                    scroller: this.scroller,
                    overviewTop: this.topInset,
                    scrollTop: this.topInset,
                    bottomInset: Theme.detailFloatingBottom,
                    layoutId: 'project-overview',
                    overviewId: 'project-split-overview',
                    scrollId: 'project-split-scroll',
                    overviewLabel: '计划概览',
                    scrollLabel: '关联资料与操作',
                    overview: (): void => this.splitOverviewLeft(),
                    content: (): void => this.splitDetailsRight(),
                })
            } else {
                Scroll(this.scroller) {
                    Column({ space: Theme.sectionSpacing }) {
                        Blank().height(this.topInset).width('100%')
                        Column({ space: 10 }) {
                            this.header()
                            if (this.focusFeedback) {
                                Text(this.focusFeedback).fontSize(13).fontColor(Theme.muted)
                            }
                            if (this.state.error) {
                                Text(this.state.error).fontSize(13).fontColor(Theme.danger)
                            }
                            if (this.route.section === 1) {
                                this.preparation()
                            }
                        }.width('100%')
                            .alignItems(HorizontalAlign.Start)
                            .opacity(this.entrance.step >= 1 ? 1 : 0)
                            .translate({ y: this.entrance.step >= 1 ? 0 : 20 })
                        Column({ space: Theme.sectionSpacing }) {
                            if (this.route.section === 0) {
                                this.overview()
                            } else if (this.route.section === 2) {
                                this.packing()
                            } else {
                                this.preparationList();
                                this.equipmentList()
                            }
                        }.width('100%')
                            .alignItems(HorizontalAlign.Start)
                            .opacity(this.entrance.step >= 2 ? 1 : 0)
                            .translate({ y: this.entrance.step >= 2 ? 0 : 20 })
                        Blank().height(Theme.detailFloatingBottom).width('100%')
                    }.constraintSize({ maxWidth: Theme.readingMaxWidth })
                        .alignItems(HorizontalAlign.Start)
                        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                        .width('100%')
                }.id(this.route.section === 2 ? 'project-packing' : this.route.section === 0 ? 'project-overview' : 'project-preparation')
                    .width('100%')
                    .height('100%')
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
                    .onAreaChange((_, area: Area): void => {
                        this.viewportTop = Number(area.globalPosition.y);
                        if (!this.measured && Number(area.height) > 0) {
                            this.measured = true;
                            this.restoreOffset();
                            this.focusAfterMeasure();
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
                    .align(Alignment.Top)
            }
        }.width('100%')
            .height('100%')
            .onAreaChange((_, area: Area): void => {
                const width = Number(area.width);
                const height = Number(area.height);
                if (width > 0 && height > 0) {
                    this.viewportWidth = width;
                    this.viewportHeight = height;
                }
            })
            .bindSheet(this.route.preparing || this.route.linking || Boolean(this.route.contextSheet), this.activeSheet(), appSheetOptions((): void => {
                this.route.preparing = false;
                this.route.linking = false;
                this.route.contextSheet = '';
            }, this.sheetEntrance, this.getUIContext()))
            .onDisAppear((): void => {
                this.state.suspend();
            })
    }
}
