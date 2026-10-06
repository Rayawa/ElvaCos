import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { SettingsPreferenceRow } from '../../components/SettingsPreferenceRow';
import { SettingsPanel } from '../../components/SettingsPanel';
import { SettingsHandControl } from '../../components/SettingsHandControl';
import { SettingsActionRow } from '../../components/SettingsActionRow';
import { Icons } from '../../common/Icons';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { AppSettings } from '../../model/Entities';
import { HapticService } from '../../services/haptic/HapticService';

@ComponentV2
export struct SettingsPage {
  @Param state: AppState = new AppState();
  @Param bottomInset: number = Theme.contentBottom;
  @Local animStep: number = 0;
  @Local helpOpen: boolean = false;
  @Local helpKind: string = 'usage';
  @Local appearanceHelp: boolean = false;
  private enterTimers: number[] = [];
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 3, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; }
  @Event destructive: (kind: string) => void = () => {};
  private async hand(value: string): Promise<void> {
    const settings = JSON.parse(JSON.stringify(this.state.settings)) as AppSettings;
    settings.hand = value; settings.grip = value === 'auto';
    if (await this.state.updateSettings(settings)) { HapticService.confirm(settings.haptic, settings.hapticLevel); }
  }
  private showHelp(kind: string): void { this.helpKind = kind; this.helpOpen = true; }
  @Builder divider() { Divider().color($r('app.color.border')).strokeWidth(0.5).margin({ left: 16, right: 16 }) }
  @Builder groupTitle(title: string) { Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.accent).width('100%').padding({ left: Theme.sectionTitlePadding }) }
  @Builder themeControl() {
    Row({ space: 8 }) {
      Text('跟随系统').fontSize(14).fontColor(Theme.muted)
      Image(Icons.help).width(22).height(22).objectFit(ImageFit.Contain)
        .onClick((): void => { this.appearanceHelp = !this.appearanceHelp; })
        .bindPopup(this.appearanceHelp, { message: '外观自动跟随系统的浅色或深色设置。', onStateChange: (event): void => { if (!event.isVisible) { this.appearanceHelp = false; } } })
        .accessibilityText('查看外观说明')
    }.width(190).justifyContent(FlexAlign.End).padding({ right: 5 })
  }
  @Builder handControl() {
    SettingsHandControl({ hand: this.state.settings.hand, isEnabled: !this.state.busy, changed: (value: string): void => { this.hand(value); } })
  }
  @Builder preferenceItems() {
    Column() {
      SettingsPreferenceRow({ label: '外观', icon: Icons.light, control: (): void => { this.themeControl(); } })
      this.divider()
      SettingsPreferenceRow({ label: '单手操作', icon: Icons.user, control: (): void => { this.handControl(); } })
      this.divider()
    }.width('100%')
  }
  @Builder helpSheet() {
    Column({ space: 16 }) {
      Row() {
        Text(this.helpKind === 'usage' ? '使用说明' : '数据与隐私说明').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.ink).layoutWeight(1)
        Button('完成').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { this.helpOpen = false; })
      }.width('100%')
      Scroll() {
        Column({ space: 18 }) {
          if (this.helpKind === 'usage') {
            Text('准备一次 Cos').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text('新建计划时选择已有角色，或一起创建角色。准备页添加本次装备，打包页逐件确认装包，照片页支持导入、筛选与批量选片。新增和编辑均在弹出表单中完成。').fontColor(Theme.muted)
            Text('单手操作').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text('左手和右手固定出门清单确认按钮的位置。选择智感握持时申请感知权限，仅在出门模式检测；拒绝权限会保留原设置，设备不支持时可选择手动布局。').fontColor(Theme.muted)
            Text('材质等级').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text('流畅关闭原生材质、光场和 HDR 按压增强；轻柔和精美开启对应等级的原生视效。外观始终跟随系统。').fontColor(Theme.muted)
          } else {
            Text('本地存储').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text('记录保存在加密数据库，照片保留一份原图与缩略图。无需账号，不连接服务器。仅处理你通过系统选择器明确选中的照片。').fontColor(Theme.muted)
            Text('备份与恢复').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text('元数据导出为明文 JSON，不含照片文件；恢复会替换当前记录。完整照片迁移请使用系统备份，跨设备恢复仍需验证。').fontColor(Theme.muted)
            Text('缓存与清空').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
            Text('清除缓存仅处理临时文件；清空本地数据会删除应用内记录与照片副本。两项操作均需确认，系统相册原图保留。').fontColor(Theme.muted)
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top)
    }.padding(24).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder
  private versionInformation(): void {
    Column({ space: 5 }) {
      Text(`版本 1.0.0`)
        .fontSize(12)
        .fontColor($r('app.color.v3_text_secondary'))
        .onClick(() => {
          // this.vibrate();
          // this.tapVersion();
        })
        .accessibilityText(`版本1.0.0`)
      Text('Designed & Developed by Ray Chen (Rayawa)')
        .fontSize(12)
        .fontColor($r('app.color.v3_text_secondary'))
        .textAlign(TextAlign.Center)
        .accessibilityText('Designed and Developed by Ray Chen Rayawa')
      Text('Copyright © 2026. All rights reserved.')
        .fontSize(12)
        .fontColor($r('app.color.v3_text_secondary'))
        .textAlign(TextAlign.Center)
        .accessibilityText('版权所有2026')
      Text('本应用备案域名：rayawa.top')
        .fontSize(12)
        .fontColor($r('app.color.v3_text_secondary'))
        .textAlign(TextAlign.Center)
        .accessibilityText('本应用备案域名rayawa点top')
      // Text('京ICP备2025153453号')
      //   .fontSize(12)
      //   .fontColor($r('app.color.diff_content'))
      //   .decoration({ type: TextDecorationType.Underline, color: $r('app.color.diff_content') })
      //   .onClick(() => {
      //     this.vibrate();
      //     this.openIcp();
      //   })
      //   .accessibilityText('京ICP备2025153453号，点击打开工信部备案页面')
    }
    .width('100%')
    .padding({ top: 14 })

    .accessibilityGroup(true)
    .accessibilityText('版本版权和备案信息')
  }
  @Builder settings() {
    Column({ space: Theme.sectionSpacing }) {
      Column({ space: 10 }) {
        Image($r('app.media.app_icon'))
          .width(100)
          .height(100)
          .borderRadius(22)
          .accessibilityText('Elva Cos图标')
          .margin({ bottom: 10 })
        Text('绮秀')
          .fontSize(30)
          .fontWeight(800)
          .fontColor($r('app.color.diff_content'))
          .textAlign(TextAlign.Center)
          .accessibilityText('绮秀')
        Text('Elva Cos')
          .fontSize(20)
          .fontWeight(600)
          .fontColor($r('app.color.v3_text_secondary'))
          .textAlign(TextAlign.Center)
          .accessibilityText('Elva Cos')
      }
      .width('100%')
      .padding({ top: 18, bottom: 18, left: 12, right: 12 })
      .accessibilityGroup(true)
      .accessibilityText('Dashboard应用图标和名称')
      Divider().color($r('app.color.border')).margin({ top: 8, bottom: 8 })
      Column({ space: Theme.sectionContentGap }) {
        this.groupTitle('设置')
        SettingsPanel({ active: true, additionalSettings: (): void => { this.preferenceItems(); }, onSettingsChanged: (): void => { this.state.reloadSettings(); } })
      }.width('100%').opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
      Divider().color($r('app.color.border')).margin({ top: 8, bottom: 8 })
      Column({ space: Theme.sectionContentGap }) {
      this.groupTitle('数据与备份')
      Column() {
        SettingsActionRow({ label: '导出元数据 JSON', icon: Icons.share, isEnabled: !this.state.busy, action: () => this.state.exportData() })
        this.divider()
        SettingsActionRow({ label: '从元数据备份恢复', icon: Icons.importPhoto, isEnabled: !this.state.busy, action: () => this.destructive('restore') })
        this.divider()
        SettingsActionRow({ label: '清空本地数据', icon: Icons.remove, danger: true, isEnabled: !this.state.busy, action: () => this.destructive('clear') })
      }.width('100%').backgroundColor(Theme.surface).borderRadius(16).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)
      }.width('100%').opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
      Divider().color($r('app.color.border')).margin({ top: 8, bottom: 8 })
      Column({ space: Theme.sectionContentGap }) {
        this.groupTitle('帮助')
        Column() {
          SettingsActionRow({ label: '使用说明', icon: Icons.help, action: (): void => { this.showHelp('usage'); } })
          this.divider()
          SettingsActionRow({ label: '数据与隐私说明', icon: Icons.light, action: (): void => { this.showHelp('data'); } })
        }.width('100%').backgroundColor(Theme.surface).borderRadius(16).shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)
      }.width('100%').opacity(this.animStep >= 3 ? 1 : 0).translate({ y: this.animStep >= 3 ? 0 : 20 })
      this.versionInformation()
    }.alignItems(HorizontalAlign.Start).width('100%')
  }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) { Blank().height(Theme.contentTop).width('100%'); this.settings() }.width('100%').padding({ bottom: this.bottomInset, left: Theme.pagePadding, right: Theme.pagePadding }).constraintSize({ maxWidth: 1440 })
    }.id('settings-scroll').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      .bindSheet(this.helpOpen, this.helpSheet(), { height: SheetSize.LARGE, showClose: false, maskColor: Theme.scrim, onDisappear: (): void => { this.helpOpen = false; } })
  }
}
