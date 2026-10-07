import { DEVELOPER_ENTRANCE_TAPS, DEVELOPER_ENTRANCE_WINDOW_MS, MIN_SPLIT_HEIGHT, SETTINGS_ENTRANCE_KEY } from '../../common/constants';
import { PreferenceSettings } from '../../component/PreferenceSettings';
import { SettingsSelection } from '../../model/ApplicationState';
import { PressFeedback } from '../../common/pressFeedback';
import { MainEntranceSession, StaggerEntrance } from '../../common/motion';
import { vibration } from '../../common/vibration';
import { scrollByAxis } from '../../common/scroll';
import { DashboardSplitLayout } from '../../component/DashboardSplitLayout';
import { appSheetOptions } from '../../common/sheet';
import { SheetHeader } from '../../component/SheetHeader';
import { SettingsValueRow } from '../../component/SettingsValueRow';
import { SettingsPanel } from '../../component/SettingsPanel';
import { SettingsActionRow } from '../../component/SettingsActionRow';
import { Icons } from '../../common/Icons';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { APP_AUTHOR, APP_COPYRIGHT, APP_NAME_EN, APP_SITE, APP_VERSION } from '../../common/constants';

@ComponentV2
export struct SettingsPage {
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Param bottomInset: number = Theme.contentBottom;
  @Local helpOpen: boolean = false;
  @Local helpKind: string = 'usage';
  @Local contentWidth: number = 0;
  @Local contentHeight: number = 0;
  private pageScroller: Scroller = new Scroller();
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();

  aboutToAppear(): void {
    if (this.entrance.managed) { return; }
    if (this.entranceSession.claim(SETTINGS_ENTRANCE_KEY)) {
      this.entrance.play(this.getUIContext());
    } else {
      this.entrance.finish(4);
    }
  }

  aboutToDisappear(): void {
    if (this.versionTapTimer >= 0) { clearTimeout(this.versionTapTimer); this.versionTapTimer = -1; }
    if (!this.entrance.managed) { this.entrance.finish(4); }
  }
  @Event open: (kind: string, id: string) => void = () => {};
  @Event destructive: (kind: string) => void = () => {};
  @Event openDeveloper: () => void = () => {};
  private versionTaps: number = 0;
  private versionTapTimer: number = -1;

  /** 版本号连点进入开发者选项：只计数不振动，超时或点满后重新开始。 */
  private tapVersion(): void {
    if (this.versionTapTimer >= 0) { clearTimeout(this.versionTapTimer); this.versionTapTimer = -1; }
    this.versionTaps++;
    if (this.versionTaps >= DEVELOPER_ENTRANCE_TAPS) {
      this.versionTaps = 0;
      this.openDeveloper();
      return;
    }
    this.versionTapTimer = setTimeout((): void => { this.versionTapTimer = -1; this.versionTaps = 0; }, DEVELOPER_ENTRANCE_WINDOW_MS);
  }

  private toggleAccount(): void {
    if (this.state.busy) { return; }
    if (this.state.account.signedIn) { this.state.signOutHuawei(); } else { this.state.signInHuawei(); }
  }

  private showHelp(kind: string): void { this.helpKind = kind; this.helpOpen = true; }

  @Builder divider() { Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 16, right: 16 }) }
  @Builder actionDivider() { Divider().color(Theme.groupDivider).margin({ left: 16, right: 16 }) }
  @Builder groupTitle(title: string) { Text(title)
    .fontSize(14)
    .fontWeight(FontWeight.Bold)
    .fontColor(Theme.accent)
    .width('100%')
    .padding({ left: Theme.sectionTitlePadding }) }

  @Builder helpSheet() {
    Column({ space: 16 }) {
      SheetHeader({
        title: this.helpKind === 'cloud' ? '云空间与同步' : '使用说明',
        hint: this.helpKind === 'cloud' ? '备份与日历同步的当前能力' : '三分钟了解绮秀的用法',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.helpOpen = false; },
      }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
      Scroll() {
        Column({ space: 18 }) {
          if (this.helpKind === 'cloud') {
            Text('当前同步状态').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('应用尚未接入云端数据同步，登录华为账号不会自动上传角色、计划和照片。现有记录保存在本机。').fontSize(14).fontColor(Theme.muted)
            Text('备份到云空间').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('可以导出元数据，在系统文件选择器中选择可用的云空间位置。JSON 不包含照片，完整数据与媒体需使用系统备份。').fontSize(14).fontColor(Theme.muted)
            Button('导出元数据备份')
              .accessibilityText('导出元数据备份')
              .width('100%')
              .backgroundColor(Theme.brand)
              .fontColor(Theme.onAccent)
              .enabled(!this.state.busy)
              .onClick((): void => { vibration.dotVibration(); this.state.exportData(); })
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
      }.layoutWeight(1).width('100%').align(Alignment.Top).opacity(this.sheetEntrance.step >= 2 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
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
    }
    .width('100%')
    .padding({ top: 14 })
    // 连点版本号进开发者选项；这里不发声也不振动，避免暴露入口。
    .onClick((): void => { this.tapVersion(); })
    .accessibilityGroup(true)
    .accessibilityText(`版本 ${APP_VERSION}，版权所有 2026，备案域名 rayawa 点 top`)
  }

  @Builder
  private appIdentity(): void {
    Column({ space: 10 }) {
      Image($r('app.media.app_icon'))
        .id('settings-app-icon')
        .width(96)
        .height(96)
        .borderRadius(22)
        .accessibilityText($r('app.string.app_icon_label'))
        .margin({ bottom: 6 })
      Text($r('app.string.app_display_name'))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.accent)
        .textAlign(TextAlign.Center)
        .accessibilityText($r('app.string.app_display_name'))
      Text(APP_NAME_EN)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.muted)
        .textAlign(TextAlign.Center)
        .accessibilityText(APP_NAME_EN)
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 12, right: 12 })
    .accessibilityGroup(true)
    .accessibilityText('应用图标和名称')
  }

  @Builder
  private accountSection(): void {
    Column({ space: Theme.sectionContentGap }) {
      this.groupTitle('华为账号')
      Column() {
        SettingsValueRow({
          label: '华为账号',
          value: this.state.account.signedIn ? (this.state.account.displayName || '已登录') : '未登录',
          hint: this.state.account.signedIn ? '登录态只保存在本机，可随时退出' : '登录后可获得本机可离线使用的账号标识',
          icon: Icons.user,
          actionLabel: this.state.accountBusy ? '处理中…' : this.state.account.signedIn ? '退出' : '登录',
          isEnabled: !this.state.busy,
          action: (): void => { this.toggleAccount(); },
        })
        this.actionDivider()
        SettingsValueRow({
          label: '云同步',
          value: '尚未接入',
          hint: '记录保存在本机，可查看备份方式',
          icon: Icons.cloud,
          actionLabel: '说明',
          isEnabled: !this.state.busy,
          action: (): void => { vibration.dotVibration(); this.showHelp('cloud'); },
        })
      }.width('100%')
        .backgroundColor(Theme.surface)
        .borderRadius(16)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
        .clip(true)
    }.width('100%').opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
  }

  @Builder
  private dataSection(): void {
    Column({ space: Theme.sectionContentGap }) {
      this.groupTitle('数据与备份')
      Column() {
        SettingsActionRow({
          label: '导出元数据 JSON',
          icon: Icons.exportData,
          isEnabled: !this.state.busy,
          action: (): void => { this.state.exportData(); }
        })
        this.actionDivider()
        SettingsActionRow({
          label: '从元数据备份恢复',
          icon: Icons.restoreData,
          isEnabled: !this.state.busy,
          action: (): void => { this.destructive('restore'); }
        })
        this.actionDivider()
        SettingsActionRow({
          label: '清空本地数据',
          icon: Icons.trash,
          danger: true,
          isEnabled: !this.state.busy,
          action: (): void => { this.destructive('clear'); }
        })
      }.width('100%')
        .backgroundColor(Theme.surface)
        .borderRadius(16)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
        .clip(true)
    }.width('100%').opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
  }

  @Builder
  private helpSection(): void {
    Column({ space: Theme.sectionContentGap }) {
      this.groupTitle('帮助')
      Column() {
        SettingsActionRow({ label: '使用说明', icon: Icons.tutorial, action: (): void => { this.showHelp('usage'); } })
        this.actionDivider()
        SettingsActionRow({ label: '更新日志', icon: Icons.appLog, action: (): void => { this.open('appLog', 'appLog'); } })
        this.actionDivider()
        SettingsActionRow({ label: '隐私政策', icon: Icons.privacy, action: (): void => { this.open('privacy', 'privacy'); } })
      }.width('100%')
        .backgroundColor(Theme.surface)
        .borderRadius(16)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
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
      this.accountSection()
      this.dataSection()

      Column({ space: Theme.sectionContentGap }) {
        this.groupTitle('设置')
        SettingsPanel({
          active: true,
          additionalSettings: this.preferenceItems.bind(this),
          onSettingsChanged: (): void => { this.state.reloadSettings(); },
        })
        Text(this.state.settingsBusy ? '正在保存设置…' : '').height(16).fontSize(12).fontColor(Theme.muted)
      }.width('100%').opacity(this.entrance.step >= 3 ? 1 : 0).translate({ y: this.entrance.step >= 3 ? 0 : 20 })

      this.helpSection()
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder settings() {
    Column({ space: Theme.sectionSpacing }) {
      Column() {
        this.appIdentity()
      }.width('100%').opacity(this.entrance.step >= 1 ? 1 : 0).translate({ y: this.entrance.step >= 1 ? 0 : 20 })
      Divider().color(Theme.divider)
      this.settingsAndLinks()
      Divider().color(Theme.divider)
      this.versionInformation()
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder wideInformation() {
    Column({ space: Theme.sectionSpacing }) {
      this.appIdentity()
      Divider().color(Theme.divider)
      this.versionInformation()
    }.width('100%').attributeModifier(this.entrance.group(1))
  }

  @Builder wideSettings() {
    DashboardSplitLayout({
      scroller: this.pageScroller, overviewTop: Theme.detailTop, bottomInset: this.bottomInset, scrollSpacing: 0,
      layoutId: 'settings-wide-layout', overviewId: 'settings-fixed-information', scrollId: 'settings-scroll',
      overviewLabel: '固定显示的应用名称和版本信息', scrollLabel: '可滚动的账号、数据、设置与帮助列表',
      overview: (): void => { this.wideInformation(); }, content: (): void => { this.settingsAndLinks(); },
    })
  }

  build() {
    Column() {
      if (this.contentWidth >= Theme.wideBreakpoint && this.contentHeight >= MIN_SPLIT_HEIGHT) {
        this.wideSettings()
      } else {
        Scroll(this.pageScroller) {
          Column({ space: Theme.sectionSpacing }) {
            Blank().height(Theme.detailTop).width('100%')
            this.settings()
            Blank().height(this.bottomInset).width('100%')
          }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        }.id('settings-scroll').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Center)
      .onAreaChange((_, area: Area): void => { this.contentWidth = Number(area.width); this.contentHeight = Number(area.height); })
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.pageScroller, event); })
      .bindSheet(this.helpOpen, this.helpSheet(), appSheetOptions((): void => { this.helpOpen = false; }, this.sheetEntrance, this.getUIContext()))
  }
}
