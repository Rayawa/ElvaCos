import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { ReferenceImage } from '../../models/Planning';
import { ManagedImage } from '../../components/common/ManagedImage';
import { DetailLink } from '../../components/common/DetailLink';
import { pageTransition, StaggerEntrance } from '../../ui/animation/motion';

@ComponentV2
export struct ReferenceDetail {
    @Event open: (kind: string, id: string) => void = () => {};
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    aboutToAppear(): void {
        if (!this.entrance.managed) {
            this.entrance.play(this.getUIContext());
        }
    }

    aboutToDisappear(): void {
        if (!this.entrance.managed) {
            this.entrance.reset();
        }
    }

    @Require @Param state: AppState;
    @Param reference: ReferenceImage = new ReferenceImage();
    build() {
        Scroll() {
            Column({ space: Theme.sectionSpacing }) {
                Blank().height(Theme.detailTop).width('100%')
                ManagedImage({
                    large: true,
                    sourcePath: this.reference.localPath,
                    label: this.reference.caption || '准备参考图',
                    ratio: 0,
                    fit: ImageFit.Contain,
                    radius: Theme.cardRadius
                }).width('100%').constraintSize({ maxHeight: 720 }).attributeModifier(this.entrance.group(1))
                Column({ space: 12 }) {
                    DetailLink({
                        title: this.reference.projectId ? '所属计划' : '所属角色',
                        value: this.reference.projectId ? this.state.projectName(this.reference.projectId) : this.state.characterName(this.reference.characterId),
                        action: (): void => { this.open(this.reference.projectId ? 'project' : 'character', this.reference.projectId || this.reference.characterId); }
                    })
                    if (this.reference.caption) {
                        Text(this.reference.caption).fontSize(15).fontColor(Theme.ink)
                    }
                    if (!this.reference.localPath) {
                        Text('元数据中保留了这张参考图。请回到所属计划或角色，重新选择同一张图片恢复本机副本。').fontColor(Theme.muted).fontSize(13)
                    }
                }.width('100%').alignItems(HorizontalAlign.Start).attributeModifier(this.entrance.group(2))
                Blank().height(Theme.detailBottom).width('100%')
            }.width('100%')
                .constraintSize({ maxWidth: Theme.readingMaxWidth })
                .alignItems(HorizontalAlign.Start)
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off).transition(pageTransition())
    }
}
