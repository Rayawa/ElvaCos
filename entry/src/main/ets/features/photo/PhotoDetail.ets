import { ManagedImage } from '../../components/ManagedImage';
import { pageTransition, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { vibration } from '../../common/vibration';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { PhotoAsset, PHOTO_STATUSES, PHOTO_LABELS } from '../../model/Entities';
import { SectionHeading, EmptyState } from '../../components/Surfaces';

@ComponentV2
export struct PhotoDetail {
  @Param state: AppState = new AppState();
  @Param photo: PhotoAsset = new PhotoAsset();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local loadError: boolean = false;
  @Local animStep: number = 0;
  private enterTimers: number[] = [];
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 0; }
  @Monitor('photo')
  photoChanged(): void { this.loadError = false; }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Column({ space: 12 }) {
          if (this.photo.localPath && !this.loadError) { ManagedImage({ sourcePath: this.photo.localPath, label: this.state.projectName(this.photo.projectId) + '的照片', fit: ImageFit.Contain, ratio: 0, radius: 20, onFailure: (): void => { this.loadError = true; } }).width('100%').constraintSize({ maxHeight: 640 }) }
          else { EmptyState({ title: '原照片需要重新导入', message: '元数据保留了计划关联与选片状态。\n从原计划重新选择照片，可补回本地文件。', button: '从相册补回', action: () => this.state.importPhotos(this.photo.projectId) }) }
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
        Column({ space: Theme.sectionSpacing }) {
          SectionHeading({ title: '照片工作流' })
          Select(PHOTO_LABELS.map((label: string): SelectOption => { return { value: label }; })).value(PHOTO_LABELS[PHOTO_STATUSES.indexOf(this.photo.status)]).onSelect((i: number) => { vibration.dotVibration(); this.state.setPhotoStatus(this.photo, PHOTO_STATUSES[i]); }).accessibilityText('照片业务状态')
          Button('所属计划 · ' + this.state.projectName(this.photo.projectId)).width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).constraintSize({ minHeight: 52 })
            .onClick((): void => { vibration.dotVibration(); this.open('project', this.photo.projectId); })
            .accessibilityText('打开所属计划 ' + this.state.projectName(this.photo.projectId))
          Text('原始版本无损保留，不修改系统相册。').fontSize(12).fontColor(Theme.muted)
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
