import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { SheetHeader } from '../components/SheetHeader';
import { DetailLink } from '../components/DetailLink';

/** 系统导航面板负责地图发现与路线选择。 */
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

    private address(): string {
        return [this.city.trim(), this.venue.trim()].filter((value: string) => Boolean(value)).join(' ');
    }

    private async showMaps(): Promise<void> {
        if (this.opening || !this.address()) {
            return;
        }
        vibration.dotVibration();
        this.mapError = '';
        this.opening = true;
        const callback: common.AbilityStartCallback = {
            onError: (): void => {
                this.opening = false;
                vibration.errorVibration();
                this.mapError = '地图无法打开，可复制地址后手动搜索。';
            },
            onResult: (): void => {
                this.opening = false;
            },
        };
        try {
            // API 11+, official navigation / PlaceSearch contract. The panel determines available applications.
            await (this.getUIContext().getHostContext() as common.UIAbilityContext).startAbilityByType('navigation',
                { sceneType: 3, destinationName: this.address() }, callback);
        } catch (error) {
            vibration.errorVibration();
            this.mapError = '地图选择窗口无法打开，可重试或复制地址。';
        } finally {
            this.opening = false;
        }
    }

    private async copyAddress(): Promise<void> {
        vibration.dotVibration();
        this.copyMessage = '';
        try {
            await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.address()));
            this.copyMessage = '地址已复制';
        } catch (error) {
            vibration.errorVibration();
            this.mapError = '复制失败，可长按地址复制。';
        }
    }

    build() {
        Column({ space: 18 }) {
            SheetHeader({ title: '活动地点', close: this.close })
            Scroll() {
                Column({ space: 18 }) {
                    Row({ space: 14 }) {
                        Stack({ alignContent: Alignment.Center }) {
                            SymbolGlyph(Icons.location)
                                .fontSize(24)
                                .fontColor([Theme.accent])
                                .accessibilityLevel('no')
                        }.width(48)
                            .height(48)
                            .borderRadius(Theme.controlRadius)
                            .backgroundColor(Theme.surface)
                            .border({ width: 0.8, color: Theme.line })
                        Column({ space: 6 }) {
                            Text(this.venue || this.city || '尚未添加地点')
                                .fontSize(22)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(Theme.ink)
                                .copyOption(CopyOptions.LocalDevice)
                            if (this.venue && this.city) {
                                Text(this.city)
                                    .fontSize(14)
                                    .fontColor(Theme.muted)
                                    .copyOption(CopyOptions.LocalDevice)
                            }
                        }.layoutWeight(1)
                            .alignItems(HorizontalAlign.Start)
                    }.padding(18)
                        .width('100%')
                        .backgroundColor(Theme.tint)
                        .borderRadius(Theme.cardRadius)
                        .border({ width: 0.8, color: Theme.line })
                    Button(this.opening ? '正在打开…' : '查看地图', { type: ButtonType.Normal, stateEffect: false })
                        .id('location-map-open')
                        .width('100%')
                        .constraintSize({ minHeight: 50 })
                        .borderRadius(Theme.controlRadius)
                        .backgroundColor(Theme.brand)
                        .fontColor(Theme.onAccent)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .enabled(Boolean(this.address()) && !this.opening)
                        .onClick((): void => {
                            void this.showMaps();
                        })
                    if (this.mapError) {
                        Text(this.mapError)
                            .id('location-map-error')
                            .fontSize(13)
                            .fontColor(Theme.danger)
                            .accessibilityText(this.mapError)
                    }
                    Column() {
                        DetailLink({
                            title: '复制地址',
                            subtitle: this.copyMessage,
                            icon: Icons.location,
                            interactive: Boolean(this.address()),
                            componentId: 'location-copy-address',
                            action: (): void => {
                                void this.copyAddress();
                            },
                        })
                        Divider().color(Theme.groupDivider)
                        DetailLink({
                            title: this.address() ? '编辑地点' : '添加地点',
                            icon: Icons.edit,
                            interactive: this.writable,
                            action: this.editLocation,
                        })
                    }.padding({ left: 12, right: 12 })
                        .width('100%')
                        .backgroundColor(Theme.bg)
                        .borderRadius(Theme.cardRadius)
                        .border({ width: 0.8, color: Theme.line })
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
            }.layoutWeight(1)
                .width('100%')
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .align(Alignment.Top)
        }.padding(Theme.pagePadding)
            .width('100%')
            .height('100%')
            .backgroundColor(Theme.surface)
    }
}
