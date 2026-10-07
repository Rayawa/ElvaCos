import { APP_LOG, APP_BUILD_NUMBER, READING_MAX_WIDTH } from '../../common/constants';
import { ReleaseNote } from '../../common/types';
import { Theme } from '../../common/Theme';
import { StaggerEntrance } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';

@ComponentV2
export struct AppLogPage {
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  private scroller: Scroller = new Scroller();

  build() {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).accessibilityLevel('no')
        ForEach(APP_LOG, (release: ReleaseNote) => {
          Column({ space: 12 }) {
            Text(release.version).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.accent)
              .width('100%').accessibilityText('版本 ' + release.version)
            Text(release.date + ' · 构建号 ' + APP_BUILD_NUMBER).fontSize(13).fontColor(Theme.muted)
              .width('100%').accessibilityText(release.date + '，构建号 ' + APP_BUILD_NUMBER)
            ForEach(release.changes, (change: string) => {
              Text('• ' + change).fontSize(15).fontColor(Theme.ink).lineHeight(26).width('100%')
                .accessibilityText(change).copyOption(CopyOptions.InApp)
            }, (change: string): string => change)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
            .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
        }, (release: ReleaseNote): string => release.version)
        Blank().height(Theme.contentBottom).accessibilityLevel('no')
      }.width('100%').constraintSize({ maxWidth: READING_MAX_WIDTH })
        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        .attributeModifier(this.entrance.group(1))
    }.id('app-log-scroll').width('100%').height('100%').align(Alignment.Top)
      .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
      .backgroundColor(Theme.bg)
  }
}
