import { AppState } from '../common/AppState';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { ReferenceImage } from '../model/Planning';
import { ManagedImage } from './ManagedImage';
import { SectionHeading } from './Surfaces';

@ComponentV2
export struct ReferenceGallery {
  @Param state: AppState = new AppState();
  @Param images: ReferenceImage[] = [];
  @Event add: () => void = () => {};
  @Event open: (id: string) => void = () => {};
  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        SectionHeading({ title: '参考图片', trailing: this.images.length + ' 张' }).layoutWeight(1)
        Button('＋ 添加图片').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.add(); })
      }.width('100%')
      if (this.images.length === 0) { Text('添加角色设定、妆容或姿势参考，准备时随时查看。').fontSize(13).fontColor(Theme.muted) }
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.images, (r: ReferenceImage) => {
            Button() {
              Column({ space: 6 }) {
                ManagedImage({ sourcePath: r.thumbnailPath, label: r.caption || '准备参考图', ratio: 1, radius: 16 }).width(128).height(128)
                Text(r.caption || (r.localPath ? '查看参考图' : '图片缺失 · 重新导入')).fontSize(12).fontColor(Theme.muted).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.width(128)
            }.type(ButtonType.Normal).backgroundColor(Color.Transparent).onClick((): void => { vibration.dotVibration(); this.open(r.id); }).accessibilityText(r.caption || '打开准备参考图')
          }, (r: ReferenceImage) => r.id)
        }.alignItems(VerticalAlign.Top)
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
