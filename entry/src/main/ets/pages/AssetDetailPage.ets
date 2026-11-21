import { SheetContent } from '../components/SheetContent';
import { DetailLink } from '../components/DetailLink';
import { DetailTag } from '../components/DetailTag';
import { Icons } from '../ui/Icons';
import { displayName } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS, PROJECT_STATUSES, PROJECT_LABELS } from '../models/constants';
import { StaggerEntrance } from '../ui/motion';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { appSheetOptions, dismissSheet } from '../ui/sheet';
import { confirm } from '../ui/Confirm';
import { AppState } from '../viewmodels/ApplicationState';
import { AssetRoute } from '../viewmodels/AssetRoute';
import { assetUsesSegments } from '../models/Wardrobe';
import { Theme } from '../ui/Theme';
import { Asset, AssetStatus, CosProject } from '../models/Entities';
import { SectionHeading, StatusPill, FactRow, EmptyState, PillTone } from '../components/Surfaces';
import { SheetHeader } from '../components/SheetHeader';
import { DashboardSearch } from '../components/DashboardSearch';

@ComponentV2
export struct AssetDetail {
    @Require @Param state: AppState;
    @Require @Param route: AssetRoute;
    @Require @Param asset: Asset;
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    @Event open: (kind: string, id: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
    @Local actionError: string = '';
    private scroller: Scroller = new Scroller();
    private measured: boolean = false;
    private restoring: boolean = true;
    private restoreTimer: number = -1;
    private displayedSection: number = 0;

    private segmented(): boolean {
        return this.route.section === 1 || assetUsesSegments(this.asset, this.state.assetUsage(this.asset.id));
    }

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

    private assetTone(): PillTone {
        if (this.asset.status === AssetStatus.OWNED) {
            return 'success';
        }
        if (this.asset.status === AssetStatus.ORDERED) {
            return 'brand';
        }
        if (this.asset.status === AssetStatus.REPAIR || this.asset.status === AssetStatus.LENT) {
            return 'warning';
        }
        return 'neutral';
    }

    private projectsToChoose(): CosProject[] {
        const query = this.route.projectQuery.trim().toLocaleLowerCase();
        return this.state.projects.filter((project: CosProject) => !query || (project.name + ' ' + this.state.characterName(project.characterId)).toLocaleLowerCase().includes(query));
    }

    private linked(id: string): boolean {
        return this.state.assetUsage(this.asset.id).projects.some((project: CosProject) => project.id === id);
    }

    private async join(project: CosProject): Promise<void> {
        vibration.dotVibration();
        this.actionError = '';
        if (await this.state.linkAsset(project.id, this.asset)) {
            this.route.linking = false;
            this.route.section = 1;
        } else {
            vibration.errorVibration();
            this.actionError = this.state.error || '关联未保存，请重试';
        }
    }

    private async unlink(project: CosProject): Promise<void> {
        const usage = this.state.assetUsage(this.asset.id);
        const ids = usage.checklist.filter((item) => item.projectId === project.id).map((item) => item.id);
        if (!(await confirm(this.getUIContext(), '解除「' + this.asset.name + '」的关联？', usage.unlinkMessage(project), '解除关联'))) {
            return;
        }
        this.actionError = '';
        if (!(await this.state.unlinkAsset(project.id, this.asset.id, ids))) {
            this.actionError = this.state.error || '关联未解除，请重试';
        }
    }

    @Builder heading() {
        Column({ space: 8 }) {
            if (this.asset.status !== AssetStatus.OWNED) {
                ContextRow({
                    label: '当前不可用',
                    text: '影响 ' + this.state.assetUsage(this.asset.id).activeProjects.length + ' 份进行中计划',
                    tone: 'warning',
                })
            }
            if (this.route.from === 'project' || this.route.from === 'day') {
                ContextRow({
                    label: this.route.from === 'day' ? '今天模式' : '来自计划',
                    text: this.state.projects.some((project: CosProject) => project.id === this.route.projectId) ? displayName(this.state.projectName(this.route.projectId)) : '来源计划已不存在，返回最近有效页面',
                })
            }
            if (this.actionError || this.state.error) {
                Text(this.actionError || this.state.error).fontSize(13).fontColor(Theme.danger)
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder facts() {
        Column({ space: 14 }) {
            Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                    SymbolGlyph(Icons.assetTypeSymbol(this.asset.type))
                        .fontSize(22)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(44)
                    .height(44)
                    .borderRadius(12)
                    .backgroundColor(Theme.tint)
                Column({ space: 2 }) {
                    Text('存放位置').fontSize(12).fontColor(Theme.muted)
                    Text(this.asset.location.trim() || '未记录位置')
                        .fontSize(21)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                        .copyOption(CopyOptions.LocalDevice)
                }.alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                StatusPill({
                    label: ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.asset.status)],
                    tone: this.assetTone(),
                })
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            Button(this.asset.location.trim() ? '修改位置' : '补充存放位置', { type: ButtonType.Normal, stateEffect: false })
                .constraintSize({ minHeight: 42 })
                .backgroundColor(Theme.tint)
                .fontColor(Theme.accent)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 16, right: 16 })
                .borderRadius(Theme.controlRadius)
                .enabled(!this.state.busy && !this.state.staleScopes.length)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.edit('asset', this.asset.id, '');
                })
        }.padding(18)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.heroRadius)
            .border({ width: 0.8, color: Theme.divider })
            .shadow({ radius: 10, color: Theme.shadow, offsetX: 0, offsetY: 3 })
        Column({ space: 8 }) {
            Row({ space: 8 }) {
                DetailTag({
                    label: '类型',
                    value: ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.asset.type)] || '其他',
                    tone: 'brand',
                }).layoutWeight(1)
                DetailTag({
                    label: '资料价',
                    value: '¥' + (this.asset.priceCents / 100).toFixed(2),
                    tone: 'neutral',
                }).layoutWeight(1)
            }.width('100%')
            if (this.asset.brand || this.asset.size) {
                Row({ space: 8 }) {
                    DetailTag({ label: '品牌店铺', value: this.asset.brand || '未填写' }).layoutWeight(1)
                    DetailTag({ label: '尺码', value: this.asset.size || '未填写' }).layoutWeight(1)
                }.width('100%')
            }
        }.width('100%')
        if (this.asset.purchaseUrl || this.asset.notes) {
            Column({ space: 14 }) {
                if (this.asset.purchaseUrl) {
                    FactRow({ label: '购买链接', value: this.asset.purchaseUrl, copyable: true })
                }
                if (this.asset.notes) {
                    Text(this.asset.notes).fontSize(14).fontColor(Theme.muted).copyOption(CopyOptions.LocalDevice)
                }
            }.padding(16)
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
        }
        Column() {
            DetailLink({
                title: '收录',
                value: this.state.assetUsage(this.asset.id).entryIds.length + ' 条',
                icon: Icons.library,
                action: (): void => {
                    this.open('inbox', 'asset|' + this.asset.id);
                },
            })
        }.padding({ left: 12, right: 12 })
            .width('100%')
            .backgroundColor(Theme.surface)
            .borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
    }

    @Builder uses() {
        Row({ space: 10 }) {
            SectionHeading({ title: '使用计划', icon: Icons.plan, trailing: this.state.assetUsage(this.asset.id).projects.length + ' 份' }).layoutWeight(1)
            Button({ type: ButtonType.Normal, stateEffect: false }) {
                Row({ space: 5 }) {
                    SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                    Text('加入计划').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                }.padding({ left: 12, right: 12 })
            }.height(36)
                .borderRadius(Theme.controlRadius)
                .backgroundColor(Theme.tint)
                .enabled(!this.state.busy && !this.state.staleScopes.length)
                .onClick((): void => {
                    vibration.dotVibration();
                    this.actionError = '';
                    this.route.projectQuery = '';
                    this.route.linking = true;
                })
        }.width('100%')
            .alignItems(VerticalAlign.Center)
        ForEach(this.state.assetUsage(this.asset.id).projects, (project: CosProject) => {
            Column() {
                DetailLink({
                    title: displayName(project.name),
                    subtitle: this.state.readiness(project.id).date || '日期待定',
                    value: PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)],
                    icon: Icons.plan,
                    action: (): void => {
                        this.open('project', project.id);
                    },
                })
                Divider().color(Theme.groupDivider)
                Button('解除关联', { type: ButtonType.Normal, stateEffect: false })
                    .constraintSize({ minHeight: 42 })
                    .fontSize(13)
                    .fontColor(Theme.danger)
                    .backgroundColor(Color.Transparent)
                    .enabled(!this.state.busy && !this.state.staleScopes.length)
                    .onClick((): void => {
                        vibration.dotVibration();
                        void this.unlink(project);
                    })
                    .accessibilityText('解除 ' + project.name + ' 的装备关联')
            }.padding({ left: 12, right: 12 })
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }, (project: CosProject) => project.id)
        if (!this.state.assetUsage(this.asset.id).projects.length) {
            EmptyState({
                title: '还没有计划使用它',
                message: '加入计划会同时建立对应打包项。',
                button: '加入计划',
                icon: Icons.plan,
                action: (): void => {
                    this.actionError = '';
                    this.route.projectQuery = '';
                    this.route.linking = true;
                },
            })
        }
    }

    @Builder planSheet() {
        SheetContent() {
            Column({ space: 14 }) {
                SheetHeader({
                    title: '选择计划加入装备',
                    hint: displayName(this.asset.name),
                    close: (): void => {
                        if (!this.state.busy) {
                            this.route.linking = false;
                        }
                    },
                })
                if (this.asset.status !== AssetStatus.OWNED) {
                    Text('加入后仍保留当前不可用状态，相关计划会显示装备问题。').fontSize(13).fontColor(Theme.warning)
                }
                DashboardSearch({
                    value: this.route.projectQuery,
                    label: '查找要加入的计划',
                    placeholder: '搜索计划 / 角色',
                    changed: (value: string): void => {
                        this.route.projectQuery = value;
                    },
                })
                if (this.actionError || this.state.error) {
                    Text(this.actionError || this.state.error).fontSize(13).fontColor(Theme.danger)
                }
                List({ space: 10 }) {
                    ForEach(this.projectsToChoose(), (project: CosProject) => {
                        ListItem() {
                            Button({ type: ButtonType.Normal, stateEffect: false }) {
                                ContextRow({
                                    label: this.linked(project.id) ? '已加入' : PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)],
                                    text: displayName(project.name),
                                    tone: this.linked(project.id) ? 'success' : 'brand',
                                    prominent: true,
                                })
                            }.constraintSize({ minHeight: 50 })
                                .width('100%')
                                .padding({ left: 12, right: 12 })
                                .backgroundColor(Theme.bg)
                                .borderRadius(Theme.controlRadius)
                                .border({ width: 0.8, color: Theme.line })
                                .enabled(!this.state.busy && !this.state.staleScopes.length && !this.linked(project.id))
                                .onClick((): void => {
                                    void this.join(project);
                                })
                                .accessibilityText('将装备加入计划 ' + project.name)
                        }
                    }, (project: CosProject) => project.id)
                    if (!this.projectsToChoose().length) {
                        ListItem() {
                            EmptyState({
                                title: this.route.projectQuery.trim() ? '没有匹配的计划' : '先建立一份计划',
                                message: '装备保持在衣柜，计划建立后可在此选择加入。',
                                button: this.route.projectQuery.trim() ? '清除搜索' : '新建计划',
                                icon: Icons.plan,
                                action: (): void => {
                                    if (this.route.projectQuery.trim()) {
                                        this.route.projectQuery = '';
                                    } else {
                                        this.route.linking = false;
                                        this.edit('project', '', '');
                                    }
                                },
                            })
                        }
                    }
                }.layoutWeight(1).width('100%').edgeEffect(EdgeEffect.Spring)
            }.padding(24).width('100%').height('100%').backgroundColor(Theme.surface)
        }
    }

    private sheetOptions(): SheetOptions {
        const options = appSheetOptions((): void => {
            this.route.linking = false;
        }, this.sheetEntrance, this.getUIContext(), SheetSize.LARGE, async (): Promise<boolean> => !this.state.busy, (): void => {
            this.route.linking = false;
        });
        options.onWillDismiss = (action: DismissSheetAction): void => {
            void dismissSheet(action, async (): Promise<boolean> => !this.state.busy);
        };
        return options;
    }

    build() {
        Scroll(this.scroller) {
            Column({ space: Theme.sectionSpacing }) {
                Blank().height(Theme.detailTop).width('100%')
                this.heading()
                if (this.route.section === 0 || !this.segmented()) {
                    this.facts()
                }
                if (this.route.section === 1 || !this.segmented()) {
                    this.uses()
                }
                Blank().height(this.segmented() ? Theme.detailFloatingBottom : Theme.detailBottom).width('100%')
            }.constraintSize({ maxWidth: Theme.readingMaxWidth })
                .width('100%')
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .alignItems(HorizontalAlign.Start)
        }.id('asset-detail-scroll')
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .align(Alignment.Top)
            .onAreaChange((_old: Area, area: Area): void => {
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
            .bindSheet(this.route.linking, this.planSheet(), this.sheetOptions())
    }
}
