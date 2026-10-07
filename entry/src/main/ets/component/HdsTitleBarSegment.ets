import { ColorMetrics, LengthMetrics, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { HdsMiniBarButton } from './HdsMiniBarButton';

/** HdsTabs 页内的原生二级分段按钮，复用 Dashboard 材质与反馈。 */
@ComponentV2
export struct HdsTitleBarSegment {
  @Param componentId: string = 'secondary-segment';
  @Param items: SegmentButtonV2Items = new SegmentButtonV2Items([]);
  @Param selectedIndexes: number[] = [0];
  @Param maxFontScale: number = 2;
  @Param segmentHeight: number = 48;
  @Param experimentalWidth: Length = '100%';
  @Param experimentalHeight: number = 52;
  @Event onSelectedIndexChanged: (index: number) => void = () => {};
  @Event onItemClicked: (index: number) => void = () => {};
  @Local private measuredWidth: number = 0;

  private selectedIndex(): number {
    return this.selectedIndexes.length > 0 ? this.selectedIndexes[0] : 0;
  }

  private materialSelectedBackgroundColor(): ColorMetrics {
    try {
      return ColorMetrics.resourceColor(Theme.segmentedSelected);
    } catch (error) {
      console.warn('[ElvaCos][component/HdsTitleBarSegment][WARN]',
        `读取材质切换项背景色失败: ${JSON.stringify(error)}`);
      return ColorMetrics.resourceColor(Theme.surface);
    }
  }

  @Builder
  private segmentContent(): void {
    Column() {
      TabSegmentButtonV2({
        items: this.items,
        selectedIndex: this.selectedIndex(),
        $selectedIndex: (index: number): void => {
          this.onSelectedIndexChanged(index);
        },
        onItemClicked: this.onItemClicked,
        itemMaxFontScale: this.maxFontScale,
        itemSelectedBackgroundColor: this.materialSelectedBackgroundColor(),
        itemMinHeight: LengthMetrics.vp(32),
        buttonBackgroundColor: ColorMetrics.resourceColor(Theme.transparent),
        // 材质统一由外层迷你栏提供，与参考项目的透明背景分支保持一致。
        buttonBackgroundBlurStyle: BlurStyle.NONE,
        buttonMinHeight: LengthMetrics.vp(40),
        buttonPadding: LengthMetrics.vp(4),
        enableStateAnimation: true,
      })
    }
    .width('100%')
    .height(this.segmentHeight)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.measuredWidth > 0) {
        HdsMiniBarButton({
          barWidth: this.measuredWidth,
          barHeight: this.experimentalHeight,
        }) {
          this.segmentContent()
        }
      }
    }
    .id(this.componentId)
    .width(this.experimentalWidth)
    .height(this.experimentalHeight)
    .onAreaChange((_, area) => {
      if (typeof area.width === 'number' && area.width > 0 && this.measuredWidth !== area.width) {
        this.measuredWidth = area.width;
      }
    })
    .margin({ top: -8 })
    .accessibilityText(this.selectedIndex() === 0 ?
      '当前显示' + String(this.items[0]?.text || '视图') + '，可切换页面内容' : '当前显示' + String(this.items[this.selectedIndex()]?.text || '视图') + '，可切换页面内容')
  }
}
