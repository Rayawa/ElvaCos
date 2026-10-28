import { handleSheetBack } from '../../ui/sheet/sheet';
import { SUPPORTS_API_26 } from '../../config/platformCompatibility';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { Theme } from '../../ui/theme/Theme';
import { StaggerEntrance } from '../../ui/animation/motion';

@ComponentV2
export struct DetailDestination {
    @Param active: boolean = true;
    @Monitor('active')
    private activeChanged(): void {
        this.foreground = this.active;
        if (this.active) { this.prepareEntrance(); this.showEntrance(); }
        else { this.releaseEntrance(); }
    }
    @Param titleOptions: HdsNavigationTitleBarOptions = {};
    @Event back: () => void = () => {};
    @Event hidden: () => void = () => {};
    @Event shown: () => void = () => {};
    @BuilderParam content: (entrance: StaggerEntrance) => void = this.emptyContent;
    @Local foreground: boolean = true;
    @Local entrance: StaggerEntrance = new StaggerEntrance();
    @Builder emptyContent(entrance: StaggerEntrance) {
        Blank()
    }

    aboutToAppear(): void {
        this.entrance.managed = true;
    }

    aboutToDisappear(): void {
        this.releaseEntrance();
    }

    private prepareEntrance(): void {
        this.entrance.reset();
    }

    private showEntrance(): void {
        this.entrance.play(this.getUIContext());
    }

    private releaseEntrance(): void {
        this.entrance.reset();
    }
    // Native chrome floats over the full body. The caller avoids the system status area once.

    private safeTitleOptions(): HdsNavigationTitleBarOptions {
        const options: HdsNavigationTitleBarOptions = { padding: this.titleOptions.padding, style: this.titleOptions.style, content: this.titleOptions.content,
            enableHoverMode: this.titleOptions.enableHoverMode, avoidLayoutSafeArea: this.titleOptions.avoidLayoutSafeArea };
        if (SUPPORTS_API_26) {
            options.enableComponentSafeArea = false;
        }
        return options;
    }

    onBackPress(): boolean {
        if (handleSheetBack()) { return true; }
        this.back();
        return true;
    }

    build() {
        HdsNavDestination() {
            Column() {
                if (this.foreground) {
                    this.content(this.entrance)
                }
            }.width('100%').height('100%').attributeModifier(this.entrance.group(1))
        }.titleBar(this.safeTitleOptions()).titleMode(HdsNavDestinationTitleMode.MINI)
            .hideTitleBar(false)
            .hideToolBar(true).backgroundColor(Theme.bg)
            .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
            .onWillShow((): void => {
                this.foreground = true;
                this.prepareEntrance();
            })
            .onShown((): void => {
                this.showEntrance();
                this.shown();
            })
            .onHidden((): void => {
                this.releaseEntrance();
                this.foreground = false;
                this.hidden();
            })
            .onBackPressed((): boolean => {
                return this.onBackPress();
            })
    }
}
