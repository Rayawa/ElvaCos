import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { EditDraft, FormIssue } from '../../state/forms/EditDraft';
import { Field } from '../common/Surfaces';

@ComponentV2
export struct CharacterFields {
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
