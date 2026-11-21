import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { ReferenceImage } from '../models/Planning';
import { ManagedImage } from '../components/ManagedImage';
import { DetailLink } from '../components/DetailLink';
import { StaggerEntrance } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';

@ComponentV2
export struct ReferenceDetail {
    @Event open: (kind: string, id: string) => void = () => {};
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    private scroller: Scroller = new Scroller();

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
        Scroll(this.scroller) {
            Column({ space: Theme.sectionSpacing }) {
                Blank().height(Theme.detailTop).width('100%')
                Column() {
                    ManagedImage({
                        large: true,
                        sourcePath: this.reference.localPath,
                        label: this.reference.caption || '准备参考图',
                        ratio: 0,
                        fit: ImageFit.Contain,
                        radius: Theme.cardRadius,
                    }).width('100%').constraintSize({ maxHeight: 700 })
                }.width('100%')
                    .padding(8)
                    .backgroundColor(Theme.surface)
                    .borderRadius(Theme.heroRadius)
                    .border({ width: 0.8, color: Theme.line })
                    .shadow({ radius: 10, color: Theme.shadow, offsetX: 0, offsetY: 3 })
                    .attributeModifier(this.entrance.group(1))
                Column({ space: 12 }) {
                    Column() {
                        DetailLink({
                            componentId: 'reference-owner-open',
                            title: this.reference.projectId ? '所属计划' : '所属角色',
                            value: this.reference.projectId ? this.state.projectName(this.reference.projectId) : this.state.characterName(this.reference.characterId),
                            icon: this.reference.projectId ? Icons.plan : Icons.tabProfile,
                            action: (): void => {
                                this.open(this.reference.projectId ? 'project' : 'character', this.reference.projectId || this.reference.characterId);
                            },
                        })
                    }.padding({ left: 12, right: 12 })
                        .width('100%')
                        .backgroundColor(Theme.surface)
                        .borderRadius(Theme.cardRadius)
                        .border({ width: 0.8, color: Theme.line })
                        .shadow({ radius: 6, color: Theme.shadow, offsetX: 0, offsetY: 2 })
                    if (this.reference.caption) {
                        Text(this.reference.caption)
                            .fontSize(14)
                            .fontColor(Theme.ink)
                            .padding(14)
                            .width('100%')
                            .backgroundColor(Theme.surface)
                            .borderRadius(Theme.cardRadius)
                            .border({ width: 0.8, color: Theme.line })
                    }
                    if (!this.reference.localPath) {
                        Text('元数据中保留了这张参考图。请回到所属计划或角色，重新选择同一张图片恢复本机副本。')
                            .fontColor(Theme.muted)
                            .fontSize(13)
                            .padding(14)
                            .width('100%')
                            .backgroundColor(Theme.tint)
                            .borderRadius(Theme.cardRadius)
                    }
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
                    .attributeModifier(this.entrance.group(2))
                Blank().height(Theme.detailBottom).width('100%')
            }.width('100%')
                .constraintSize({ maxWidth: Theme.readingMaxWidth })
                .alignItems(HorizontalAlign.Start)
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        }.id('reference-detail-scroll')
            .width('100%')
            .height('100%')
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
