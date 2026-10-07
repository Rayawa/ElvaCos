import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { ReferenceImage } from '../../model/Planning';
import { ManagedImage } from '../../components/ManagedImage';
import { FactRow } from '../../components/Surfaces';
import { pageTransition } from '../../common/motion';

@ComponentV2
export struct ReferenceDetail {
  @Param state: AppState = new AppState();
  @Param reference: ReferenceImage = new ReferenceImage();
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        ManagedImage({ sourcePath: this.reference.localPath, label: this.reference.caption || '准备参考图', ratio: 0.8, radius: Theme.cardRadius }).width('100%').aspectRatio(0.8)
        FactRow({ label: this.reference.projectId ? '所属计划' : '所属角色', value: this.reference.projectId ? this.state.projectName(this.reference.projectId) : this.state.characterName(this.reference.characterId) })
        if (this.reference.caption) { Text(this.reference.caption).fontSize(15).fontColor(Theme.ink) }
        if (!this.reference.localPath) { Text('元数据中保留了这张参考图。请回到所属计划或角色，重新选择同一张图片恢复本机副本。').fontColor(Theme.muted).fontSize(13) }
        Blank().height(Theme.contentBottom).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off).transition(pageTransition())
  }
}
