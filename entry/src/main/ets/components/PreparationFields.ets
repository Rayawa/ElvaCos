import { DateField } from './DateField';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { EditDraft, FormIssue } from '../viewmodels/EditDraft';
import { Field } from './Surfaces';
import { PreparationCategory } from '../models/Preparation';

@ComponentV2
export struct PreparationFields {
    @Require @Param state: AppState;
    @Require @Param draft: EditDraft;
    @Param issues: FormIssue[] = [];
    @Event area: (field: string, area: Area) => void = () => {};
    @Event focused: (field: string) => void = () => {};

    private issue(field: string): string {
        return this.issues.find((issue: FormIssue) => issue.field === field)?.message || '';
    }

    @Builder fieldIssue(field: string) {
        if (this.issue(field)) {
            Text(this.issue(field)).fontSize(14).fontColor(Theme.danger).accessibilityText(this.issue(field))
        }
    }

    build() {
        Column({ space: Theme.fieldSpacing }) {
            Text('准备分类 *').fontColor(Theme.muted).fontSize(13)
            Select(this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.draft.parentId).map((c: PreparationCategory): SelectOption => {
                return { value: c.name };
            }))
                .value(this.state.preparationCategories.find((c: PreparationCategory) => c.id === this.draft.categoryId)?.name || '请选择分类')
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.draft.categoryId = this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.draft.parentId)[index].id;
                })
                .accessibilityText('任务分类')
                .id('form-input:categoryId')
                .width('100%')
                .constraintSize({ minHeight: Theme.controlHeight })
                .backgroundColor(Theme.tint)
                .borderRadius(12)
                .border({ width: 1, color: Theme.line })
                .font({ size: 15, weight: FontWeight.Medium })
                .fontColor(Theme.ink)
                .onAreaChange((_, area: Area): void => {
                    this.area('categoryId', area);
                })
            this.fieldIssue('categoryId')
            DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => {
                    this.area('date', area);
                }, label: '截止日期（可选）',
                value: this.draft.date,
                optional: true,
                change: (v: string): void => {
                    this.draft.date = v;
                }
            })
            Field({ componentId: 'form-input:waitingOn', error: this.issue('waitingOn'), area: (area: Area): void => {
                    this.area('waitingOn', area);
                }, focused: (): void => {
                    this.focused('waitingOn');
                }, label: '等待对象（可选）', value: this.draft.waitingOn, placeholder: '例如：快递、妆娘排期、摄影师返图', change: (value: string): void => {
                    this.draft.waitingOn = value;
                }
            })
            DateField({ componentId: 'form-input:waitingUntil', error: this.issue('waitingUntil'), area: (area: Area): void => {
                    this.area('waitingUntil', area);
                }, label: '等待至（可选）', value: this.draft.waitingUntil, optional: true, change: (value: string): void => {
                    this.draft.waitingUntil = value;
                }
            })
            Text('填写任一等待字段后，未完成任务会归入「在途」，不计入逾期。清空两项可回到待办。').fontSize(13).fontColor(Theme.muted)
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
