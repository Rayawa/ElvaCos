import { TEAM_ROLES } from '../../config/constants';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { vibration } from '../../ui/feedback/vibration';
import { EditDraft, FormIssue } from '../../state/forms/EditDraft';
import { Field } from '../common/Surfaces';

@ComponentV2
export struct TeamFields {
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
            Text('分工').fontSize(13).fontColor(Theme.muted)
            Select(TEAM_ROLES.concat('自定义分工').map((role: string): SelectOption => {
                return { value: role };
            })).value(TEAM_ROLES.includes(this.draft.type) ? this.draft.type : '自定义分工')
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.draft.type = index < TEAM_ROLES.length ? TEAM_ROLES[index] : '';
                })
                .accessibilityText('团队分工')
                .visualEffect(this.feedback.effect('select-16'))
                .compositingFilter(this.feedback.filter('select-16'))
                .attributeModifier(this.feedback.control('select-16')).constraintSize({ minHeight: 36 })
                .controlSize(ControlSize.SMALL).font({ size: 14 })
            if (!TEAM_ROLES.includes(this.draft.type)) {
                Field({ componentId: 'form-input:type', error: this.issue('type'), area: (area: Area): void => {
                        this.area('type', area);
                    }, focused: (): void => {
                        this.focused('type');
                    },
                    label: '自定义分工 *',
                    value: this.draft.type,
                    placeholder: '例如：道具师、同行伙伴',
                    change: (value: string): void => {
                        this.draft.type = value;
                    }
                })
            }
            Text('填写本机称呼和联络备注，不会访问通讯录或向对方发送消息。').fontSize(12).fontColor(Theme.muted)
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
