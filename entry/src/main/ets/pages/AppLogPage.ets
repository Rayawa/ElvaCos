import { ContextRow } from '../components/ContextRow';
import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit';
import { APP_LOG, READING_MAX_WIDTH } from '../models/constants';
import { ReleaseNote, ReleaseType } from '../models/types';
import { Icons } from '../ui/Icons';
import { Theme } from '../ui/Theme';
import { SystemCapability } from '../ui/SystemCapability';
import { StaggerEntrance } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { showToastSafely } from '../ui/safeUi';
import { vibration } from '../ui/vibration';
import { DetailDestination } from '../components/DetailDestination';
import { EmptyState } from '../components/Surfaces';

@ComponentV2
export struct AppLogPage {
    @Param effects: boolean = true;
    @Param materialLevel: number = 1;
    @Event back: () => void = () => {};
    @Local showBeta: boolean = true;
    @Local showRc: boolean = true;
    @Local showRelease: boolean = true;
    private scroller: Scroller = new Scroller();
    @Computed
    get filteredLogs(): ReleaseNote[] {
        return APP_LOG.filter((release: ReleaseNote): boolean => {
            if (release.type === 'beta') {
                return this.showBeta;
            }
            if (release.type === 'rc') {
                return this.showRc;
            }
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
                    action: (): void => {
                        this.toggleFilter(type);
                    },
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
                        .backgroundColor(Theme.releaseBadge).borderRadius(Theme.badgeRadius).margin({ left: 8 })
                        .accessibilityText('正式发布版本')
                }
            }.width('100%')
            ContextRow({ label: '构建 ' + release.buildNumber, text: release.date })
                .accessibilityText(release.date + '，构建号 ' + release.buildNumber)
            ForEach(release.changes, (change: string) => {
                Row({ space: 8 }) {
                    Circle({ width: 5, height: 5 })
                        .fill(Theme.accent)
                        .margin({ top: 7 })
                        .accessibilityLevel('no')
                    Text(change).fontSize(15).fontColor(Theme.ink).layoutWeight(1)
                        .accessibilityText(change).copyOption(CopyOptions.InApp)
                }.width('100%').alignItems(VerticalAlign.Top)
            }, (change: string): string => change)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            .border({ width: 0.8, color: Theme.line })
            .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })
    }

    @LocalBuilder
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
                Blank().height(Theme.detailBottom).accessibilityLevel('no')
            }.width('90%').constraintSize({ maxWidth: READING_MAX_WIDTH })
                .alignItems(HorizontalAlign.Start)
                .attributeModifier(entrance.group(1))
        }.id('app-log-scroll').width('100%').height('100%').align(Alignment.Top)
            .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
            .backgroundColor(Theme.bg).accessibilityText('可滚动的应用更新日志')
    }

    build() {
        DetailDestination({
            titleOptions: SystemCapability.titleBar('更新日志', this.effects, this.materialLevel,
                undefined, this.menus(), false, this.back, 3),
            back: this.back,
            content: this.logContent,
        })
    }
}
