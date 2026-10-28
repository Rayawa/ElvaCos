import { ContextRow } from '../common/ContextRow';
import { AppState } from '../../state/ApplicationState';
import { BackupObjectCount } from '../../models/MetadataBackupPreview';
import { Theme } from '../../ui/theme/Theme';
import { formatTimestamp } from '../../utils/format/format';
import { confirm } from '../../ui/feedback/Confirm';
import { SheetHeader } from '../common/SheetHeader';

@ComponentV2
export struct BackupRestoreSheet {
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
                this.done();
            } else {
                this.error = this.state.error || '未完成替换，当前记录保留。';
            }
        } finally {
            this.confirming = false;
        }
    }

    build() {
        Column({ space: 16 }) {
            SheetHeader({ title: '备份预览', hint: '已校验，尚未替换当前记录', close: (): void => {
                    if (!this.state.busy && !this.confirming) {
                        this.close();
                    }
                }
            })
            Scroll() {
                Column({ space: 14 }) {
                    if (this.state.restorePreview) {
                        ContextRow({ label: '元数据 v' + this.state.restorePreview.version, text: formatTimestamp(this.state.restorePreview.exportedAt) })
                        Text('完整替换所有本地业务记录，不合并；设置与系统相册原图保留。本地表单草稿将清理。旧版本未包含的对象类型也会清空。').fontSize(14).fontColor(Theme.muted)
                        Text('JSON 不含照片文件。仅复用匹配的本机媒体路径；' + this.state.restorePreview.mediaWithoutLocalPath + ' 条图片记录没有可复用路径，恢复后需重新导入。现有路径对应的文件仍需打开时核对；照片版本的渲染图不恢复。活动提醒需在本机重新开启。')
                            .fontSize(14)
                            .fontColor(Theme.muted)
                        Row() {
                            Text('对象').layoutWeight(1)
                            Text('当前 → 备份').fontColor(Theme.muted)
                        }.width('100%')
                        ForEach(this.state.restorePreview.counts, (count: BackupObjectCount) => {
                            Row() {
                                Text(count.label).layoutWeight(1)
                                Text(count.current + ' → ' + count.incoming)
                            }.width('100%').constraintSize({ minHeight: 36 }).accessibilityText(count.label + '，当前 ' + count.current + '，备份 ' + count.incoming)
                        }, (count: BackupObjectCount) => count.table)
                    }
                    Button('先导出当前元数据').id('backup-export-current').constraintSize({ minHeight: 48 }).width('100%')
                        .enabled(!this.state.busy && !this.confirming).onClick((): void => {
                            this.state.exportData();
                        })
                    Text(this.state.lastMetadataExport ? '最近成功导出：' + formatTimestamp(this.state.lastMetadataExport) + '（不含照片）' : '尚无成功导出记录')
                        .fontSize(14)
                        .fontColor(Theme.muted)
                }.width('100%').alignItems(HorizontalAlign.Start)
            }.layoutWeight(1).width('100%')
            if (this.error || this.state.error) {
                Text(this.error || this.state.error).id('backup-restore-error').fontSize(14).fontColor(Theme.danger)
            }
            if (this.state.notice) {
                Text(this.state.notice).fontSize(14).fontColor(Theme.muted)
            }
            Button(this.state.busy ? '处理中…' : '替换全部元数据').id('backup-replace').constraintSize({ minHeight: 52 }).width('100%')
                .enabled(!this.state.busy && !this.confirming && !!this.state.restorePreview && !this.state.staleScopes.length)
                .backgroundColor(Theme.danger).fontColor(Theme.onAccent).onClick((): void => {
                    this.replace();
                })
        }.padding(24).width('100%').height('100%').backgroundColor(Theme.surface)
    }
}
