import { ContextRow } from '../components/ContextRow';
import { AppState } from '../viewmodels/ApplicationState';
import { BackupObjectCount } from '../models/MetadataBackupPreview';
import { Theme } from '../ui/Theme';
import { formatTimestamp } from '../utils/format';
import { confirm } from '../ui/Confirm';
import { SheetHeader } from '../components/SheetHeader';
import { vibration } from '../ui/vibration';
import { scrollByAxis } from '../ui/scroll';
import { Icons } from '../ui/Icons';

@ComponentV2
export struct BackupRestoreSheet {
    private scroller: Scroller = new Scroller();
    @Require @Param state: AppState;
    @Event close: () => void = () => {};
    @Event done: () => void = () => {};
    @Local confirming: boolean = false;
    @Local error: string = '';
    private async replace(): Promise<void> {
        const preview = this.state.restorePreview;
        if (!preview || this.state.busy || this.confirming) {
            return;
        }
        this.confirming = true;
        try {
            if (!await confirm(this.getUIContext(), '最终确认替换？', '当前 ' + preview.currentCount + ' 条记录将由备份的 ' + preview.incomingCount + ' 条记录完整替换，不会合并。本地表单草稿将清理；照片文件未包含在 JSON 中。', '替换全部元数据', '保留当前数据')) {
                return;
            }
            this.error = '';
            if (await this.state.restoreData()) {
                vibration.dotVibration();
                this.done();
            } else {
                vibration.errorVibration();
                this.error = this.state.error || '未完成替换，当前记录保留。';
            }
        } finally {
            this.confirming = false;
        }
    }

    build() {
        Column() {
            Column({ space: 12 }) {
                SheetHeader({
                    title: '备份预览',
                    hint: '已校验，尚未替换当前记录',
                    haptic: this.state.settings.haptic,
                    hapticLevel: this.state.settings.hapticLevel,
                    close: (): void => {
                        if (!this.state.busy && !this.confirming) {
                            this.close();
                        }
                    }
                })
            }.padding({ left: 24, right: 24, top: 20, bottom: 12 }).width('100%')
            Scroll(this.scroller) {
                Column({ space: 14 }) {
                    if (this.state.restorePreview) {
                        Column({ space: 10 }) {
                            ContextRow({
                                label: '元数据 v' + this.state.restorePreview.version,
                                text: formatTimestamp(this.state.restorePreview.exportedAt)
                            })
                            Text('完整替换所有本地业务记录，不合并；设置与系统相册原图保留。本地表单草稿将清理。旧版本未包含的对象类型也会清空。')
                                .fontSize(13)
                                .lineHeight(20)
                                .fontColor(Theme.muted)
                            Text('JSON 不含照片文件。仅复用匹配的本机媒体路径；' + this.state.restorePreview.mediaWithoutLocalPath + ' 条图片记录没有可复用路径，恢复后需重新导入。现有路径对应的文件仍需打开时核对；照片版本的渲染图不恢复。活动提醒需在本机重新开启。')
                                .fontSize(13)
                                .lineHeight(20)
                                .fontColor(Theme.muted)
                        }.width('100%')
                            .alignItems(HorizontalAlign.Start)
                            .padding(16)
                            .backgroundColor(Theme.bg)
                            .borderRadius(Theme.cardRadius)
                            .border({ width: 1, color: Theme.line })

                        Column() {
                            Row() {
                                Text('对象').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.muted).layoutWeight(1)
                                Text('当前 → 备份').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.muted)
                            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })
                            ForEach(this.state.restorePreview.counts, (count: BackupObjectCount, index: number) => {
                                Column() {
                                    Divider().color(Theme.line)
                                    Row() {
                                        Text(count.label).fontSize(15).fontColor(Theme.ink).layoutWeight(1)
                                        Text(count.current + ' → ' + count.incoming)
                                            .fontSize(15)
                                            .fontWeight(FontWeight.Medium)
                                            .fontColor(Theme.ink)
                                    }.width('100%')
                                        .constraintSize({ minHeight: 42 })
                                        .padding({ left: 16, right: 16 })
                                        .accessibilityText(count.label + '，当前 ' + count.current + '，备份 ' + count.incoming)
                                }.width('100%')
                            }, (count: BackupObjectCount) => count.table)
                        }.width('100%')
                            .backgroundColor(Theme.bg)
                            .borderRadius(Theme.cardRadius)
                            .border({ width: 1, color: Theme.line })
                    }
                    Column({ space: 10 }) {
                        Button({ stateEffect: false }) {
                            Row({ space: 8 }) {
                                SymbolGlyph(Icons.share)
                                    .fontSize(16)
                                    .fontColor([Theme.ink])
                                Text('先导出当前元数据')
                                    .fontSize(15)
                                    .fontWeight(FontWeight.Medium)
                                    .fontColor(Theme.ink)
                            }.justifyContent(FlexAlign.Center)
                        }.id('backup-export-current')
                            .constraintSize({ minHeight: 48 })
                            .width('100%')
                            .backgroundColor(Theme.tint)
                            .borderRadius(Theme.controlRadius)
                            .border({ width: 1, color: Theme.line })
                            .enabled(!this.state.busy && !this.confirming)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.state.exportData();
                            })
                        Text(this.state.lastMetadataExport ? '最近成功导出：' + formatTimestamp(this.state.lastMetadataExport) + '（不含照片）' : '尚无成功导出记录')
                            .fontSize(13)
                            .fontColor(Theme.muted)
                    }.width('100%').alignItems(HorizontalAlign.Start)
                }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 24, right: 24, bottom: 20 })
            }.layoutWeight(1)
                .width('100%')
                .edgeEffect(EdgeEffect.Spring)
                .onAxisEvent((event: AxisEvent): void => {
                    scrollByAxis(this.scroller, event);
                })
            Column({ space: 10 }) {
                Divider().color(Theme.line)
                if (this.error || this.state.error) {
                    Text(this.error || this.state.error)
                        .id('backup-restore-error')
                        .fontSize(13)
                        .fontColor(Theme.danger)
                        .width('100%')
                        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                        .backgroundColor(Theme.dangerBg)
                        .borderRadius(Theme.controlRadius)
                }
                if (this.state.notice) {
                    Text(this.state.notice)
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .width('100%')
                        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                        .backgroundColor(Theme.noticeBg)
                        .borderRadius(Theme.controlRadius)
                }
                Button(this.state.busy ? '处理中…' : '替换全部元数据', { stateEffect: false })
                    .id('backup-replace')
                    .constraintSize({ minHeight: 52 })
                    .width('100%')
                    .borderRadius(Theme.controlRadius)
                    .enabled(!this.state.busy && !this.confirming && !!this.state.restorePreview && !this.state.staleScopes.length)
                    .backgroundColor(Theme.danger)
                    .fontColor(Theme.onAccent)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.replace();
                    })
            }.padding({ left: 24, right: 24, top: 10, bottom: 24 }).width('100%').backgroundColor(Theme.surface)
        }.width('100%').height('100%').backgroundColor(Theme.surface)
    }
}
