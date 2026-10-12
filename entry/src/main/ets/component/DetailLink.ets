import { displayName } from '../common/format';
import { Theme } from '../common/Theme';
import { Icons } from '../common/Icons';

/** Quiet navigation row for secondary content, with a single title and optional subtitle. */
@ComponentV2
export struct DetailLink {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param value: string = '';
  @Param icon: Resource | undefined = undefined;
  @Param componentId: string = '';
  @Param interactive: boolean = true;
  @Event action: () => void = () => {};
  build() {
    Button() {
      Row({ space: 12 }) {
        if (this.icon) { Image(this.icon).width(22).height(22).fillColor(Theme.muted).accessibilityLevel('no') }
        Column({ space: 5 }) {
          Text(displayName(this.title)).fontSize(16).fontColor(Theme.ink).maxLines(2)
          if (this.subtitle) { Text(displayName(this.subtitle)).fontSize(13).fontColor(Theme.muted).maxLines(2) }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.value) { Text(this.value).fontSize(14).fontColor(Theme.muted).maxLines(1) }
        Image(Icons.chevronRight).width(14).height(14).fillColor(Theme.muted).accessibilityLevel('no')
      }.width('100%').padding({ top: 14, bottom: 14, left: 4, right: 4 })
    }.id(this.componentId).type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 56 })
      .backgroundColor(Color.Transparent).borderRadius(12).enabled(this.interactive).onClick((): void => { this.action(); })
      .accessibilityText(this.title + (this.subtitle ? '，' + this.subtitle : '') + (this.value ? '，' + this.value : ''))
  }
}
