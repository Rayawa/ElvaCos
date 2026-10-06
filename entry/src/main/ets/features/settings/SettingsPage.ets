import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { SheetHeader } from '../../components/SheetHeader';
import { SettingsPreferenceRow } from '../../components/SettingsPreferenceRow';
import { SettingsValueRow } from '../../components/SettingsValueRow';
import { SettingsChoiceSlider } from '../../components/SettingsChoiceSlider';
import { SettingsPanel } from '../../components/SettingsPanel';
import { SettingsActionRow } from '../../components/SettingsActionRow';
import { Icons } from '../../common/Icons';
import { AppState } from '../../common/AppState';
import { APPEARANCE_LABELS, APPEARANCE_VALUES, HAND_LABELS, HAND_VALUES, Theme } from '../../common/Theme';
import { AppSettings } from '../../model/Entities';
import { APP_AUTHOR, APP_COPYRIGHT, APP_NAME_EN, APP_SITE, APP_VERSION } from '../../common/constants';
import { HapticService } from '../../services/haptic/HapticService';

@ComponentV2
export struct SettingsPage {
  @Param state: AppState = new AppState();
  @Param bottomInset: number = Theme.contentBottom;
  @Local animStep: number = 0;
  @Local helpOpen: boolean = false;
  @Local helpKind: string = 'usage';
  private enterTimers: number[] = [];
  // 二级页面：每次进入都重新播放入场动画。
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 4, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 0; }
  @Event destructive: (kind: string) => void = () => {};

  private async copySettings(): Promise<AppSettings> {
    return JSON.parse(JSON.stringify(this.state.settings)) as AppSettings;
  }

  private async hand(value: string): Promise<void> {
    const settings = await this.copySettings();
    settings.hand = value; settings.grip = value === 'auto';
    if (await this.state.updateSettings(settings)) { HapticService.confirm(settings.haptic, settings.hapticLevel); }
  }

  private async appearance(index: number): Promise<void> {
    const settings = await this.copySettings();
    settings.appearance = APPEARANCE_VALUES[index] || APPEARANCE_VALUES[APPEARANCE_VALUES.length - 1];
    if (await this.state.updateSettings(settings)) { HapticService.confirm(settings.haptic, settings.hapticLevel); }
  }

  private toggleAccount(): void {
    if (this.state.busy) { return; }
    if (this.state.account.signedIn) { this.state.signOutHuawei(); } else { this.state.signInHuawei(); }
  }

  private showHelp(kind: string): void { this.helpKind = kind; this.helpOpen = true; }

  @Builder divider() { Divider().color(Theme.line).strokeWidth(0.5).margin({ left: 16, right: 16 }) }
  @Builder groupTitle(title: string) { Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent).width('100%').padding({ left: Theme.sectionTitlePadding }) }

  @Builder appearanceControl() {
    SettingsChoiceSlider({
      index: Math.max(0, APPEARANCE_VALUES.indexOf(this.state.settings.appearance)),
      labels: APPEARANCE_LABELS, accessibilityLabel: '应用外观',
      isEnabled: !this.state.busy,
      changed: (index: number): void => { this.appearance(index); },
    })
  }

  @Builder handControl() {
    SettingsChoiceSlider({
      index: Math.max(0, HAND_VALUES.indexOf(this.state.settings.hand)),
      labels: HAND_LABELS, accessibilityLabel: '操作模式',
      isEnabled: !this.state.busy,
      changed: (index: number): void => { this.hand(HAND_VALUES[index] || 'left'); },
    })
  }

  @Builder preferenceItems() {
    Column() {
      SettingsPreferenceRow({ label: '应用外观', icon: Icons.light, control: (): void => { this.appearanceControl(); } })
      this.divider()
      SettingsPreferenceRow({ label: '操作模式', icon: Icons.user, control: (): void => { this.handControl(); } })
      this.divider()
    }.width('100%')
  }

  @Builder helpSheet() {
    Column({ space: 16 }) {
      SheetHeader({
        title: this.helpKind === 'usage' ? '使用说明' : '隐私协议',
        hint: this.helpKind === 'usage' ? '三分钟了解绮秀的用法' : '数据如何保存在你的设备上',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.helpOpen = false; },
      })
      Scroll() {
        Column({ space: 18 }) {
          if (this.helpKind === 'usage') {
            Text('准备一次 Cos').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('新建计划时选择已有角色，或一起创建角色。准备页添加本次装备，打包页逐件确认装包，照片页支持导入、筛选与批量选片。新增和编辑都在弹出的表单中完成。').fontSize(14).fontColor(Theme.muted)
            Text('操作模式').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('左手和右手固定出门清单确认按钮的位置。选择智感握持时申请感知权限，仅在出门模式检测；拒绝权限会保留原设置，设备不支持时可选择手动布局。').fontSize(14).fontColor(Theme.muted)
            Text('应用外观与材质等级').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('应用外观三档：天蓝为浅色、雾蓝为深色、跟随系统由系统设置决定，切换后全应用立即生效。材质等级为流畅时关闭原生材质、光场和按压增强。').fontSize(14).fontColor(Theme.muted)
          } else {
            Text('本地存储').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('角色、计划、衣柜与照片索引保存在本机加密数据库，照片保留一份原图与缩略图。不连接服务器，仅处理你通过系统选择器明确选中的照片。').fontSize(14).fontColor(Theme.muted)
            Text('华为账号').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('登录仅用于获取本机可离线使用的账号标识，应用不保存访问令牌，也不会把记录上传到任何服务器。云空间同步尚未开启，开启前所有数据只保存在本机。').fontSize(14).fontColor(Theme.muted)
            Text('备份与清除').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text('元数据导出为明文 JSON，不含照片文件；恢复会替换当前记录。清除缓存只处理临时文件，清空本地数据会删除应用内记录与照片副本，两项操作都需要确认，系统相册原图不受影响。').fontSize(14).fontColor(Theme.muted)
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top)
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
        .accessibilityText('Designed and Developed by Ray Chen Rayawa')
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
    .accessibilityGroup(true)
    .accessibilityText('版本版权和备案信息')
  }

  @Builder
  private appIdentity(): void {
    Column({ space: 10 }) {
      Image($r('app.media.app_icon'))
        .width(96)
        .height(96)
        .borderRadius(22)
        .accessibilityText('绮秀应用图标')
        .margin({ bottom: 6 })
      Text($r('app.string.app_display_name'))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.accent)
        .textAlign(TextAlign.Center)
        .accessibilityText('绮秀')
      Text(APP_NAME_EN)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.muted)
        .textAlign(TextAlign.Center)
        .accessibilityText('Elva Cos')
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 12, right: 12 })
    .accessibilityGroup(true)
    .accessibilityText('绮秀应用图标和名称')
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
          icon: Icons.me,
          actionLabel: this.state.account.signedIn ? '退出' : '登录',
          isEnabled: !this.state.busy,
          action: (): void => { this.toggleAccount(); },
        })
        this.divider()
        SettingsValueRow({
          label: '云同步',
          value: '暂未开启',
          hint: '云空间同步在路线图中，开启前记录只保存在本机',
          icon: Icons.cloud,
          isEnabled: false,
        })
      }.width('100%').backgroundColor(Theme.surface).borderRadius(16).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)
    }.width('100%').opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
  }

  @Builder
  private dataSection(): void {
    Column({ space: Theme.sectionContentGap }) {
      this.groupTitle('数据与备份')
      Column() {
        SettingsActionRow({ label: '导出元数据 JSON', icon: Icons.share, isEnabled: !this.state.busy, action: (): void => { this.state.exportData(); } })
        this.divider()
        SettingsActionRow({ label: '从元数据备份恢复', icon: Icons.importPhoto, isEnabled: !this.state.busy, action: (): void => { this.destructive('restore'); } })
        this.divider()
        SettingsActionRow({ label: '清空本地数据', icon: Icons.remove, danger: true, isEnabled: !this.state.busy, action: (): void => { this.destructive('clear'); } })
      }.width('100%').backgroundColor(Theme.surface).borderRadius(16).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)
    }.width('100%').opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
  }

  @Builder
  private helpSection(): void {
    Column({ space: Theme.sectionContentGap }) {
      this.groupTitle('帮助')
      Column() {
        SettingsActionRow({ label: '使用说明', icon: Icons.help, action: (): void => { this.showHelp('usage'); } })
        this.divider()
        SettingsActionRow({ label: '隐私协议', icon: Icons.light, action: (): void => { this.showHelp('privacy'); } })
      }.width('100%').backgroundColor(Theme.surface).borderRadius(16).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)
    }.width('100%').opacity(this.animStep >= 4 ? 1 : 0).translate({ y: this.animStep >= 4 ? 0 : 20 })
  }

  @Builder settings() {
    Column({ space: Theme.sectionSpacing }) {
      Column() {
        this.appIdentity()
      }.width('100%').opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })

      Divider().color(Theme.line).margin({ top: 4, bottom: 4 })

      this.accountSection()
      this.dataSection()

      Column({ space: Theme.sectionContentGap }) {
        this.groupTitle('设置')
        SettingsPanel({ active: true, additionalSettings: (): void => { this.preferenceItems(); }, onSettingsChanged: (): void => { this.state.reloadSettings(); } })
      }.width('100%').opacity(this.animStep >= 3 ? 1 : 0).translate({ y: this.animStep >= 3 ? 0 : 20 })

      this.helpSection()
      this.versionInformation()
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        this.settings()
        Blank().height(this.bottomInset).width('100%')
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding }).constraintSize({ maxWidth: 1440 })
    }.id('settings-scroll').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      .bindSheet(this.helpOpen, this.helpSheet(), appSheetOptions((): void => { this.helpOpen = false; }))
  }
}
