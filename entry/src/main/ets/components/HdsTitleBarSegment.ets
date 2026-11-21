import { ColorMetrics, LengthMetrics, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { HdsMiniBarButton } from './HdsMiniBarButton';

/** Dashboard 的标题栏分段。选中值通过数字属性接入 V2 页面状态。 */
@Component
export struct HdsTitleBarSegment {
    @Require items: SegmentButtonV2Items;
    @Prop componentId: string = 'secondary-segment';
    @Prop selectedIndex: number = 0;
    @Prop maxFontScale: number = 2;
    @Prop segmentHeight: number = 48;
    @Prop experimentalWidth: Length = '100%';
    @Prop experimentalHeight: number = 52;
    onSelectedIndexChanged?: (index: number) => void;
    onItemClicked?: (index: number) => void;
    @State private measuredWidth: number = 0;

    private materialSelectedBackgroundColor(): ColorMetrics {
        try {
            return ColorMetrics.resourceColor($r('app.color.segmented_color_selected'));
        } catch (error) {
            console.warn('[ElvaCos][HdsTitleBarSegment] 读取材质切换项背景色失败: ' + JSON.stringify(error));
            return ColorMetrics.rgba(102, 102, 102, 0.13);
        }
    }

    @Builder
    private segmentContent(): void {
        Column() {
            TabSegmentButtonV2({
                items: this.items,
                selectedIndex: this.selectedIndex,
                $selectedIndex: (index: number): void => {
                    this.onSelectedIndexChanged?.(index);
                },
                onItemClicked: this.onItemClicked,
                itemMaxFontScale: this.maxFontScale,
                itemSelectedBackgroundColor: this.materialSelectedBackgroundColor(),
                itemMinHeight: LengthMetrics.vp(32),
                buttonBackgroundColor: ColorMetrics.rgba(0, 0, 0, 0),
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
        .accessibilityText('当前显示' + (this.items[this.selectedIndex]?.text ?? '') + '，可切换页面')
    }
}
