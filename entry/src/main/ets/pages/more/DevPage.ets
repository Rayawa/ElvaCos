import { APP_BUILD_NUMBER, APP_VERSION, READING_MAX_WIDTH, SCHEMA_VERSION } from '../../common/constants';
import { DeviceInfoEntry, deviceInfoEntries } from '../../common/DeviceInfo';
import { Icons } from '../../common/Icons';
import { StaggerEntrance } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { SystemCapability } from '../../common/SystemCapability';
import { Theme } from '../../common/Theme';
import { SectionHeading } from '../../component/Surfaces';
import { SettingsValueRow } from '../../component/SettingsValueRow';
import { AppState } from '../../model/ApplicationState';

/**
 * 开发者选项：由设置页连点版本号五次进入，只承载调试与演示用途的入口和只读诊断信息。
 * 页面本体由 Dashboard 的 DetailDestination 承载（HDS 标题栏材质 / 入场动效 / 返回振动 / 无障碍标签）。
 */
@ComponentV2
export struct DevPage {
  private scroller: Scroller = new Scroller();
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Require @Param state: AppState;
  @Local loading: boolean = false;

  aboutToAppear(): void { if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (!this.entrance.managed) { this.entrance.reset(); } }

  private async loadDemo(): Promise<void> {
    if (this.loading) { return; }
    this.loading = true;
    try { await this.state.loadDemoData(); }
    finally { this.loading = false; }
  }

  @Computed
  private get deviceEntries(): DeviceInfoEntry[] { return deviceInfoEntries(); }

  @Computed
  private get capabilitySummary(): string {
    const missing: string[] = [];
    if (!SystemCapability.effects()) { missing.push('HDS 材质'); }
    if (!SystemCapability.haptic()) { missing.push('振动'); }
    if (!SystemCapability.grip()) { missing.push('握姿'); }
    if (!SystemCapability.share()) { missing.push('分享'); }
    return missing.length === 0 ? '全部可用' : '不可用：' + missing.join('、');
  }

  /** 一行只读信息：标签固定宽度、值占满剩余宽度并自动断行，长值（哈希、ABI、计数）不会撑破卡片。 */
  @Builder
  private fieldRow(label: string, value: string): void {
    Row({ space: 12 }) {
      Text(label).fontSize(14).fontColor(Theme.muted).maxLines(1)
      Text(value)
        .fontSize(14)
        .fontColor(Theme.ink)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .wordBreak(WordBreak.BREAK_ALL)
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16, top: 11, bottom: 11 })
    .accessibilityGroup(true)
    .accessibilityText(label + '：' + value)
  }

  @Builder
  private fieldDivider(): void {
    Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 16, right: 16 })
  }

  @Builder
  private content(): void {
    Column({ space: Theme.sectionContentGap }) {
      Blank().height(Theme.detailTop).accessibilityLevel('no')
      SectionHeading({ title: '数据工具' })
      Column() {
        SettingsValueRow({
          label: '载入示例数据',
          hint: '追加原神与绝区零的演示角色、计划与活动，可重复载入；需要清空时在设置页操作',
          icon: Icons.restoreData,
          actionLabel: this.loading ? '载入中…' : '载入',
          isEnabled: this.state.ready && !this.state.busy,
          action: (): void => { this.loadDemo(); },
        })
      }.width('100%')
        .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)

      SectionHeading({ title: '应用信息' })
      Column() {
        this.fieldRow('应用版本', APP_VERSION)
        this.fieldDivider()
        this.fieldRow('构建号', String(APP_BUILD_NUMBER))
        this.fieldDivider()
        this.fieldRow('数据库结构', 'v' + SCHEMA_VERSION)
        this.fieldDivider()
        this.fieldRow('系统能力', this.capabilitySummary)
      }.width('100%')
        .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)

      SectionHeading({ title: '设备信息', trailing: this.deviceEntries.length + ' 项' })
      Column() {
        ForEach(this.deviceEntries, (entry: DeviceInfoEntry, index: number) => {
          this.fieldRow(entry.label, entry.value)
          if (index < this.deviceEntries.length - 1) { this.fieldDivider() }
        }, (entry: DeviceInfoEntry): string => entry.label)
      }.width('100%')
        .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)
        .accessibilityText('完整设备信息，共 ' + this.deviceEntries.length + ' 项')

      SectionHeading({ title: '本机数据' })
      Column() {
        this.fieldRow('角色', String(this.state.characters.length))
        this.fieldDivider()
        this.fieldRow('计划', String(this.state.projects.length))
        this.fieldDivider()
        this.fieldRow('活动', String(this.state.events.length))
        this.fieldDivider()
        this.fieldRow('装备', String(this.state.assets.length))
        this.fieldDivider()
        this.fieldRow('照片', String(this.state.photos.length))
      }.width('100%')
        .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 }).clip(true)

      Text('开发者选项只影响本机数据；再次进入可在设置页连点版本号五次。')
        .fontSize(12).fontColor(Theme.muted).width('100%').padding({ top: 6, left: 4, right: 4 })
        .accessibilityText('开发者选项只影响本机数据，再次进入可在设置页连点版本号五次')
      Blank().height(Theme.contentBottom).accessibilityLevel('no')
    }
    .width('100%').constraintSize({ maxWidth: READING_MAX_WIDTH })
    .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    .alignItems(HorizontalAlign.Start)
    .attributeModifier(this.entrance.group(1))
  }

  build() {
    Scroll(this.scroller) {
      this.content()
    }
    .id('developer-scroll').width('100%').height('100%').align(Alignment.Top)
    .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
    .accessibilityText('可滚动的开发者选项内容')
  }
}
