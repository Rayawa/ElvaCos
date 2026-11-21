import { ASSET_STATUSES, ASSET_STATUS_LABELS, ASSET_TYPES, ASSET_TYPE_LABELS } from '../models/constants';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { EditDraft, FormIssue } from '../viewmodels/EditDraft';
import { AssetType, AssetStatus } from '../models/Entities';
import { Field } from './Surfaces';

@ComponentV2
export struct AssetFields {
    @Require @Param state: AppState;
    @Require @Param draft: EditDraft;
    @Param issues: FormIssue[] = [];
    @Event area: (field: string, area: Area) => void = () => {};
    @Event focused: (field: string) => void = () => {};

    private issue(field: string): string {
        return this.issues.find((issue: FormIssue) => issue.field === field)?.message || '';
    }

    build() {
        Column({ space: Theme.fieldSpacing }) {
            if (this.draft.parentId && !this.draft.id) {
                Text('保存后自动加入「' + this.state.projectName(this.draft.parentId) + '」和打包清单')
                    .fontSize(13)
                    .fontColor(Theme.accent)
                    .width('100%')
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor(Theme.noticeBg)
                    .borderRadius(Theme.controlRadius)
            }
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                Column({ space: 8 }) {
                    Text('类型').fontSize(13).fontColor(Theme.muted)
                    Select(ASSET_TYPE_LABELS.map((label: string): SelectOption => {
                        return { value: label };
                    }))
                        .value(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.draft.type as AssetType)])
                        .onSelect((index: number) => {
                            vibration.dotVibration();
                            this.draft.type = ASSET_TYPES[index];
                        })
                        .accessibilityText('装备类型')
                        .width('100%')
                        .constraintSize({ minHeight: Theme.controlHeight })
                        .backgroundColor(Theme.tint)
                        .borderRadius(12)
                        .border({ width: 1, color: Theme.line })
                        .font({ size: 15, weight: FontWeight.Medium })
                        .fontColor(Theme.ink)
                }.width('48%').constraintSize({ minWidth: 140 }).alignItems(HorizontalAlign.Start)
                Column({ space: 8 }) {
                    Text('状态').fontSize(13).fontColor(Theme.muted)
                    Select(ASSET_STATUS_LABELS.map((label: string): SelectOption => {
                        return { value: label };
                    }))
                        .value(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.draft.status as AssetStatus)])
                        .onSelect((index: number) => {
                            vibration.dotVibration();
                            this.draft.status = ASSET_STATUSES[index];
                        })
                        .accessibilityText('装备状态')
                        .width('100%')
                        .constraintSize({ minHeight: Theme.controlHeight })
                        .backgroundColor(Theme.tint)
                        .borderRadius(12)
                        .border({ width: 1, color: Theme.line })
                        .font({ size: 15, weight: FontWeight.Medium })
                        .fontColor(Theme.ink)
                }.width('48%').constraintSize({ minWidth: 140 }).alignItems(HorizontalAlign.Start)
            }.width('100%')
            Field({ componentId: 'form-input:location', error: this.issue('location'), area: (area: Area): void => {
                    this.area('location', area);
                }, focused: (): void => {
                    this.focused('location');
                }, label: '存放位置', value: this.draft.location, change: (v: string) => {
                    this.draft.location = v;
                }
            })
            Field({ componentId: 'form-input:brand', error: this.issue('brand'), area: (area: Area): void => {
                    this.area('brand', area);
                }, focused: (): void => {
                    this.focused('brand');
                }, label: '品牌 / 店铺', value: this.draft.brand, change: (v: string) => {
                    this.draft.brand = v;
                }
            })
            Field({ componentId: 'form-input:size', error: this.issue('size'), area: (area: Area): void => {
                    this.area('size', area);
                }, focused: (): void => {
                    this.focused('size');
                }, label: '尺码', value: this.draft.size, change: (v: string) => {
                    this.draft.size = v;
                }
            })
            Field({ componentId: 'form-input:money', error: this.issue('money'), area: (area: Area): void => {
                    this.area('money', area);
                }, focused: (): void => {
                    this.focused('money');
                }, label: '购买价格（元）', value: this.draft.money, change: (v: string) => {
                    this.draft.money = v;
                }
            })
            Field({ componentId: 'form-input:url', error: this.issue('url'), area: (area: Area): void => {
                    this.area('url', area);
                }, focused: (): void => {
                    this.focused('url');
                },
                label: '购买链接',
                value: this.draft.url,
                placeholder: 'https://',
                change: (v: string) => {
                    this.draft.url = v;
                }
            })
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
