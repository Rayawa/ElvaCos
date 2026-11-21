import { StatusPill } from '../components/Surfaces';
import { displayName } from '../utils/format';
import { ContextRow } from '../components/ContextRow';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';

@ComponentV2
export struct PhotoImportStatus {
    @Require @Param state: AppState;
    @Param projectId: string = '';

    build() {
        if (this.state.photoImport.phase === 'completed' && (!this.projectId || this.projectId === this.state.photoImport.projectId)) {
            Column({ space: 10 }) {
                ContextRow({
                    label: '本次导入',
                    text: displayName(this.state.projectName(this.state.photoImport.projectId)),
                    tone: 'brand',
                    prominent: true,
                })
                Flex({ wrap: FlexWrap.Wrap }) {
                    Row({ space: 6 }) {
                        StatusPill({ label: '成功', tone: 'success', compact: true })
                        Text(this.state.photoImport.succeeded + ' 张').fontSize(13).fontColor(Theme.muted)
                    }.margin({ right: 12, bottom: 4 })
                    if (this.state.photoImport.skipped) {
                        Row({ space: 6 }) {
                            StatusPill({ label: '重复', tone: 'neutral', compact: true })
                            Text(this.state.photoImport.skipped + ' 张').fontSize(13).fontColor(Theme.muted)
                        }.margin({ right: 12, bottom: 4 })
                    }
                    if (this.state.photoImport.failures.length) {
                        Row({ space: 6 }) {
                            StatusPill({ label: '失败', tone: 'danger', compact: true })
                            Text(this.state.photoImport.failures.length + ' 张').fontSize(13).fontColor(Theme.muted)
                        }.margin({ right: 12, bottom: 4 })
                    }
                    if (this.state.photoImport.cancelled) {
                        Row({ space: 6 }) {
                            StatusPill({ label: '未处理', tone: 'warning', compact: true })
                            Text(this.state.photoImport.cancelled + ' 张').fontSize(13).fontColor(Theme.muted)
                        }.margin({ right: 12, bottom: 4 })
                    }
                }.width('100%')
                    .accessibilityText(this.state.photoImport.summary())
                if (this.state.photoImport.failures.length) {
                    Text(this.state.photoImport.failures[0].message)
                        .fontSize(13)
                        .fontColor(Theme.danger)
                    Text('重试只处理失败项；系统授权失效时请重新选择照片。')
                        .fontSize(12)
                        .fontColor(Theme.muted)
                    Button('重试失败 ' + this.state.photoImport.failures.length + ' 张', { type: ButtonType.Normal, stateEffect: false })
                        .constraintSize({ minHeight: 42 })
                        .width('100%')
                        .borderRadius(Theme.controlRadius)
                        .backgroundColor(Theme.brand)
                        .fontColor(Theme.onAccent)
                        .enabled(!this.state.busy && !this.state.staleScopes.length)
                        .onClick((): void => {
                            vibration.dotVibration();
                            void this.state.retryPhotoImport();
                        })
                    Button('重新选择照片', { type: ButtonType.Normal, stateEffect: false })
                        .constraintSize({ minHeight: 42 })
                        .width('100%')
                        .borderRadius(Theme.controlRadius)
                        .backgroundColor(Theme.surface)
                        .border({ width: 0.8, color: Theme.line })
                        .fontColor(Theme.ink)
                        .enabled(!this.state.busy && !this.state.staleScopes.length)
                        .onClick((): void => {
                            vibration.dotVibration();
                            void this.state.importPhotos(this.state.photoImport.projectId);
                        })
                }
                Button('关闭导入结果', { type: ButtonType.Normal, stateEffect: false })
                    .constraintSize({ minHeight: 38 })
                    .borderRadius(Theme.controlRadius)
                    .backgroundColor(Theme.surface)
                    .border({ width: 0.8, color: Theme.line })
                    .fontColor(Theme.muted)
                    .fontSize(13)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.state.photoImport.clear();
                    })
            }.width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(14)
                .backgroundColor(Theme.surface)
                .borderRadius(Theme.cardRadius)
                .border({ width: 0.8, color: Theme.line })
                .shadow({ radius: 8, color: Theme.shadow, offsetX: 0, offsetY: 2 })
        }
    }
}
