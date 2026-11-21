import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { EditDraft, FormIssue } from '../viewmodels/EditDraft';
import { Field } from './Surfaces';

@ComponentV2
export struct CharacterFields {
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
            Field({ componentId: 'form-input:work', error: this.issue('work'), area: (area: Area): void => {
                    this.area('work', area);
                }, focused: (): void => {
                    this.focused('work');
                }, label: '所属作品', value: this.draft.work, change: (v: string) => {
                    this.draft.work = v;
                }
            })
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
