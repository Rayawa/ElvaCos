import { util } from '@kit.ArkTS';
import { DocumentBlock, parseLocalDocument } from '../../common/LocalDocument';
import { PRIVACY_RAWFILE, READING_MAX_WIDTH } from '../../common/constants';
import { Theme } from '../../common/Theme';
import { StaggerEntrance } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { EmptyState } from '../../component/Surfaces';

/** 与 Dashboard LocalHtmlPage 相同的本地文档边界；遵循本工程原生 UI 约定。 */
@ComponentV2
export struct LocalHtmlPage {
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Local blocks: DocumentBlock[] = [];
  @Local loading: boolean = true;
  @Local error: string = '';
  private scroller: Scroller = new Scroller();
  private revision: number = 0;
  private loadTimer: number = -1;

  aboutToAppear(): void {
    this.loadTimer = setTimeout((): void => { this.loadTimer = -1; this.load(); }, 0);
  }

  aboutToDisappear(): void {
    this.revision++;
    if (this.loadTimer >= 0) { clearTimeout(this.loadTimer); this.loadTimer = -1; }
  }

  private async load(): Promise<void> {
    const revision = ++this.revision;
    this.loading = true;
    this.error = '';
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) { throw new Error('文档上下文不可用'); }
      const content = await context.resourceManager.getRawFileContent(PRIVACY_RAWFILE);
      const blocks = parseLocalDocument(new util.TextDecoder('utf-8', { fatal: true }).decodeToString(content));
      if (blocks.length === 0) { throw new Error('隐私政策正文为空'); }
      if (revision === this.revision) { this.blocks = blocks; }
    } catch (error) {
      if (revision === this.revision) { this.error = '隐私政策暂时无法加载，请重试'; }
    } finally {
      if (revision === this.revision) { this.loading = false; }
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Blank().height(Theme.detailTop).accessibilityLevel('no')
        if (this.loading) {
          LoadingProgress().width(36).height(36).color(Theme.brand).accessibilityText('正在加载隐私政策')
        } else if (this.error) {
          EmptyState({ title: '文档加载失败', message: this.error, button: '重试', action: (): void => { this.load(); } })
        } else {
          ForEach(this.blocks, (block: DocumentBlock, index: number) => {
            Text(block.text)
              .id('privacy-paragraph-' + index)
              .fontSize(block.heading ? 18 : 15)
              .fontWeight(block.heading ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(block.heading ? Theme.accent : Theme.ink)
              .lineHeight(block.heading ? 28 : 26)
              .width('100%')
              .copyOption(CopyOptions.InApp)
              .accessibilityText(block.text)
              .accessibilityLevel('yes')
          }, (_block: DocumentBlock, index: number): string => index.toString())
        }
        Blank().height(Theme.contentBottom).accessibilityLevel('no')
      }.width('100%').constraintSize({ maxWidth: READING_MAX_WIDTH })
        .alignItems(HorizontalAlign.Start)
        .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
        .attributeModifier(this.entrance.group(1))
    }.id('privacy-scroll').width('100%').height('100%').align(Alignment.Top)
      .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
      .backgroundColor(Theme.bg)
  }
}
