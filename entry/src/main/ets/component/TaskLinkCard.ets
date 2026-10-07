import { Icons } from '../common/Icons';
import { Theme } from '../common/Theme';
import { InteractiveCard } from './Surfaces';

/** 待办入口复用统一卡片反馈；任务状态与路由仍由页面负责。 */
@ComponentV2
export struct TaskLinkCard {
  @Param title: string = '';
  @Param detail: string = '';
  @Param label: string = '';
  @Param hint: string = '';
  @Param effects: boolean = true;
  @Event action: () => void = () => {};

  @Builder body() {
    Row({ space: 12 }) {
      SymbolGlyph(Icons.pending).fontSize(20).fontColor([Theme.accent]).accessibilityLevel('no')
      Column({ space: 4 }) {
        Text(this.title).fontSize(15).fontColor(Theme.ink)
        Text(this.detail).fontSize(12).fontColor(Theme.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Image(Icons.chevronRight).width(16).height(16).objectFit(ImageFit.Contain)
        .opacity(0.55).accessibilityLevel('no')
    }.width('100%')
  }

  build() {
    InteractiveCard({
      label: this.label || this.title, hint: this.hint, effects: this.effects,
      action: (): void => { this.action(); }, content: (): void => { this.body(); },
    })
  }
}
