import { EXPENSE_CATEGORIES } from '../models/constants';
import { DateField } from './DateField';
import { CosProject } from '../models/Entities';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { EditDraft, FormIssue } from '../viewmodels/EditDraft';
import { Field } from './Surfaces';

@ComponentV2
export struct ExpenseFields {
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
            Text('所属计划 *').fontSize(13).fontColor(Theme.muted)
            Select(this.state.projects.map((p: CosProject): SelectOption => {
                return { value: p.name };
            })).value(this.draft.parentId ? this.state.projectName(this.draft.parentId) : '请选择计划')
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.draft.parentId = this.state.projects[index].id;
                })
                .enabled(!this.draft.id)
                .accessibilityText('花费计划')
                .id('form-input:parentId')
                .width('100%')
                .constraintSize({ minHeight: Theme.controlHeight })
                .backgroundColor(Theme.tint)
                .borderRadius(Theme.pillRadius)
                .border({ width: 1, color: Theme.line })
                .font({ size: 15, weight: FontWeight.Medium })
                .fontColor(Theme.ink)
                .onAreaChange((_, area: Area): void => {
                    this.area('parentId', area);
                })
            this.fieldIssue('parentId')
            Text('分类').fontSize(13).fontColor(Theme.muted)
            Select(EXPENSE_CATEGORIES.map((category: string): SelectOption => {
                return { value: category };
            })).value(this.draft.type)
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.draft.type = EXPENSE_CATEGORIES[index];
                })
                .accessibilityText('花费分类')
                .width('100%')
                .constraintSize({ minHeight: Theme.controlHeight })
                .backgroundColor(Theme.tint)
                .borderRadius(Theme.pillRadius)
                .border({ width: 1, color: Theme.line })
                .font({ size: 15, weight: FontWeight.Medium })
                .fontColor(Theme.ink)
            Field({ componentId: 'form-input:money', error: this.issue('money'), area: (area: Area): void => {
                    this.area('money', area);
                }, focused: (): void => {
                    this.focused('money');
                },
                label: '实际花费（元） *',
                value: this.draft.money,
                placeholder: '例如：129.90',
                change: (v: string): void => {
                    this.draft.money = v;
                }
            })
            DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => {
                    this.area('date', area);
                }, label: '付款日期 *', value: this.draft.date, change: (v: string): void => {
                    this.draft.date = v;
                }
            })
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
