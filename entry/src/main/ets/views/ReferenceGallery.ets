import { PressFeedback } from '../ui/pressFeedback';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { ReferenceImage } from '../models/Planning';
import { ManagedImage } from '../components/ManagedImage';
import { SectionHeading } from '../components/Surfaces';

@ComponentV2
export struct ReferenceGallery {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Require @Param state: AppState;
    @Param images: ReferenceImage[] = [];
    @Event add: () => void = () => {};
    @Event open: (id: string) => void = () => {};

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Column({ space: 12 }) {
            Row({ space: 8 }) {
                SectionHeading({ title: '参考图片', icon: Icons.importPhoto, trailing: this.images.length + ' 张' }).layoutWeight(1)
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('添加图片').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                    }.padding({ left: 12, right: 12 })
                }.accessibilityText('添加图片')
                    .height(36)
                    .borderRadius(Theme.controlRadius)
                    .backgroundColor(Theme.tint)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.add();
                    })
                    .visualEffect(this.feedback.effect('button-1', false))
                    .compositingFilter(this.feedback.filter('button-1', false))
                    .attributeModifier(this.feedback.control('button-1', false))
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            if (this.images.length === 0) {
                Text('添加角色设定、妆容或姿势参考，准备时随时查看。')
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .padding(14)
                    .width('100%')
                    .backgroundColor(Theme.tint)
                    .borderRadius(Theme.cardRadius)
            }
            Scroll() {
                Row({ space: 12 }) {
                    ForEach(this.images, (r: ReferenceImage) => {
                        Button({ type: ButtonType.Normal, stateEffect: false }) {
                            Column({ space: 6 }) {
                                ManagedImage({ sourcePath: r.thumbnailPath, label: r.caption || '准备参考图', ratio: 1, radius: Theme.slotRadius })
                                    .width(124)
                                    .height(124)
                                Text(r.caption || (r.localPath ? '查看参考图' : '图片缺失，请重新导入'))
                                    .fontSize(12)
                                    .fontColor(Theme.muted)
                                    .maxLines(2)
                                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                            }.width(124)
                                .padding(6)
                                .backgroundColor(Theme.surface)
                                .borderRadius(Theme.cardRadius)
                                .border({ width: 0.8, color: Theme.line })
                        }.id('reference-thumbnail:' + r.id)
                            .backgroundColor(Theme.transparent)
                            .borderRadius(Theme.cardRadius)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.open(r.id);
                            })
                            .accessibilityText(r.caption || '打开准备参考图')
                            .visualEffect(this.feedback.effect('button-2:' + r.id, true))
                            .compositingFilter(this.feedback.filter('button-2:' + r.id, true))
                            .attributeModifier(this.feedback.control('button-2:' + r.id, true))
                    }, (r: ReferenceImage) => r.id)
                }.alignItems(VerticalAlign.Top)
            }.scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .width('100%')
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }
}
