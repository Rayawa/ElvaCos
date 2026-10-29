import { SheetContent } from '../../components/common/SheetContent';
import { window } from '@kit.ArkUI';
import { LocationSheet } from '../../components/schedule/LocationSheet';
import { DetailLink } from '../../components/common/DetailLink';
import { DayTaskRow } from '../../components/schedule/DayTaskRow';
import { displayName } from '../../utils/format/format';
import { ProjectShot } from '../../models/Shot';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, PROJECT_STATUSES, PROJECT_LABELS } from '../../config/constants';
import { Theme } from '../../ui/theme/Theme';
import { AppState } from '../../state/ApplicationState';
import { EventRoute } from '../../models/EventRoute';
import { CosEvent, CosProject, ChecklistItem, AssetStatus } from '../../models/Entities';
import { TeamMember } from '../../models/Planning';
import { CollectedEntry, entryTitle } from '../../models/CollectedEntry';
import { eventDateLabel, eventTimeLabel } from '../../domain/schedule/Schedule';
import { DayModule, DayTimelineItem, eventTimeline, planShootingLabel, hasEventShots, dayNumber, availableDayModules, assembledDayModules, orderedDayModules, reminderState, dayContext } from '../../domain/schedule/DayMode';
import { StaggerEntrance } from '../../ui/animation/motion';
import { appSheetOptions, dismissSheet } from '../../ui/sheet/sheet';
import { confirm } from '../../ui/feedback/Confirm';
import { operationCommitted } from '../../domain/operations/OperationResult';
import { SheetHeader } from '../../components/common/SheetHeader';
import { HdsViewTabs } from '../../components/navigation/HdsViewTabs';
import { Icons } from '../../ui/icons/Icons';
import { SectionHeading, StatusPill, EmptyState } from '../../components/common/Surfaces';
import { EntryCollectionView } from '../../components/entries/EntryCollectionView';
import { ManagedImage } from '../../components/common/ManagedImage';
import { ProjectCard } from '../../components/plans/ProjectCard';

@ComponentV2
export struct EventDetail {
    @Require @Param state: AppState;
    @Require @Param route: EventRoute;
    @Param event: CosEvent = new CosEvent();
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    @Event open: (kind: string, id: string) => void = () => {};
    @Local shotError: string = '';
    @Local packingError: string = '';
    @Event openShot: (projectId: string, shotId: string) => void = () => {};
    @Event openAsset: (id: string, projectId: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event back: () => void = () => {};
    @Local locationOpen: boolean = false;
    @Local linking: boolean = false;
    @Local recordError: string = '';
    @Local recordText: string = '';
    @Local viewing: boolean = false;
    @Local credential: CollectedEntry = new CollectedEntry();
    @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
    @Local contentTop: number = Theme.contentTop;
    private systemTop: number = 0;
    private contentOrigin: number = 0;

    private updateTopInset(): void {
        this.contentTop = Theme.detailTop + Math.max(0, this.systemTop - this.contentOrigin);
    }
    private hostWindow: window.Window | undefined = undefined;
    private departed: boolean = false;
    private avoidChanged = (value: window.AvoidAreaOptions): void => {
        if (value.type === window.AvoidAreaType.TYPE_SYSTEM) {
            this.systemTop = this.getUIContext().px2vp(value.area.topRect.height);
            this.updateTopInset();
        }
    };

    private async observeSystemArea(): Promise<void> {
        try {
            const host = await window.getLastWindow(this.getUIContext().getHostContext() as common.UIAbilityContext);
            if (this.departed) {
                return;
            }
            this.hostWindow = host;
            this.systemTop = this.getUIContext().px2vp(host.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height);
            this.updateTopInset();
            host.on('avoidAreaChange', this.avoidChanged);
        } catch (error) {
            console.warn('Event window safe area unavailable');
        }
    }
    private scroller: Scroller = new Scroller();
    private displayedIndex: number = 0;
    private restoring: boolean = true;
    private measured: boolean = false;
    private restoreTimer: number = -1;

    private offsetIndex(): number {
        return this.route.dayMode ? 4 + this.route.section : this.route.section;
    }

    aboutToAppear(): void {
        this.departed = false;
        void this.observeSystemArea();
        this.displayedIndex = this.offsetIndex();
        this.restoreScroll();
    }

    aboutToDisappear(): void {
        this.departed = true;
        try {
            this.hostWindow?.off('avoidAreaChange', this.avoidChanged);
        } catch (error) {
            console.warn('Event safe area listener could not detach');
        }
        this.hostWindow = undefined;
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
    }

    @Monitor('route.section', 'route.dayMode')
    private viewChanged(): void {
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
            this.restoreTimer = -1;
        }
        this.measured = false;
        this.restoring = true;
        this.displayedIndex = this.offsetIndex();
        this.restoreScroll();
    }

    @Monitor('route.restoreVersion')
    private contextChanged(): void {
        this.restoreScroll();
    }

    private restoreScroll(): void {
        if (!this.measured) {
            return;
        }
        if (this.restoreTimer >= 0) {
            clearTimeout(this.restoreTimer);
        }
        this.restoring = true;
        this.restoreTimer = setTimeout((): void => {
            this.restoreTimer = -1;
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedIndex], animation: false });
            this.restoring = false;
        }, 0);
    }

    private projects(): CosProject[] {
        return this.state.projects.filter((project: CosProject) => project.eventId === this.event.id);
    }

    private credentials(): CollectedEntry[] {
        return this.state.entries.filter((entry: CollectedEntry) => entry.scopeKind === 'event' && entry.scopeId === this.event.id && ['ticket', 'map', 'link'].includes(entry.kind));
    }

    private modules(): DayModule[] {
        return assembledDayModules(availableDayModules(this.event, this.state.projects, this.state.entries, this.state.team, this.state.clockTime, hasEventShots(this.event.id, this.state.projects, this.state.readinessPlans)), this.state.dayModules, this.route.section);
    }

    private async associate(project: CosProject): Promise<void> {
        const copy = JSON.parse(JSON.stringify(project)) as CosProject;
        copy.eventId = this.event.id;
        if (await this.state.saveProject(copy)) {
            this.linking = false;
        }
    }

    private async openLink(url: string): Promise<void> {
        try {
            await (this.getUIContext().getHostContext() as common.UIAbilityContext).openLink(url, { appLinkingOnly: false });
        } catch (error) {
            this.state.reportError('无法打开链接，可复制后手动打开');
        }
    }

    private async copyContact(member: TeamMember): Promise<void> {
        try {
            await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, member.notes));
            this.state.reportNotice('已复制 ' + member.name + ' 的备注 / 联系方式');
        } catch (error) {
            this.state.reportError('复制失败，请重试或长按备注复制');
        }
    }

    private recordFor(project: CosProject): void {
        this.route.recording = false;
        if (this.route.recordKind === 0) {
            this.edit('expense', '', project.id);
        } else {
            this.state.importPhotos(project.id);
        }
    }

    private async captureText(): Promise<void> {
        this.recordError = '';
        const result = await this.state.captureEntry(this.recordText, 'event', this.event.id);
        if (operationCommitted(result)) {
            this.recordText = '';
        } else {
            this.recordError = result.detail || '收录未保存，请重试';
        }
    }

    private async captureImage(): Promise<void> {
        this.recordError = '';
        const result = await this.state.captureEntryImage('event', this.event.id);
        if (!operationCommitted(result)) {
            this.recordError = result.detail || '图片未收录，请重试';
        }
    }

    private async canCloseSheet(): Promise<boolean> {
        if (this.state.busy) {
            return false;
        }
        if (this.route.recording && this.recordText.trim()) {
            if (!await confirm(this.getUIContext(), '放弃这条未保存的收录？', '取消可继续输入；已保存的收录会保留。', '放弃输入')) {
                return false;
            }
            this.recordText = '';
        }
        return true;
    }

    private closeSheets(): void {
        this.locationOpen = false;
        this.linking = false;
        this.route.configuring = false;
        this.route.recording = false;
        this.viewing = false;
    }

    private async requestClose(): Promise<void> {
        if (await this.canCloseSheet()) {
            this.closeSheets();
        }
    }

    private sheetOptions(): SheetOptions {
        const options = appSheetOptions((): void => {
            this.closeSheets();
        }, this.sheetEntrance, this.getUIContext(), this.locationOpen ? SheetSize.MEDIUM : SheetSize.LARGE,
        (): Promise<boolean> => this.canCloseSheet(), (): void => this.closeSheets());
        options.onWillDismiss = (action: DismissSheetAction): void => {
            void dismissSheet(action, (): Promise<boolean> => this.canCloseSheet());
        };
        return options;
    }

    @Builder linkSheet() {
        Column({ space: 14 }) {
            SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: '关联已有计划', hint: '只列出尚未关联活动的计划', close: (): void => {
                    this.linking = false;
                }
            })
            Scroll() {
                Column({ space: 12 }) {
                    ForEach(this.state.projects.filter((project: CosProject) => !project.eventId), (project: CosProject) => {
                        Button(project.name).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.state.busy)
                            .onClick((): void => {
                                this.associate(project);
                            })
                    }, (project: CosProject) => project.id)
                    if (!this.state.projects.some((project: CosProject) => !project.eventId)) {
                        Text('没有待关联的计划，可以为本次活动新建计划。').fontColor(Theme.muted)
                    }
                }.width('100%')
            }.layoutWeight(1).width('100%')
        }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
    }

    @Builder configurationSheet() {
        Column({ space: 16 }) {
            SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: '今天模式模块', hint: '两段固定；有对应内容的模块才会显示', close: (): void => {
                    this.route.configuring = false;
                }
            })
            Scroll() {
                Column({ space: 16 }) {
                    ForEach([0, 1], (section: number) => {
                        SectionHeading({ title: section === 0 ? '出发前' : '现场' })
                        ForEach(orderedDayModules(this.state.dayModules, section), (module: DayModule, index: number) => {
                            Row({ space: 8 }) {
                                Checkbox().height(64).select(this.state.dayModules[module.id]?.enabled !== false).enabled(!this.state.settingsBusy)
                                    .onChange((enabled: boolean): void => {
                                        this.state.configureDayModule(module.id, enabled);
                                    }).accessibilityText(module.label + '模块开关')
                                Text(module.label).layoutWeight(1).fontColor(Theme.ink)
                                Button('上移').constraintSize({ minHeight: 64 }).enabled(index > 0 && !this.state.settingsBusy)
                                    .onClick((): void => {
                                        this.state.configureDayModule(module.id, undefined, -1);
                                    }).accessibilityText(module.label + '上移')
                                Button('下移')
                                    .constraintSize({ minHeight: 64 })
                                    .enabled(index < orderedDayModules(this.state.dayModules, section).length - 1 && !this.state.settingsBusy)
                                    .onClick((): void => {
                                        this.state.configureDayModule(module.id, undefined, 1);
                                    }).accessibilityText(module.label + '下移')
                            }.width('100%').constraintSize({ minHeight: 64 })
                        }, (module: DayModule) => module.id)
                    })
                }.width('100%')
            }.layoutWeight(1).width('100%')
        }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
    }

    @Builder recordSheet() {
        Column({ space: 16 }) {
            SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: this.route.recordKind < 0 ? '快速记录' : this.route.recordKind === 0 ? '选择记账计划' : this.route.recordKind === 1 ? '收录一条' : '选择照片所属计划', close: (): void => {
                    this.requestClose();
                }
            })
            Scroll() {
                Column({ space: 12 }) {
                    if (this.route.recordKind < 0) {
                        DetailLink({ title: '记一笔', subtitle: '记录这次活动的花费', icon: Icons.plan, action: (): void => {
                                this.route.recordKind = 0;
                                this.recordError = '';
                            }
                        })
                        Divider().color(Theme.line)
                        DetailLink({ title: '收录一条', subtitle: '保存链接、文字或图片', icon: Icons.library, action: (): void => {
                                this.route.recordKind = 1;
                                this.recordError = '';
                            }
                        })
                        Divider().color(Theme.line)
                        DetailLink({ title: '传照片', subtitle: '导入到本场计划', icon: Icons.importPhoto, action: (): void => {
                                this.route.recordKind = 2;
                                this.recordError = '';
                            }
                        })
                    } else if (this.route.recordKind === 1) {
                        TextArea({ text: this.recordText, placeholder: '粘贴链接或写一句话' })
                            .height(120)
                            .enabled(!this.state.busy)
                            .onChange((value: string): void => {
                                this.recordText = value;
                            })
                        if (this.recordError) {
                            Text(this.recordError).id('day-record-error').fontSize(14).fontColor(Theme.danger).accessibilityText(this.recordError)
                        }
                        Button('收录')
                            .width('100%')
                            .constraintSize({ minHeight: 64 })
                            .enabled(!this.state.busy && Boolean(this.recordText.trim()))
                            .onClick((): void => {
                                this.captureText();
                            })
                        Button('存一张图').width('100%').constraintSize({ minHeight: 64 }).enabled(!this.state.busy).onClick((): void => {
                            void this.captureImage();
                        })
                        Text('直接归到本次活动，标题和类型可以以后补充。').fontColor(Theme.muted)
                    } else {
                        ForEach(this.projects(), (project: CosProject) => {
                            Button(project.name).width('100%').constraintSize({ minHeight: 64 }).enabled(!this.state.busy).onClick((): void => {
                                this.recordFor(project);
                            })
                        }, (project: CosProject) => project.id)
                        if (!this.projects().length) {
                            EmptyState({ title: '先为本次活动建立计划', message: '花费和照片都属于具体计划。', button: '新建计划', action: (): void => {
                                    this.route.recording = false;
                                    this.edit('eventProject', '', this.event.id);
                                }
                            })
                        }
                    }
                }.width('100%')
            }.layoutWeight(1).width('100%')
        }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
    }

    @Builder credentialSheet() {
        Column({ space: 12 }) {
            SheetHeader({ haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: this.route.dayMode ? 64 : 48, title: entryTitle(this.credential), close: (): void => {
                    this.viewing = false;
                }
            })
            Scroll() {
                Column({ space: 12 }) {
                    if (this.credential.localPath) {
                        ManagedImage({ sourcePath: this.credential.localPath, large: true, fit: ImageFit.Contain, label: entryTitle(this.credential) })
                            .width('100%')
                            .height(480)
                    }
                    if (this.credential.text) {
                        Text(this.credential.text).fontSize(18).fontColor(Theme.ink).copyOption(CopyOptions.LocalDevice)
                    }
                    if (this.credential.url) {
                        Text(this.credential.url).fontColor(Theme.muted).copyOption(CopyOptions.LocalDevice)
                        Button('打开链接').width('100%').constraintSize({ minHeight: 64 }).onClick((): void => {
                            this.openLink(this.credential.url);
                        })
                    }
                    if (!this.credential.localPath && this.credential.kind !== 'link') {
                        Text('没有本机图片；可在活动的收录区补充或修复。').fontColor(Theme.muted)
                    }
                }.width('100%')
            }.layoutWeight(1).width('100%')
        }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
    }

    private dateTitle(): string {
        if (this.event.dateMode === 'pending' || !this.event.date) {
            return '日期待定';
        }
        const start = Number(this.event.date.slice(5, 7)) + '月' + Number(this.event.date.slice(8)) + '日';
        if (this.event.dateMode !== 'multiple' || !this.event.endDate) {
            return start;
        }
        if (this.event.date.slice(0, 4) !== this.event.endDate.slice(0, 4)) {
            return eventDateLabel(this.event);
        }
        return start + ' — ' + (this.event.date.slice(5, 7) === this.event.endDate.slice(5, 7) ? '' : Number(this.event.endDate.slice(5, 7)) + '月') + Number(this.event.endDate.slice(8)) + '日';
    }

    @Builder overview() {
        Column({ space: 12 }) {
            Row() {
                Text(this.event.eventType).fontSize(14).fontColor(Theme.muted).layoutWeight(1)
                StatusPill({ label: this.event.ticketPurchased ? '门票已准备' : '门票待确认' })
            }.width('100%')
            Text(this.dateTitle()).fontSize(25).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text((this.event.date ? this.event.date.slice(0, 4) + '年，' : '') + eventTimeLabel(this.event)).fontSize(16).fontColor(Theme.muted)
            Button('进入今天模式').width('100%').height(52).backgroundColor(Theme.brand).fontColor(Theme.onAccent)
                .onClick((): void => {
                    this.route.section = 0;
                    this.route.dayMode = true;
                })
        }.padding(20).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        Column() {
            DetailLink({ title: this.event.venue || '添加地点', subtitle: this.event.city, icon: Icons.location, componentId: 'event-location-open', action: (): void => {
                    this.locationOpen = true;
                }
            })
        }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        if (this.event.url || this.event.notes) {
            Column({ space: 16 }) {
                if (this.event.url) {
                    DetailLink({ title: '官方链接', icon: Icons.library, action: (): void => {
                            this.openLink(this.event.url);
                        }
                    })
                }
                if (this.event.notes) {
                    Text(this.event.notes).fontSize(15).fontColor(Theme.muted).copyOption(CopyOptions.LocalDevice)
                }
            }.padding(16).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        }
    }

    @Builder plans() {
        Column({ space: 14 }) {
            SectionHeading({ title: '本场计划', trailing: this.projects().length + ' 份' })
            Row({ space: 8 }) {
                Button('新建计划').constraintSize({ minHeight: 48 }).onClick((): void => {
                    this.edit('eventProject', '', this.event.id);
                })
                Button('关联已有').constraintSize({ minHeight: 48 }).enabled(!this.state.busy).onClick((): void => {
                    this.linking = true;
                })
            }
            ForEach(this.projects(), (project: CosProject) => {
                ProjectCard({ state: this.state, project: project, open: (): void => this.open('project', project.id) })
            }, (project: CosProject) => project.id)
            if (!this.projects().length) {
                Text('新建计划会自动带入本次活动；也可以关联已有计划。').fontColor(Theme.muted)
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Builder reminders() {
        Column({ space: 12 }) {
            Text(reminderState(this.event, this.state.clockTime)).fontSize(23).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            if (this.event.reminderMinutes >= 0) {
                Text(this.event.reminderMinutes === 0 ? '活动开始时提醒' : '提前 ' + this.event.reminderMinutes + ' 分钟').fontSize(14).fontColor(Theme.muted)
            }
        }.padding(20).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        Column() {
            DetailLink({ title: '编辑提醒', icon: Icons.edit, action: (): void => {
                    this.edit('event', this.event.id, '');
                }
            })
            Divider().color(Theme.line)
            DetailLink({ title: '通知设置', icon: Icons.event, action: (): void => {
                    this.state.openReminderSettings();
                }
            })
            Divider().color(Theme.line)
            DetailLink({ title: '添加到系统日历', subtitle: '在系统确认页选择账户', icon: Icons.event, interactive: !this.state.busy, action: (): void => {
                    this.state.addEventToCalendar(this.event);
                }
            })
        }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    }

    @Builder dayHeader() {
        Column({ space: 8 }) {
            Row({ space: 8 }) {
                Button() {
                    Row({ space: 8 }) {
                        Image(Icons.location).width(20).height(20).fillColor(Theme.accent)
                        Text(this.event.venue || this.event.city || '添加地点')
                            .fontSize(20)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.ink)
                            .maxLines(2)
                            .layoutWeight(1)
                        Image(Icons.chevronRight).width(14).height(14).fillColor(Theme.muted)
                    }.width('100%')
                }.id('day-location')
                    .type(ButtonType.Normal)
                    .backgroundColor(Color.Transparent)
                    .constraintSize({ minHeight: 48 })
                    .layoutWeight(1)
                    .onClick((): void => {
                        this.locationOpen = true;
                    }).accessibilityText('查看活动地点与地图')
                StatusPill({ label: dayContext(this.event, this.state.clockTime) })
                if (dayNumber(this.event, this.state.clockTime)) {
                    StatusPill({ label: dayNumber(this.event, this.state.clockTime) })
                }
            }.width('100%')
            Text(eventDateLabel(this.event) + '，' + eventTimeLabel(this.event))
                .id('day-date-time')
                .fontSize(14)
                .fontColor(Theme.muted)
                .maxLines(2)
        }.padding({ top: 12, left: Theme.pagePadding, right: Theme.pagePadding, bottom: 16 })
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(Theme.bg)
    }

    @Builder packing(project: CosProject) {
        Column() {
            DetailLink({ title: displayName(project.name), subtitle: '已装包 ' + this.state.readiness(project.id)
                    .pack.packed + ' / ' + this.state.readiness(project.id)
                    .pack.total + ' 件', action: (): void => {
                        this.open('outing', project.id);
                    }
            })
            Divider().color(Theme.line)
            if (!this.state.checklist.some((item: ChecklistItem) => item.projectId === project.id)) {
                DetailLink({ title: '建立打包清单', icon: Icons.add, action: (): void => {
                        this.open('packing', project.id);
                    }
                })
            }
            ForEach(this.state.checklist.filter((item: ChecklistItem) => item.projectId === project.id).sort((a: ChecklistItem, b: ChecklistItem) => a.sortOrder - b.sortOrder), (item: ChecklistItem) => {
                DayTaskRow({ title: item.label, done: item.done, interactive: !this.state.busy && !this.state.staleScopes.length,
                    subtitle: item.assetId ? this.packingLocation(item) : '', statusLabel: item.assetId ? this.packingStatus(item) : '', secondaryLabel: item.assetId ? '装备' : '',
                    toggle: (): void => {
                        void this.togglePacking(item);
                    }, secondary: (): void => {
                        this.openAsset(item.assetId, project.id);
                    }
                })
                Divider().color(Theme.line)
            }, (item: ChecklistItem) => item.id)
        }.padding({ left: 12, right: 12 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    }

    private packingLocation(item: ChecklistItem): string {
        const asset = this.state.assets.find((asset) => asset.id === item.assetId);
        if (!asset) {
            return '装备已不存在';
        }
        return asset.location || '未记录位置';
    }

    private packingStatus(item: ChecklistItem): string {
        const asset = this.state.assets.find((asset) => asset.id === item.assetId);
        return asset && asset.status !== AssetStatus.OWNED ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] : '';
    }

    private async togglePacking(item: ChecklistItem): Promise<void> {
        this.packingError = '';
        if (!await this.state.toggleChecklist(item)) {
            this.packingError = this.state.projectName(item.projectId) + '，' + item.label + '：' + (this.state.error || '装包确认未保存，请重试');
        }
    }

    private async toggleShot(shot: ProjectShot): Promise<void> {
        this.shotError = '';
        const result = await this.state.toggleShot(shot.id, shot.projectId, shot.done);
        if (!operationCommitted(result)) {
            this.shotError = this.state.error || '拍摄勾选未保存，请重试';
        }
    }

    @Builder shots(project: CosProject) {
        Column() {
            DetailLink({ title: displayName(project.name), subtitle: '已拍 ' + this.state.readiness(project.id)
                    .shots.done + ' / ' + this.state.readiness(project.id)
                    .shots.total + ' 项', action: (): void => {
                        this.openShot(project.id, '');
                    }
            })
            Divider().color(Theme.line)
            ForEach(this.state.readiness(project.id).shots.items, (shot: ProjectShot) => {
                DayTaskRow({ title: shot.title, done: shot.done, interactive: !this.state.busy && !this.state.staleScopes.length,
                    secondaryLabel: shot.referenceId ? '参考' : '详情', toggle: (): void => {
                        void this.toggleShot(shot);
                    },
                    secondary: (): void => {
                        if (shot.referenceId) {
                            this.open('reference', shot.referenceId);
                        } else {
                            this.openShot(project.id, shot.id);
                        }
                    }
                })
                Divider().color(Theme.line)
            }, (shot: ProjectShot) => shot.id)
        }.padding({ left: 12, right: 12 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    }

    @Builder dayModule(module: DayModule) {
        Column({ space: 10 }) {
            SectionHeading({ title: module.id === 'packing' ? '打包清单' : module.id === 'people' ? '同行的人' : module.label })
            if (module.id === 'packing') {
                if (this.packingError) {
                    Text(this.packingError).id('day-packing-error').fontSize(15).fontColor(Theme.danger)
                }
                ForEach(this.projects(), (project: CosProject) => {
                    this.packing(project)
                }, (project: CosProject) => project.id)
            } else if (module.id === 'credentials') {
                Column() {
                    ForEach(this.credentials(), (entry: CollectedEntry) => {
                        Button() {
                            Row({ space: 12 }) {
                                if (entry.thumbnailPath || entry.localPath) {
                                    ManagedImage({ sourcePath: entry.thumbnailPath || entry.localPath, label: entryTitle(entry), ratio: 1 }).width(48).height(48)
                                } else {
                                    Image(Icons.library).width(24).height(24).fillColor(Theme.muted)
                                }
                                Text(entryTitle(entry)).fontSize(17).layoutWeight(1).fontColor(Theme.ink)
                                Image(Icons.chevronRight).width(14).height(14).fillColor(Theme.muted)
                            }.width('100%').padding({ top: 12, bottom: 12 })
                        }.type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 64 }).backgroundColor(Color.Transparent)
                            .onClick((): void => {
                                this.credential = entry;
                                this.viewing = true;
                            }).accessibilityText('打开凭证 ' + entryTitle(entry))
                        Divider().color(Theme.line)
                    }, (entry: CollectedEntry) => entry.id)
                }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            } else if (module.id === 'people') {
                Column() {
                    ForEach(this.projects(), (project: CosProject) => {
                        ForEach(this.state.team.filter((member: TeamMember) => member.projectId === project.id), (member: TeamMember) => {
                            Row({ space: 12 }) {
                                Column({ space: 6 }) {
                                    Row({ space: 8 }) {
                                        Text(member.name).fontSize(17).fontColor(Theme.ink).layoutWeight(1)
                                        if (member.role) {
                                            StatusPill({ label: member.role })
                                        }
                                    }.width('100%')
                                    Text(member.notes || displayName(project.name))
                                        .fontSize(13)
                                        .fontColor(Theme.muted)
                                        .maxLines(2)
                                        .copyOption(CopyOptions.LocalDevice)
                                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                                if (member.notes) {
                                    Button('复制')
                                        .type(ButtonType.Normal)
                                        .constraintSize({ minHeight: 64, minWidth: 48 })
                                        .backgroundColor(Color.Transparent)
                                        .fontColor(Theme.accent)
                                        .fontSize(14)
                                        .onClick((): void => {
                                            this.copyContact(member);
                                        }).accessibilityText('复制 ' + member.name + ' 的备注或联系方式')
                                }
                            }.width('100%').padding({ top: 12, bottom: 12 })
                            Divider().color(Theme.line)
                        }, (member: TeamMember) => member.id)
                    }, (project: CosProject) => project.id)
                }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            } else if (module.id === 'plans') {
                Column() {
                    ForEach(this.projects(), (project: CosProject) => {
                        DetailLink({ title: displayName(project.name), subtitle: planShootingLabel(project, this.state.events),
                            value: PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)], action: (): void => {
                                this.open('project', project.id);
                            }
                        })
                        Divider().color(Theme.line)
                    }, (project: CosProject) => project.id)
                }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            } else if (module.id === 'shots') {
                if (this.shotError) {
                    Text(this.shotError).fontSize(15).fontColor(Theme.danger)
                }
                ForEach(this.projects().filter((project: CosProject) => this.state.readiness(project.id).shots.total > 0), (project: CosProject) => {
                    this.shots(project)
                }, (project: CosProject) => project.id)
            } else if (module.id === 'timeline') {
                Column() {
                    ForEach(eventTimeline(this.event, this.state.projects), (item: DayTimelineItem) => {
                        Row({ space: 12 }) {
                            Text(item.time).width(64).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                            if (item.projectId) {
                                DetailLink({ title: displayName(item.label), subtitle: item.date || '日期待定', action: (): void => {
                                        this.open('project', item.projectId);
                                    }
                                }).layoutWeight(1)
                            } else {
                                Column({ space: 5 }) {
                                    Text(displayName(item.label)).fontSize(16).fontColor(Theme.ink);
                                    Text(item.date || '日期待定').fontSize(13).fontColor(Theme.muted)
                                }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ top: 16, bottom: 16 })
                            }
                        }.id('day-timeline:' + item.id).width('100%').constraintSize({ minHeight: 64 })
                        Divider().color(Theme.line)
                    }, (item: DayTimelineItem) => item.id)
                }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            } else if (module.id === 'wrapup') {
                Column() {
                    DetailLink({ title: '留下今天的照片', subtitle: '选择所属计划后导入', icon: Icons.importPhoto, action: (): void => {
                            this.route.recordKind = 2;
                            this.route.recording = true;
                        }
                    })
                }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    @Local availableWidth: number = 360;
    build() {
        Column() {
            if (this.route.dayMode) {
                Blank().height(this.contentTop - 16).width('100%');
                this.dayHeader()
            }
            HdsViewTabs({ labels: this.route.dayMode ? ['出发前', '现场'] : ['概览', '本场计划', '收录', '提醒'],
                icons: this.route.dayMode ? [Icons.library, Icons.event] : [Icons.home, Icons.plan, Icons.importPhoto, Icons.event],
                selectedIndex: this.route.section, componentId: 'event-view-tabs', effects: this.state.settings.effects,
                materialLevel: this.state.settings.materialLevel, availableWidth: this.availableWidth,
                haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
                changed: (index: number): void => {
                    this.route.section = index;
                }, content: (): void => {
                    this.viewContent();
                }
            }).layoutWeight(1)
        }.width('100%').height('100%').onAreaChange((_, area: Area): void => {
            this.availableWidth = Number(area.width);
            this.contentOrigin = Number(area.globalPosition.y);
            this.updateTopInset();
        })
    }

    private nativeSheetVisible(): boolean {
        return this.locationOpen || this.linking || this.route.configuring || this.route.recording || this.viewing;
    }

    @Builder viewContent() {
        // The collection owns its editor sheet here. Other event tools replace that
        // host with the event sheet, keeping the root plus destination at two hosts.
        if (!this.route.dayMode && this.route.section === 2 && !this.nativeSheetVisible()) {
            EntryCollectionView({ embedded: false, state: this.state, route: this.route.entries, componentId: 'event-entries-scroll', restoreVersion: this.route.restoreVersion,
                topInset: this.contentTop, bottomInset: Theme.detailFloatingBottom, horizontalPadding: Theme.pagePadding, open: this.open })
        } else {
            Column() {
                if (!this.route.dayMode && this.route.section === 2) {
                    EntryCollectionView({ embedded: true, state: this.state, route: this.route.entries, componentId: 'event-entries-scroll', restoreVersion: this.route.restoreVersion,
                        topInset: this.contentTop, bottomInset: Theme.detailFloatingBottom, horizontalPadding: Theme.pagePadding, open: this.open })
                        .layoutWeight(1)
                } else {
                    Scroll(this.scroller) {
                        Column({ space: Theme.sectionSpacing }) {
                            if (!this.route.dayMode) {
                                if (this.route.section === 0) {
                                    this.overview()
                                } else if (this.route.section === 1) {
                                    this.plans()
                                } else {
                                    this.reminders()
                                }
                            } else {
                                ForEach(this.modules(), (module: DayModule) => {
                                    this.dayModule(module)
                                }, (module: DayModule) => module.id)
                                if (!this.modules().length) {
                                    Text('这一段暂时没有内容。可以在详情中关联计划、收录凭证，或开启已关闭的模块。').fontSize(17).fontColor(Theme.muted)
                                }
                            }
                            Blank().height(Theme.detailFloatingBottom).width('100%')
                        }.width('100%')
                            .constraintSize({ maxWidth: Theme.readingMaxWidth })
                            .padding({ top: this.route.dayMode ? 0 : this.contentTop, left: Theme.pagePadding, right: Theme.pagePadding })
                            .alignItems(HorizontalAlign.Start)
                    }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
                        .onAreaChange((_, area: Area): void => {
                            if (!this.measured && Number(area.height) > 0) {
                                this.measured = true;
                                this.restoreScroll();
                            }
                        })
                        .onDidScroll((): void => {
                            if (this.measured && !this.restoring) {
                                this.route.offsets[this.displayedIndex] = this.scroller.currentOffset().yOffset;
                            }
                        })
                }
            }.width('100%').height('100%')
                .bindSheet(this.nativeSheetVisible(), this.activeSheet(), this.sheetOptions())
        }
    }

    @Builder activeSheet() {
        SheetContent() {
            if (this.locationOpen) {
                LocationSheet({ city: this.event.city, venue: this.event.venue, writable: !this.state.busy && !this.state.staleScopes.length,
                    close: (): void => {
                        this.locationOpen = false;
                    }, editLocation: (): void => {
                        this.locationOpen = false;
                        this.edit('event', this.event.id, '');
                    }
                })
            } else if (this.linking) {
                this.linkSheet()
            } else if (this.route.configuring) {
                this.configurationSheet()
            } else if (this.route.recording) {
                this.recordSheet()
            } else {
                this.credentialSheet()
            }
        }
    }
}
