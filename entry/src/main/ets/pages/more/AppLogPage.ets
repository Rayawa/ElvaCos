import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit';
import { APP_LOG, READING_MAX_WIDTH } from '../../common/constants';
import { ReleaseNote, ReleaseType } from '../../common/types';
import { Icons } from '../../common/Icons';
import { Theme } from '../../common/Theme';
import { SystemCapability } from '../../common/SystemCapability';
import { PressFeedback } from '../../common/pressFeedback';
import { StaggerEntrance } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { showToastSafely } from '../../common/safeUi';
import { vibration } from '../../common/vibration';
import { DetailDestination } from '../../component/DetailDestination';
import { EmptyState } from '../../component/Surfaces';

@ComponentV2
export struct AppLogPage {
  @Param effects: boolean = true;
  @Param materialLevel: number = 1;
  @Event back: () => void = () => {};
  @Local showBeta: boolean = true;
  @Local showRc: boolean = true;
  @Local showRelease: boolean = true;
  private scroller: Scroller = new Scroller();
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());

  @Computed
  get filteredLogs(): ReleaseNote[] {
    return APP_LOG.filter((release: ReleaseNote): boolean => {
      if (release.type === 'beta') { return this.showBeta; }
      if (release.type === 'rc') { return this.showRc; }
      return this.showRelease;
    });
  }

  private toggleFilter(type: ReleaseType): void {
    let enabled: boolean;
    let name: string;
    if (type === 'beta') {
      this.showBeta = !this.showBeta;
      enabled = this.showBeta;
      name = 'Beta版本';
    } else if (type === 'rc') {
      this.showRc = !this.showRc;
      enabled = this.showRc;
      name = 'ReleaseCandidate版本';
    } else {
      this.showRelease = !this.showRelease;
      enabled = this.showRelease;
      name = '正式版';
    }
    vibration.dotVibration();
    showToastSafely(this.getUIContext().getPromptAction(), (enabled ? '打开' : '关闭') + name + '日志', 500, 'AppLog');
  }

  private filterMenu(type: ReleaseType, label: string, enabled: boolean,
    enabledIcon: Resource, disabledIcon: Resource): HdsNavigationMenuItemOptions {
    return {
      content: {
        label: label + (enabled ? '，已显示' : '，已隐藏'),
        icon: enabled ? enabledIcon : disabledIcon,
        isEnabled: true,
        componentId: 'app-log-filter-' + type,
        action: (): void => { this.toggleFilter(type); },
      },
    };
  }

  private menus(): HdsNavigationMenuItemOptions[] {
    return [
      this.filterMenu('beta', '筛选Beta日志', this.showBeta, Icons.betaOn, Icons.beta),
      this.filterMenu('rc', '筛选RC日志', this.showRc, Icons.rcOn, Icons.rc),
      this.filterMenu('release', '筛选正式版日志', this.showRelease, Icons.releaseOn, Icons.release),
    ];
  }

  @Builder
  private logCard(release: ReleaseNote): void {
    Column({ space: 12 }) {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        Text(release.version)
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
          .accessibilityText('版本 ' + release.version)
        if (release.type === 'release') {
          Text('正式版').fontSize(12).fontColor(Theme.surface)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(Theme.releaseBadge).borderRadius(6).margin({ left: 8 })
            .accessibilityText('正式发布版本')
        }
      }.width('100%')
      Text(release.date + ' · 构建号 ' + release.buildNumber)
        .fontSize(13).fontColor(Theme.muted).width('100%')
        .accessibilityText(release.date + '，构建号 ' + release.buildNumber)
      ForEach(release.changes, (change: string) => {
        Row({ space: 5 }) {
          Text('•').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.muted)
            .accessibilityLevel('no')
          Text(change).fontSize(15).fontColor(Theme.ink).layoutWeight(1)
            .accessibilityText(change).copyOption(CopyOptions.InApp)
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (change: string): string => change)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
      .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
      .visualEffect(this.feedback.effect('release-' + release.version, true))
      .compositingFilter(this.feedback.filter('release-' + release.version, true))
      .attributeModifier(this.feedback.control('release-' + release.version, true))
  }

  @Builder
  private logContent(entrance: StaggerEntrance): void {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).accessibilityLevel('no')
        ForEach(this.filteredLogs, (release: ReleaseNote) => {
          this.logCard(release)
        }, (release: ReleaseNote): string => release.version)
        if (this.filteredLogs.length === 0) {
          EmptyState({ title: '暂无符合条件的日志', message: '可在标题栏开启需要查看的发布类型' })
        }
        Blank().height(Theme.contentBottom).accessibilityLevel('no')
      }.width('90%').constraintSize({ maxWidth: READING_MAX_WIDTH })
        .alignItems(HorizontalAlign.Start)
        .attributeModifier(entrance.group(1))
    }.id('app-log-scroll').width('100%').height('100%').align(Alignment.Top)
      .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
      .backgroundColor(Theme.bg).accessibilityText('可滚动的应用更新日志')
  }

  build() {
    DetailDestination({
      titleOptions: SystemCapability.titleBar('更新日志', this.effects, this.materialLevel,
        undefined, this.menus(), false, this.back),
      back: this.back,
      content: this.logContent.bind(this),
    })
  }
}
