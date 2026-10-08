import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';

@ComponentV2
export struct PhotoImportStatus {
  @Require @Param state: AppState;
  @Param projectId: string = '';
  build() {
    if (this.state.photoImport.phase === 'completed' && (!this.projectId || this.projectId === this.state.photoImport.projectId)) {
      Column({ space: 10 }) {
        Text('本次导入 · ' + this.state.projectName(this.state.photoImport.projectId)).fontSize(16).fontColor(Theme.ink)
        Text(this.state.photoImport.summary()).fontSize(14).fontColor(Theme.muted).accessibilityText(this.state.photoImport.summary())
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
