import { ContextRow } from '../common/ContextRow';
import { PROJECT_LABELS, PROJECT_STATUSES } from '../../config/constants';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { DateField } from './DateField';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { vibration } from '../../ui/feedback/vibration';
import { EditDraft, FormIssue } from '../../state/forms/EditDraft';
import { Character, CharacterVariant, CosEvent, ProjectStatus } from '../../models/Entities';
import { Field } from '../common/Surfaces';
import { PreparationTemplatePicker } from './PreparationTemplatePicker';

@ComponentV2
export struct ProjectFields {
    @Require @Param state: AppState;
    @Require @Param draft: EditDraft;
    @Param issues: FormIssue[] = [];
    @Event area: (field: string, area: Area) => void = () => {};
    @Event focused: (field: string) => void = () => {};
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());

    private issue(field: string): string {
        return this.issues.find((issue: FormIssue) => issue.field === field)?.message || '';
    }

    @Builder fieldIssue(field: string) {
        if (this.issue(field)) {
            Text(this.issue(field)).fontSize(14).fontColor(Theme.danger).accessibilityText(this.issue(field))
        }
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Column({ space: Theme.fieldSpacing }) {
            Text('这次想出谁？ *').fontColor(Theme.muted).fontSize(13)
            Select((this.draft.id ? new Array<SelectOption>() : new Array<SelectOption>({ value: '＋ 创建新角色' })).concat(this.state.characters.map((c: Character): SelectOption => {
                return { value: c.name };
            })))
                .value(this.draft.newCharacter ? '＋ 创建新角色' : this.state.characterName(this.draft.characterId))
                .onSelect((index: number) => {
                    vibration.dotVibration();
                    const previous = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId);
                    const automatic = !this.draft.name || this.draft.name === previous + '计划' || this.draft.name === previous + ' · 计划';
                    this.draft.newCharacter = !this.draft.id && index === 0;
                    this.draft.characterId = this.draft.newCharacter ? '' : this.state.characters[index - (this.draft.id ? 0 : 1)].id;
                    this.draft.variantId = '';
                    if (automatic && !this.draft.id) {
                        const role = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId);
                        this.draft.name = role ? role + '计划' : '';
                    }
                })
                .accessibilityText('计划角色')
                .visualEffect(this.feedback.effect('select-1'))
                .compositingFilter(this.feedback.filter('select-1'))
                .attributeModifier(this.feedback.control('select-1'))
                .id('form-input:characterId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                    this.area('characterId', area);
                })
            this.fieldIssue('characterId')
            if (this.draft.newCharacter) {
                Field({ componentId: 'form-input:characterName', error: this.issue('characterName'), area: (area: Area): void => {
                        this.area('characterName', area);
                    }, focused: (): void => {
                        this.focused('characterName');
                    }, label: '角色名称 *', value: this.draft.characterName, placeholder: '例如：初音未来', change: (v: string) => {
                        const automatic = !this.draft.name || this.draft.name === this.draft.characterName + '计划' || this.draft.name === this.draft.characterName + ' · 计划';
                        this.draft.characterName = v;
                        if (automatic) {
                            this.draft.name = v ? v + '计划' : '';
                        }
                    }
                })
                Field({ componentId: 'form-input:work', error: this.issue('work'), area: (area: Area): void => {
                        this.area('work', area);
                    }, focused: (): void => {
                        this.focused('work');
                    }, label: '所属作品（可选）', value: this.draft.work, change: (v: string) => {
                        this.draft.work = v;
                    }
                })
            }
            Field({ componentId: 'form-input:name', error: this.issue('name'), area: (area: Area): void => {
                    this.area('name', area);
                }, focused: (): void => {
                    this.focused('name');
                },
                label: '计划名称 *',
                value: this.draft.name,
                placeholder: '例如：初音未来秋日漫展',
                change: (v: string) => {
                    this.draft.name = v;
                }
            })
            DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => {
                    this.area('date', area);
                }, label: '目标日期（可选）',
                value: this.draft.date,
                optional: true,
                change: (v: string) => {
                    this.draft.date = v;
                }
            })
            if (!this.draft.id) {
                Button() {
                    ContextRow({ label: this.draft.preparationExpanded ? '收起模板' : '准备模板', text: '已选 ' + this.draft.preparationKeys.length + ' 项' })
                }.type(ButtonType.Normal)
                    .accessibilityText(this.draft.preparationExpanded ? '收起准备模板' : '展开准备模板，已选择 ' + this.draft.preparationKeys.length + ' 项')
                    .backgroundColor(Theme.tint)
                    .fontColor(Theme.accent)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.draft.preparationExpanded = !this.draft.preparationExpanded;
                    })
                    .visualEffect(this.feedback.effect('button-2'))
                    .compositingFilter(this.feedback.filter('button-2'))
                    .attributeModifier(this.feedback.control('button-2'))
                if (this.draft.preparationExpanded) {
                    PreparationTemplatePicker({
                        keys: this.draft.preparationKeys,
                        mode: this.draft.preparationMode,
                        change: (keys: string[], mode: number): void => {
                            this.draft.preparationKeys = keys;
                            this.draft.preparationMode = mode;
                        }
                    })
                }
            }
            Button() {
                ContextRow({ label: this.draft.advanced ? '收起设置' : '更多设置', text: '版本、活动、拍摄、预算' })
            }.type(ButtonType.Normal)
                .id('form-project-more').accessibilityText(this.draft.advanced ? '收起更多设置' : '展开角色版本、活动、拍摄时间与预算设置')
                .backgroundColor(Theme.tint)
                .fontColor(Theme.accent)
                .onClick(() => {
                    vibration.dotVibration();
                    this.draft.advanced = !this.draft.advanced;
                })
                .visualEffect(this.feedback.effect('button-3'))
                .compositingFilter(this.feedback.filter('button-3'))
                .attributeModifier(this.feedback.control('button-3'))
            if (this.draft.advanced) {
                Text('角色版本').fontColor(Theme.muted).fontSize(13)
                Select(new Array<SelectOption>({ value: '不指定版本' }).concat(this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId).map((v: CharacterVariant): SelectOption => {
                    return { value: v.name };
                })))
                    .value(this.draft.variantId ? this.state.variants.find((v: CharacterVariant) => v.id === this.draft.variantId && v.characterId === this.draft.characterId)?.name || '版本已不存在，请重新选择' : '不指定版本')
                    .onSelect((index: number) => {
                        vibration.dotVibration();
                        this.draft.variantId = index === 0 ? '' : this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId)[index - 1].id;
                    })
                    .accessibilityText('角色版本')
                    .visualEffect(this.feedback.effect('select-4'))
                    .compositingFilter(this.feedback.filter('select-4'))
                    .attributeModifier(this.feedback.control('select-4'))
                    .id('form-input:variantId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                        this.area('variantId', area);
                    })
                this.fieldIssue('variantId')
                Text('关联活动').fontColor(Theme.muted).fontSize(13)
                Select(new Array<SelectOption>({ value: '不关联活动' }).concat(this.state.events.map((e: CosEvent): SelectOption => {
                    return { value: e.name };
                })))
                    .value(this.draft.eventId ? this.state.events.find((e: CosEvent) => e.id === this.draft.eventId)?.name || '活动已不存在，请重新选择' : '不关联活动')
                    .onSelect((index: number) => {
                        vibration.dotVibration();
                        this.draft.eventId = index === 0 ? '' : this.state.events[index - 1].id;
                    })
                    .accessibilityText('关联活动')
                    .visualEffect(this.feedback.effect('select-5'))
                    .compositingFilter(this.feedback.filter('select-5'))
                    .attributeModifier(this.feedback.control('select-5'))
                    .id('form-input:eventId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                        this.area('eventId', area);
                    })
                this.fieldIssue('eventId')
                if (this.draft.eventAssociationHint(this.state)) {
                    Text(this.draft.eventAssociationHint(this.state)).id('form-project-event-change').fontSize(14).fontColor(Theme.muted)
                }
                Select(PROJECT_LABELS.map((label: string): SelectOption => {
                    return { value: label };
                }))
                    .value(PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.draft.status as ProjectStatus)])
                    .onSelect((index: number) => {
                        vibration.dotVibration();
                        this.draft.status = PROJECT_STATUSES[index];
                    })
                    .accessibilityText('计划状态')
                    .visualEffect(this.feedback.effect('select-6'))
                    .compositingFilter(this.feedback.filter('select-6'))
                    .attributeModifier(this.feedback.control('select-6'))
                DateField({ componentId: 'form-input:shootingTime', error: this.issue('shootingTime'), area: (area: Area): void => {
                        this.area('shootingTime', area);
                    }, label: '拍摄 / 约拍开始时间（可选）', value: this.draft.shootingTime, time: true, optional: true, change: (value: string): void => {
                        this.draft.shootingTime = value;
                    }
                })
                Text('日期使用目标日期，否则使用活动开始日期；跨日拍摄请指定目标日期。日期未定时仅记录时刻。').fontSize(14).fontColor(Theme.muted)
                Field({ componentId: 'form-input:money', error: this.issue('money'), area: (area: Area): void => {
                        this.area('money', area);
                    }, focused: (): void => {
                        this.focused('money');
                    }, label: '预算（元，可留空；填 0 表示零预算）', value: this.draft.money, change: (v: string) => {
                        this.draft.money = v;
                        this.draft.budgetEdited = true;
                    }
                })
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
