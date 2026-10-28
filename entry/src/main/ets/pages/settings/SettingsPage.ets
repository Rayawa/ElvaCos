import { formatTimestamp } from '../../utils/format/format';
import { DEVELOPER_ENTRANCE_TAPS, DEVELOPER_ENTRANCE_WINDOW_MS, APP_AUTHOR, APP_COPYRIGHT, APP_SITE, APP_VERSION } from '../../config/constants';
import { PreferenceSettings } from '../../components/settings/PreferenceSettings';
import { SettingsSelection, AppState } from '../../state/ApplicationState';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { StaggerEntrance } from '../../ui/animation/motion';
import { vibration } from '../../ui/feedback/vibration';
import { scrollByAxis } from '../../ui/layout/scroll';

import { appSheetOptions } from '../../ui/sheet/sheet';
import { SheetHeader } from '../../components/common/SheetHeader';
import { SettingsValueRow } from '../../components/settings/SettingsValueRow';
import { SettingsPanel } from '../../components/settings/SettingsPanel';
import { SettingsActionRow } from '../../components/settings/SettingsActionRow';
import { Icons } from '../../ui/icons/Icons';
import { Theme } from '../../ui/theme/Theme';

@ComponentV2
export struct SettingsPage {
    @Param section: number = 0;
    @Param offsets: number[] = [0, 0, 0];
    private restoreTimer: number = -1;
    private restoring: boolean = true;
    private measured: boolean = false;
    @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Require @Param state: AppState;
    @Param bottomInset: number = Theme.detailBottom;
    @Local helpOpen: boolean = false;
    @Local helpKind: string = 'usage';
    private pageScroller: Scroller = new Scroller();
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    aboutToAppear(): void {
        if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); }
    }

    aboutToDisappear(): void {
        if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; }
        this.feedback.dispose();
        if (this.versionTapTimer >= 0) {
            clearTimeout(this.versionTapTimer);
            this.versionTapTimer = -1;
        }
        if (!this.entrance.managed) {
            this.entrance.finish(4);
        }
    }

    @Event open: (kind: string, id: string) => void = () => {};
    @Event destructive: (kind: string) => void = () => {};
    @Event openDeveloper: () => void = () => {};
    private versionTaps: number = 0;
    private versionTapTimer: number = -1;
    /** 版本号连点进入开发者选项：只计数不振动，超时或点满后重新开始。 */

    private tapVersion(): void {
        if (this.versionTapTimer >= 0) {
            clearTimeout(this.versionTapTimer);
            this.versionTapTimer = -1;
        }
        this.versionTaps++;
        if (this.versionTaps >= DEVELOPER_ENTRANCE_TAPS) {
            this.versionTaps = 0;
            this.openDeveloper();
            return;
        }
        this.versionTapTimer = setTimeout((): void => {
            this.versionTapTimer = -1;
            this.versionTaps = 0;
        }, DEVELOPER_ENTRANCE_WINDOW_MS);
    }

    private showHelp(kind: string): void {
        this.helpKind = kind;
        this.helpOpen = true;
    }

    @Builder divider() {
        Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 16, right: 16 })
    }

    @Builder actionDivider() {
        Divider().color(Theme.groupDivider).margin({ left: 16, right: 16 })
    }

    @Builder groupTitle(title: string) {
        Text(title)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.accent)
            .width('100%')
            .padding({ left: Theme.sectionTitlePadding })
    }

    @Builder helpSheet() {
        Column({ space: 16 }) {
            SheetHeader({
                title: this.helpKind === 'cloud' ? '云空间与同步' : '使用说明',
                hint: this.helpKind === 'cloud' ? '备份与日历同步的当前能力' : '三分钟了解绮秀的用法',
                haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
                close: (): void => {
                    this.helpOpen = false;
                },
            }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
            Scroll() {
                Column({ space: 18 }) {
                    if (this.helpKind === 'cloud') {
                        Text('当前同步状态').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                        Text('应用尚未接入账号登录或云端数据同步。角色、计划、照片与收录保存在本机，离线业务可直接使用。').fontSize(14).fontColor(Theme.muted)
                        Text('备份到云空间').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                        Text('可以在系统文件选择器中将元数据导出到云空间。JSON 不含照片，照片原文件需另行保存；系统备份的恢复范围以设备服务为准。').fontSize(14).fontColor(Theme.muted)
                        Button('导出元数据备份')
                            .accessibilityText('导出元数据备份')
                            .width('100%')
                            .backgroundColor(Theme.brand)
                            .fontColor(Theme.onAccent)
                            .enabled(!this.state.busy)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.state.exportData();
                            })
                            .visualEffect(this.feedback.effect('button-1'))
                            .compositingFilter(this.feedback.filter('button-1'))
                            .attributeModifier(this.feedback.control('button-1'))
                        Text('设备日历').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                        Text('添加活动到设备日历时，在系统确认页选择日历账户与提醒。日历是否同步由系统日历和云空间设置决定，应用内计划与照片不会随之同步。').fontSize(14).fontColor(Theme.muted)
                    } else {
                        Text('准备一次 Cos').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                        Text('新建计划时选择已有角色，或一起创建角色。准备页添加本次装备，打包页逐件确认装包，照片页支持导入、筛选与批量选片。新增和编辑都在弹出的表单中完成。').fontSize(14).fontColor(Theme.muted)
                        Text('操作模式').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                        Text('左手和右手固定出门清单确认按钮的位置。选择智感握持时申请感知权限，仅在出门模式检测；拒绝权限会保留原设置，设备不支持时可选择手动布局。').fontSize(14).fontColor(Theme.muted)
                        Text('主题配色、应用外观与材质等级').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                        Text('主题配色可选蓝、绿、粉、橙、红，每组都包含浅色和深色。应用外观可选浅色、深色或跟随系统，切换后立即生效并记住选择。材质等级为流畅时关闭原生材质、光场和按压增强。').fontSize(14).fontColor(Theme.muted)
                    }
                }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
            }.layoutWeight(1)
                .width('100%')
                .align(Alignment.Top)
                .opacity(this.sheetEntrance.step >= 2 ? 1 : 0)
                .translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
        }.padding(24).width('100%').height('100%').backgroundColor(Theme.surface)
    }

    @Builder
    private versionInformation(): void {
        Column({ space: 5 }) {
            Text(`版本 ${APP_VERSION}`)
                .fontSize(12)
                .fontColor(Theme.muted)
                .accessibilityText(`版本${APP_VERSION}`)
            Text(APP_AUTHOR)
                .fontSize(12)
                .fontColor(Theme.muted)
                .textAlign(TextAlign.Center)
                .accessibilityText('设计与开发：Ray Chen，Rayawa')
            Text(APP_COPYRIGHT)
                .fontSize(12)
                .fontColor(Theme.muted)
                .textAlign(TextAlign.Center)
                .accessibilityText('版权所有2026')
            Text(APP_SITE)
                .fontSize(12)
                .fontColor(Theme.muted)
                .textAlign(TextAlign.Center)
                .accessibilityText('本应用备案域名rayawa点top')
        }.width('100%')
            .padding({ top: 14 })
        // 连点版本号进开发者选项；这里不发声也不振动，避免暴露入口。
            .onClick((): void => {
                this.tapVersion();
            })
            .accessibilityGroup(true)
            .accessibilityText(`版本 ${APP_VERSION}，版权所有 2026，备案域名 rayawa 点 top`)
    }

    @Builder
    private appIdentity(): void {
        Row({ space: 12 }) {
            Image($r('app.media.app_icon')).id('settings-app-icon').width(44).height(44).borderRadius(12)
                .accessibilityText($r('app.string.app_icon_label'))
            Text($r('app.string.app_display_name')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
        }.width('100%').padding(16).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            .accessibilityGroup(true)
    }

    @Builder
    private storageSection(): void {
        Column({ space: Theme.sectionContentGap }) {
            this.groupTitle('本机存储与同步')
            Column() {
                SettingsValueRow({
                    label: '云同步',
                    value: '尚未接入',
                    hint: '记录保存在本机，可查看备份方式',
                    icon: Icons.cloud,
                    actionLabel: '说明',
                    isEnabled: !this.state.busy,
                    action: (): void => {
                        vibration.dotVibration();
                        this.showHelp('cloud');
                    },
                })
            }.width('100%')
                .backgroundColor(Theme.surface)
                .borderRadius(16)
                .border({ width: 0.5, color: Theme.line })
                .clip(true)
        }.width('100%').opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
    }

    @Builder
    private dataSection(): void {
        Column({ space: Theme.sectionContentGap }) {
            this.groupTitle('数据与备份')
            Text(this.state.lastMetadataExport ? '最近成功导出元数据：' + formatTimestamp(this.state.lastMetadataExport) + '（不含照片）' : '尚无成功导出的元数据记录')
                .fontSize(14)
                .fontColor(Theme.muted)
            Column() {
                SettingsActionRow({
                    label: '导出元数据 JSON',
                    icon: Icons.exportData,
                    isEnabled: !this.state.busy,
                    action: (): void => {
                        this.state.exportData();
                    }
                })
                this.actionDivider()
                SettingsActionRow({
                    label: '从元数据备份恢复',
                    icon: Icons.restoreData,
                    isEnabled: !this.state.busy,
                    action: (): void => {
                        this.destructive('restore');
                    }
                })
                this.actionDivider()
                SettingsActionRow({
                    label: '清空本地数据',
                    icon: Icons.trash,
                    danger: true,
                    isEnabled: !this.state.busy,
                    action: (): void => {
                        this.destructive('clear');
                    }
                })
            }.width('100%')
                .backgroundColor(Theme.surface)
                .borderRadius(16)
                .border({ width: 0.5, color: Theme.line })
                .clip(true)
        }.width('100%').opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
    }

    @Builder
    private helpSection(): void {
        Column({ space: Theme.sectionContentGap }) {
            this.groupTitle('帮助')
            Column() {
                SettingsActionRow({ label: '使用说明', icon: Icons.tutorial, action: (): void => {
                        this.showHelp('usage');
                    }
                })
                this.actionDivider()
                SettingsActionRow({ label: '更新日志', icon: Icons.appLog, action: (): void => {
                        this.open('appLog', 'appLog');
                    }
                })
                this.actionDivider()
                SettingsActionRow({ label: '隐私政策', icon: Icons.privacy, action: (): void => {
                        this.open('privacy', 'privacy');
                    }
                })
            }.width('100%')
                .backgroundColor(Theme.surface)
                .borderRadius(16)
                .border({ width: 0.5, color: Theme.line })
                .clip(true)
        }.width('100%').opacity(this.entrance.step >= 4 ? 1 : 0).translate({ y: this.entrance.step >= 4 ? 0 : 20 })
    }

    @Builder
    private preferenceItems(): void {
        PreferenceSettings({
            isEnabled: !this.state.busy,
            save: (changes: SettingsSelection): Promise<boolean> => this.state.updateSettings(changes),
        })
    }

    @Builder settingsAndLinks() {
        Column({ space: Theme.sectionSpacing }) {
            if (this.section === 0) {
                Column({ space: Theme.sectionContentGap }) {
                    this.groupTitle('偏好与交互')
                    SettingsPanel({ active: true, additionalSettings: this.preferenceItems.bind(this),
                        onSettingsChanged: (): void => { this.state.reloadSettings(); } })
                    if (this.state.settingsBusy) { Text('正在保存设置…').fontSize(12).fontColor(Theme.muted) }
                }.width('100%')
            } else if (this.section === 1) {
                this.storageSection()
                this.dataSection()
            } else {
                this.helpSection()
                this.appIdentity()
                this.versionInformation()
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    build() {
        Scroll(this.pageScroller) {
            Column({ space: Theme.sectionSpacing }) {
                Blank().height(Theme.detailTop).width('100%')
                this.settingsAndLinks()
                Blank().height(this.bottomInset).width('100%')
            }.width('100%').constraintSize({ maxWidth: Theme.readingMaxWidth })
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        }.id('settings-scroll').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
            .edgeEffect(EdgeEffect.Spring)
            .onAreaChange((_, area: Area): void => {
                if (this.measured || Number(area.height) <= 0) { return; }
                this.measured = true;
                const offset = this.offsets[this.section];
                this.restoreTimer = setTimeout((): void => {
                    this.restoreTimer = -1;
                    this.pageScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
                    this.restoring = false;
                }, 0);
            })
            .onDidScroll((): void => { if (!this.restoring) { this.offsets[this.section] = this.pageScroller.currentOffset().yOffset; } })
            .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.pageScroller, event); })
            .bindSheet(this.helpOpen, this.helpSheet(), appSheetOptions((): void => { this.helpOpen = false; }, this.sheetEntrance, this.getUIContext()))
    }
}
