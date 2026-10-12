import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';
import { SheetHeader } from './SheetHeader';
import { DetailLink } from './DetailLink';

/** The system navigation panel owns map discovery and selection. No provider URI or fake coordinates. */
@ComponentV2
export struct LocationSheet {
  @Param city: string = '';
  @Param venue: string = '';
  @Param writable: boolean = true;
  @Event close: () => void = () => {};
  @Event editLocation: () => void = () => {};
  @Local mapError: string = '';
  @Local copyMessage: string = '';
  @Local opening: boolean = false;
  private address(): string { return [this.city.trim(), this.venue.trim()].filter((value: string) => Boolean(value)).join(' '); }
  private async showMaps(): Promise<void> {
    if (this.opening || !this.address()) { return; }
    this.mapError = ''; this.opening = true;
    const callback: common.AbilityStartCallback = {
      onError: (): void => { this.opening = false; this.mapError = '地图无法打开，可复制地址后手动搜索。'; },
      onResult: (): void => { this.opening = false; },
    };
    try {
      // API 11+, official navigation / PlaceSearch contract. The panel determines available applications.
      await (this.getUIContext().getHostContext() as common.UIAbilityContext).startAbilityByType('navigation',
        { sceneType: 3, destinationName: this.address() }, callback);
    } catch (error) { this.mapError = '地图选择窗口无法打开，可重试或复制地址。'; }
    finally { this.opening = false; }
  }
  private async copyAddress(): Promise<void> {
    this.copyMessage = '';
    try { await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.address())); this.copyMessage = '地址已复制'; }
    catch (error) { this.mapError = '复制失败，可长按地址复制。'; }
  }
  build() {
    Column({ space: 20 }) {
      SheetHeader({ title: '活动地点', close: this.close })
      Scroll() {
        Column({ space: 20 }) {
          Row({ space: 16 }) {
            Image(Icons.location).width(40).height(40).fillColor(Theme.accent).accessibilityLevel('no')
            Column({ space: 8 }) {
              Text(this.venue || this.city || '尚未添加地点').fontSize(24).fontWeight(FontWeight.Medium).fontColor(Theme.ink).copyOption(CopyOptions.LocalDevice)
              if (this.venue && this.city) { Text(this.city).fontSize(15).fontColor(Theme.muted).copyOption(CopyOptions.LocalDevice) }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.padding(20).width('100%').backgroundColor(Theme.tint).borderRadius(Theme.cardRadius)
          Button(this.opening ? '正在打开…' : '查看地图').id('location-map-open').width('100%').constraintSize({ minHeight: 56 })
            .backgroundColor(Theme.brand).fontColor(Theme.onAccent).enabled(Boolean(this.address()) && !this.opening).onClick((): void => { void this.showMaps(); })
          if (this.mapError) { Text(this.mapError).id('location-map-error').fontSize(14).fontColor(Theme.danger).accessibilityText(this.mapError) }
          Column() {
            DetailLink({ title: '复制地址', subtitle: this.copyMessage, icon: Icons.location, interactive: Boolean(this.address()), componentId: 'location-copy-address', action: (): void => { void this.copyAddress(); } })
            Divider().color(Theme.line)
            DetailLink({ title: this.address() ? '编辑地点' : '添加地点', icon: Icons.edit, interactive: this.writable, action: this.editLocation })
          }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.bg).borderRadius(Theme.cardRadius)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
}
