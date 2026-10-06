import { ManagedImage } from '../../components/ManagedImage';
import { pageTransition } from '../../common/motion';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { PhotoAsset, PHOTO_STATUSES, PHOTO_LABELS } from '../../model/Entities';
import { EmptyState } from '../../components/Surfaces';

@ComponentV2
export struct PhotoDetail {
  @Param state: AppState = new AppState();
  @Param photo: PhotoAsset = new PhotoAsset();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local loadError: boolean = false;
  @Monitor('photo')
  photoChanged(): void { this.loadError = false; }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.contentTop).width('100%')
        if (this.photo.localPath && !this.loadError) { ManagedImage({ sourcePath: this.photo.localPath, label: this.state.projectName(this.photo.projectId) + '的照片', fit: ImageFit.Contain, ratio: 0, radius: 20, onFailure: (): void => { this.loadError = true; } }).width('100%').constraintSize({ maxHeight: 640 }) }
        else { EmptyState({ title: '原照片需要重新导入', message: '元数据保留了计划关联与选片状态。\n从原计划重新选择照片，可补回本地文件。', button: '从相册补回', action: () => this.state.importPhotos(this.photo.projectId) }) }
        Text('照片工作流').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        Select(PHOTO_LABELS.map((label: string): SelectOption => { return { value: label }; })).value(PHOTO_LABELS[PHOTO_STATUSES.indexOf(this.photo.status)]).onSelect((i: number) => this.state.setPhotoStatus(this.photo, PHOTO_STATUSES[i])).accessibilityText('照片业务状态')
        Text('选片、待修图、最终作品分别记录；原图始终保留。').fontSize(13).fontColor(Theme.muted)
        Button('所属计划 · ' + this.state.projectName(this.photo.projectId)).width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => this.open('project', this.photo.projectId))
        Text('原始版本 · 无损保留\n首版仅管理照片流程，不修改系统相册，也不覆盖原图。').fontSize(12).fontColor(Theme.muted)
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
