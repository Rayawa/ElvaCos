import { StatusPill } from './Surfaces';
import { displayName } from '../common/format';
import { ContextRow } from './ContextRow';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';

@ComponentV2
export struct PhotoImportStatus {
  @Require @Param state: AppState;
  @Param projectId: string = '';
  build() {
    if (this.state.photoImport.phase === 'completed' && (!this.projectId || this.projectId === this.state.photoImport.projectId)) {
      Column({ space: 10 }) {
        ContextRow({ label: '本次导入', text: displayName(this.state.projectName(this.state.photoImport.projectId)), prominent: true })
        Flex({ wrap: FlexWrap.Wrap }) {
          Row({ space: 6 }) { StatusPill({ label: '成功' }); Text(this.state.photoImport.succeeded + ' 张').fontSize(14).fontColor(Theme.muted) }.margin({ right: 12, bottom: 4 })
          if (this.state.photoImport.skipped) { Row({ space: 6 }) { StatusPill({ label: '重复' }); Text(this.state.photoImport.skipped + ' 张').fontSize(14).fontColor(Theme.muted) }.margin({ right: 12, bottom: 4 }) }
          if (this.state.photoImport.failures.length) { Row({ space: 6 }) { StatusPill({ label: '失败' }); Text(this.state.photoImport.failures.length + ' 张').fontSize(14).fontColor(Theme.muted) }.margin({ right: 12, bottom: 4 }) }
          if (this.state.photoImport.cancelled) { Row({ space: 6 }) { StatusPill({ label: '未处理' }); Text(this.state.photoImport.cancelled + ' 张').fontSize(14).fontColor(Theme.muted) }.margin({ right: 12, bottom: 4 }) }
        }.width('100%').accessibilityText(this.state.photoImport.summary())
        if (this.state.photoImport.failures.length) {
          Text(this.state.photoImport.failures[0].message).fontSize(14).fontColor(Theme.danger)
          Text('重试只处理失败项；系统授权失效时请重新选择照片。').fontSize(14).fontColor(Theme.muted)
          Button('重试失败 ' + this.state.photoImport.failures.length + ' 张').constraintSize({ minHeight: 48 }).width('100%')
            .enabled(!this.state.busy && !this.state.staleScopes.length).onClick((): void => { void this.state.retryPhotoImport(); })
          Button('重新选择照片').constraintSize({ minHeight: 48 }).width('100%').enabled(!this.state.busy && !this.state.staleScopes.length)
            .onClick((): void => { void this.state.importPhotos(this.state.photoImport.projectId); })
        }
        Button('关闭导入结果').constraintSize({ minHeight: 48 }).onClick((): void => { this.state.photoImport.clear(); })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Theme.tint).borderRadius(Theme.cardRadius)
    }
  }
}
