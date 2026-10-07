import { STORAGE_KEY_VIBRATION_LEVEL, STORAGE_KEY_IMMERSIVE_MATERIAL_LEVEL, STORAGE_KEY_USERNAME } from '../common/constants';
import { Icons } from '../common/Icons';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { common } from '@kit.AbilityKit';
import { getDeviceName, setImmersiveMaterialLevel, setUsername, setVibrationLevel } from '../common/storage';
import { MediaRepository } from '../data/media/MediaRepository';
import { formatBytes } from '../common/format';
import { showToastSafely } from '../common/safeUi';
import { SUPPORTS_HARMONY_API_23 } from '../common/constants';
import { HdsListItemCard, IconSize, PrefixIcon } from '@kit.UIDesignKit';
import { LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN, LIST_ITEM_PREFIX_MARGIN, LIST_ITEM_SUFFIX_MARGIN } from '../common/constants';

@Component
struct UsernameEditor {
    @Prop @Watch('onInitialUsernameChanged') initialUsername: string = '';
    @Prop narrow: boolean = false;
    onCommit?: (value: string) => void;
    @StorageLink(STORAGE_KEY_VIBRATION_LEVEL) vibrationLevel: number = 1;
    @State private draftUsername: string = '';
    @State private showHelp: boolean = false;
    private editing: boolean = false;
    private lastCommittedUsername: string = '';

    aboutToAppear(): void {
        this.draftUsername = this.initialUsername;
        this.lastCommittedUsername = this.initialUsername.trim();
    }

    aboutToDisappear(): void {
        this.commitDraft();
    }

    private onInitialUsernameChanged(): void {
        if (this.editing) return;
        this.draftUsername = this.initialUsername;
        this.lastCommittedUsername = this.initialUsername.trim();
    }

    private commitDraft(): void {
        const username = this.draftUsername.trim();
        if (this.draftUsername !== username) this.draftUsername = username;
        if (username === this.lastCommittedUsername) return;
        this.lastCommittedUsername = username;
        if (this.onCommit) this.onCommit(username);
    }

    build() {
        Flex({
            wrap: FlexWrap.Wrap,
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center
        }) {
            Text('用户名')
                .fontSize(16)
                .fontColor(Theme.ink)
                .maxLines(2)
                .accessibilityText('用户名')

            Row({ space: 8 }) {
                TextInput({
                    text: this.draftUsername,
                    placeholder: getDeviceName()
                })
                    .layoutWeight(1)
                    .constraintSize({ minWidth: 120 })
                    .height(40)
                    .enableKeyboardOnFocus(false)
                    .backgroundColor(Theme.tint)
                    .onChange((value: string): void => {
                        this.draftUsername = value;
                    })
                    .onEditChange((isEditing: boolean): void => {
                        this.editing = isEditing;
                        if (!isEditing) this.commitDraft();
                    })
                    .onSubmit((): void => this.commitDraft())
                    .accessibilityText(
                        `用户名输入框，当前用户名为${this.draftUsername || getDeviceName()}`
                    )

                Image(Icons.help)
                    .height(22)
                    .width(22)
                    .objectFit(ImageFit.Contain)

                    .onClick((): void => {
                        if (this.vibrationLevel > 0) vibration.dotVibration();
                        this.showHelp = !this.showHelp;
                    })
                    .bindPopup(this.showHelp, {
                        message: '用户名只保存在本机；留空时显示为设备名称',
                        onStateChange: (event): void => {
                            if (!event.isVisible) this.showHelp = false;
                        },
                    })
                    .accessibilityText('查看用户名说明')
            }
            .width(this.narrow ? '100%' : 204)
            .margin({ top: this.narrow ? 4 : 0 })
        }
        .padding({ right: 7 })
        .width('100%')
        .accessibilityGroup(true)
        .accessibilityText(`用户名设置，当前${this.draftUsername || getDeviceName()}`)
    }
}

@Component
export struct SettingsPanel {
    @BuilderParam additionalSettings: () => void = this.emptySettings;
    @Builder private emptySettings() {}
    onSettingsChanged?: () => void;
    @Prop @Watch('onActiveChanged') active: boolean = false;
    @StorageLink(STORAGE_KEY_VIBRATION_LEVEL) vibrationLevel: number = 1;
    @StorageLink(STORAGE_KEY_IMMERSIVE_MATERIAL_LEVEL) @Watch('materialLevelChanged') immersiveMaterialLevel: number = 1;
    @StorageLink(STORAGE_KEY_USERNAME) username: string = '';
    // 材质档位在界面上是反向的（流畅在左，精美在右），用镜像值做 $$ 双向绑定，
    // 保证拖动时滑块连续跟随手指，松手才提交 —— 与振动强度滑块的写法一致。
    @State private materialSliderValue: number = 1;

    @State handlePopupTrash: boolean = false;
    @State cacheSize: string = '计算中…';
    @State private contentWidth: number = 0;
    private readonly vibrationSupported: boolean = vibration.isSupported();
    private cacheSizeTimer: number = -1;
    private cacheRevision: number = 0;
    private visible: boolean = false;

    private vibrationPrefixItem: PrefixIcon = new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: { image: Icons.vibration },
    });

    private materialPrefixItem: PrefixIcon = new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: { image: Icons.material },
    });

    private usernamePrefixItem: PrefixIcon = new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: { image: Icons.user },
    });

    private trashPrefixItem: PrefixIcon = new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: { image: Icons.trash },
    });

    private onActiveChanged(): void {
        this.syncMaterialSlider();
        if (this.active) this.scheduleCacheSizeRefresh();
    }

    private syncMaterialSlider(): void {
        const mirrored = 2 - this.immersiveMaterialLevel;
        if (this.materialSliderValue !== mirrored) this.materialSliderValue = mirrored;
    }

    private materialLevelChanged(): void {
        this.syncMaterialSlider();
    }

    private scheduleCacheSizeRefresh(): void {
        if (!this.visible || !this.active) { return; }
        const revision = ++this.cacheRevision;
        if (this.cacheSizeTimer >= 0) clearTimeout(this.cacheSizeTimer);
        this.cacheSizeTimer = setTimeout(async (): Promise<void> => {
            this.cacheSizeTimer = -1;
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            try {
                const size = formatBytes(await new MediaRepository(context).cacheSize());
                if (revision === this.cacheRevision) { this.cacheSize = size; }
            } catch (error) { if (revision === this.cacheRevision) { this.cacheSize = '暂不可用'; } }
        }, 0);
    }

    aboutToDisappear(): void {
        this.visible = false;
        this.cacheRevision++;
        if (this.cacheSizeTimer >= 0) {
            clearTimeout(this.cacheSizeTimer);
            this.cacheSizeTimer = -1;
        }
    }

    private persistUsername(username: string): void {
        setUsername(username).then((): void => { if (this.onSettingsChanged) this.onSettingsChanged(); }).catch((error: Error) => {
            console.error('[ElvaCos][component/SettingsPanel][ERROR]',
                `保存用户名失败: ${error.message}`);
            showToastSafely(this.getUIContext().getPromptAction(), '保存用户名失败，请重试');
        });
    }

    private trash(): void {
        const uiContent = this.getUIContext();
        const prompt = uiContent.getPromptAction();

        try {
            uiContent.showAlertDialog({
                message: '将仅清除应用临时缓存。角色、项目、原图、缩略图、用户名和设置都会保留。',
                primaryButton: {
                    value: '取消',
                    action: () => {
                        if (this.vibrationLevel > 0) {
                            vibration.dotVibration();
                        }
                    }
                },
                secondaryButton: {
                    value: '继续',
                    action: async () => {
                        if (this.vibrationLevel > 0) {
                            vibration.dotVibration();
                        }
                        const context =
                            this.getUIContext().getHostContext() as common.UIAbilityContext;

                        try {
                            await new MediaRepository(context).clearCache();

                            showToastSafely(
                                prompt,
                                '缓存已完全清除',
                                1800,
                                'Settings'
                            );
                        } catch (error) {
                            console.error(
                                '[ElvaCos][component/SettingsPanel][ERROR]',
                                `清除缓存失败: ${JSON.stringify(error)}`
                            );

                            showToastSafely(
                                prompt,
                                '部分缓存文件正在使用，请稍后重试',
                                2190,
                                'Settings'
                            );
                        }

                        this.scheduleCacheSizeRefresh();
                    },
                },
            });
        } catch (error) {
            console.error(
                '[ElvaCos][component/SettingsPanel][ERROR]',
                `清除缓存确认窗口显示失败: ${JSON.stringify(error)}`
            );

            showToastSafely(
                prompt,
                '暂时无法打开清除缓存窗口，请稍后重试',
                1900,
                'Settings'
            );
        }
    }

    build() {
        Column() {
            this.usernameItem()

            Divider()
                .color(Theme.divider)
                .strokeWidth(0.5)
                .margin({
                    left: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                    right: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                })

            if (this.vibrationSupported) {
                this.vibrationLevelItem()

                Divider()
                    .color(Theme.divider)
                    .strokeWidth(0.5)
                    .margin({
                        left: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                        right: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                    })
            }

            if (SUPPORTS_HARMONY_API_23) {
                Divider()
                    .color(Theme.divider)
                    .strokeWidth(0.5)
                    .margin({
                        left: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                        right: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                    })

                this.materialLevelItem()
            }

            Divider()
                .color(Theme.divider)
                .strokeWidth(0.5)
                .margin({
                    left: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                    right: LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN,
                })

            this.additionalSettings()
            this.trashItem()
        }
        .width('100%')
        .backgroundColor(Theme.surface)
        .borderRadius(16)
        .shadow({
            radius: 8,
            color: Theme.shadow,
            offsetY: 2
        })
        .clip(true)
        .onAppear((): void => {
            this.visible = true;
            this.syncMaterialSlider();
            if (this.active) this.scheduleCacheSizeRefresh();
        })
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
            this.contentWidth = Number(newValue.width);
        })
        .accessibilityGroup(true)
        .accessibilityText('应用设置')
    }

    private isNarrowSettings(): boolean {
        return this.contentWidth > 0 && this.contentWidth < 330;
    }

    private vibrationLevelName(): string {
        if (this.vibrationLevel === 0) {
            return '关闭';
        }

        if (this.vibrationLevel === 1) {
            return '灵动';
        }

        return '硬朗';
    }

    @Builder
    private vibrationLevelItem(): void {
        HdsListItemCard({
            prefixItem: this.vibrationPrefixItem,
            textItem: {
                customBuilder: () => {
                    this.vibrationLevelContent()
                },
            },
            cardHeight: this.isNarrowSettings() ? 116 : 68,
            cardBackgroundColor: Theme.surface,
            cardBorderRadius: 0,
            hoverBorderRadius: 12,
            cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
            cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
            accessibilityOptions: {
                accessibilityText:
                `振动强度设置`,
            },
        })
    }

    @Builder
    private vibrationLevelContent(): void {
        Flex({
            wrap: FlexWrap.Wrap,
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center
        }) {
            Text('振动强度')
                .fontSize(16)
                .fontColor(Theme.ink)
                .maxLines(2)
                .accessibilityText('振动强度')

            Column({ space: 1 }) {
                Slider({
                    value: $$this.vibrationLevel,
                    min: 0,
                    max: 2,
                    step: 1,
                    style: SliderStyle.InSet,
                })
                    .width(190)
                    .selectedColor(Theme.brand)
                    .trackColor(Theme.tint)
                    .blockBorderColor(Theme.surface)
                    .showSteps(true)
                    .showTips(false)
                    .onChange((value: number, mode: SliderChangeMode) => {
                        const nextLevel = Math.round(value);

                        if (mode === SliderChangeMode.Click ||
                            mode === SliderChangeMode.End) {
                            vibration.dotVibration();

                            setVibrationLevel(nextLevel).then((): void => { if (this.onSettingsChanged) this.onSettingsChanged(); }).catch((error: Error) => {
                                console.error(
                                    '[ElvaCos][component/SettingsPanel][ERROR]',
                                    `保存振动强度失败: ${error.message}`
                                );
                                showToastSafely(this.getUIContext().getPromptAction(), '保存设置失败，请重试');
                            });
                        }
                    })
                    .accessibilityText(
                        `振动强度，当前${this.vibrationLevelName()}，共三档`
                    )

                Row() {
                    this.vibrationLevelLabel('关闭', 0)
                    this.vibrationLevelLabel('灵动', 1)
                    this.vibrationLevelLabel('硬朗', 2)
                }
                .width(190)
                .justifyContent(FlexAlign.SpaceBetween)
            }
            .width(190)
            .margin({
                top: this.isNarrowSettings() ? 4 : 0
            })
        }
        .width('100%')
        .padding({ right: 2 })
        .accessibilityGroup(true)
        .accessibilityText(
            `振动强度，当前${this.vibrationLevelName()}`
        )
    }

    @Builder
    private vibrationLevelLabel(label: string, level: number): void {
        Text(label)
            .fontSize(12)
            .fontWeight(
                this.vibrationLevel === level ?
                    FontWeight.Medium :
                    FontWeight.Regular
            )
            .fontColor(
                this.vibrationLevel === level ?
                    Theme.accent :
                    Theme.muted
            )
            .width(40)
            .textAlign(TextAlign.Center)
            .accessibilityText(
                `${label}振动${this.vibrationLevel === level ? '，已选择' : ''}`
            )
    }

    private materialLevelName(): string {
        if (this.immersiveMaterialLevel === 2) {
            return '流畅';
        }

        if (this.immersiveMaterialLevel === 1) {
            return '轻柔';
        }

        return '精美';
    }

    @Builder
    private materialLevelItem(): void {
        HdsListItemCard({
            prefixItem: this.materialPrefixItem,
            textItem: {
                customBuilder: () => {
                    this.materialLevelContent()
                },
            },
            cardHeight: this.isNarrowSettings() ? 116 : 68,
            cardBackgroundColor: Theme.surface,
            cardBorderRadius: 0,
            hoverBorderRadius: 12,
            cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
            cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
            accessibilityOptions: {
                accessibilityText:
                `材质等级设置`,
            },
        })
    }

    @Builder
    private materialLevelContent(): void {
        Flex({
            wrap: FlexWrap.Wrap,
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center
        }) {
            Text('材质等级')
                .fontSize(16)
                .fontColor(Theme.ink)
                .maxLines(2)
                .accessibilityText('材质等级')

            Column({ space: 1 }) {
                Slider({
                    value: $$this.materialSliderValue,
                    min: 0,
                    max: 2,
                    step: 1,
                    style: SliderStyle.InSet,
                })
                    .width(190)
                    .selectedColor(Theme.brand)
                    .trackColor(Theme.tint)
                    .blockBorderColor(Theme.surface)
                    .showSteps(true)
                    .showTips(false)
                    .onChange((value: number, mode: SliderChangeMode) => {
                        const nextLevel = 2 - Math.round(value);

                        if (mode === SliderChangeMode.Click ||
                            mode === SliderChangeMode.End) {
                            this.immersiveMaterialLevel = nextLevel;
                            this.materialSliderValue = 2 - nextLevel;

                            vibration.dotVibration();

                            setImmersiveMaterialLevel(nextLevel)
                              .then((): void => { if (this.onSettingsChanged) this.onSettingsChanged(); })
                              .catch((error: Error) => {
                                console.error(
                                    '[ElvaCos][component/SettingsPanel][ERROR]',
                                    `保存材质等级失败: ${error.message}`
                                );
                                showToastSafely(this.getUIContext().getPromptAction(), '保存设置失败，请重试');
                            });
                        }
                    })
                    .accessibilityText(
                        `材质等级，当前${this.materialLevelName()}，共三档`
                    )

                Row() {
                    this.materialLevelLabel('流畅', 2)
                    this.materialLevelLabel('轻柔', 1)
                    this.materialLevelLabel('精美', 0)
                }
                .width(190)
                .justifyContent(FlexAlign.SpaceBetween)
            }
            .width(190)
            .margin({
                top: this.isNarrowSettings() ? 4 : 0
            })
        }
        .width('100%')
        .padding({ right: 2 })
        .accessibilityGroup(true)
        .accessibilityText(
            `材质等级，当前${this.materialLevelName()}`
        )
    }

    @Builder
    private materialLevelLabel(label: string, level: number): void {
        Text(label)
            .fontSize(12)
            .fontWeight(
                this.immersiveMaterialLevel === level ?
                    FontWeight.Medium :
                    FontWeight.Regular
            )
            .fontColor(
                this.immersiveMaterialLevel === level ?
                    Theme.accent :
                    Theme.muted
            )
            .width(40)
            .textAlign(TextAlign.Center)
            .accessibilityText(
                `${label}材质${
                this.immersiveMaterialLevel === level ?
                    '，已选择' :
                    ''
                }`
            )
    }

    @Builder
    private usernameItem(): void {
        HdsListItemCard({
            prefixItem: this.usernamePrefixItem,
            textItem: {
                customBuilder: () => {
                    this.usernameContent()
                },
            },
            cardHeight: this.isNarrowSettings() ? 108 : 68,
            cardBackgroundColor: Theme.surface,
            cardBorderRadius: 0,
            hoverBorderRadius: 12,
            cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
            cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
            accessibilityOptions: {
                accessibilityText:
                `用户名设置，当前${this.username || getDeviceName()}`,
            },
        })
    }

    @Builder
    private usernameContent(): void {
        UsernameEditor({
            initialUsername: this.username,
            narrow: this.isNarrowSettings(),
            onCommit: (value: string): void => this.persistUsername(value),
        })
    }

    @Builder
    private trashItem(): void {
        HdsListItemCard({
            prefixItem: this.trashPrefixItem,
            textItem: {
                customBuilder: () => {
                    this.trashContent()
                },
            },
            onClick: () => {
                vibration.dotVibration();
                this.trash();
            },
            cardHeight: 52,
            cardBackgroundColor: Theme.surface,
            cardBorderRadius: 0,
            hoverBorderRadius: 12,
            cardPrefixMargin: LIST_ITEM_PREFIX_MARGIN,
            cardSuffixMargin: LIST_ITEM_SUFFIX_MARGIN,
            accessibilityOptions: {
                accessibilityText:
                `清除缓存，当前缓存文件总大小：${this.cacheSize}`,
            },
        })
    }

    @Builder
    private trashContent(): void {
        Flex({
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center
        }) {
            Text('清除缓存')
                .fontSize(16)
                .fontColor(Theme.ink)
                .accessibilityText('清除缓存')

            Row({ space: 8 }) {
                Text(`缓存文件总大小：${this.cacheSize}`)
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .accessibilityText(
                        `缓存文件总大小${this.cacheSize}`
                    )

                Image(Icons.help)
                    .height(24)
                    .width(24)
                    .objectFit(ImageFit.Contain)
                    .accessibilityText('查看清除缓存说明')

                    .onClick(() => {
                        if (this.vibrationLevel > 0) {
                            vibration.dotVibration();
                        }

                        this.handlePopupTrash =
                            !this.handlePopupTrash;
                    })
                    .monopolizeEvents(true)
                    .bindPopup(this.handlePopupTrash, {
                        message:
                        '仅清除临时缓存；业务记录、原图、缩略图和设置不会被删除',
                        onStateChange: (event) => {
                            if (!event.isVisible) {
                                this.handlePopupTrash = false;
                            }
                        }
                    })
            }
        }
        .width('100%')
        .padding({ right: 7 })
        .accessibilityGroup(true)
        .accessibilityText(
            `清除缓存，当前缓存文件总大小${this.cacheSize}`
        )
    }
}
