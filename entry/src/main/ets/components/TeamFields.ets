import { TEAM_ROLES } from '../models/constants';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { EditDraft, FormIssue } from '../viewmodels/EditDraft';
import { Field } from './Surfaces';

@ComponentV2
export struct TeamFields {
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
            Text('分工').fontSize(13).fontColor(Theme.muted)
            Select(TEAM_ROLES.concat('自定义分工').map((role: string): SelectOption => {
                return { value: role };
            })).value(TEAM_ROLES.includes(this.draft.type) ? this.draft.type : '自定义分工')
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.draft.type = index < TEAM_ROLES.length ? TEAM_ROLES[index] : '';
                })
                .accessibilityText('团队分工')
                .width('100%')
                .constraintSize({ minHeight: Theme.controlHeight })
                .backgroundColor(Theme.tint)
                .borderRadius(12)
                .border({ width: 1, color: Theme.line })
                .font({ size: 15, weight: FontWeight.Medium })
                .fontColor(Theme.ink)
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
